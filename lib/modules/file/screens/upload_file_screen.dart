// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/academic/academic_group.dart';
import '../../../models/file/file_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/academic_group_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/user_log_service.dart';
import '../../schedule/services/schedule_service.dart';
import '../../user/services/active_student_service.dart';
import '../services/file_service.dart';
import '../utils/file_utils.dart';

class UploadFileScreen extends StatefulWidget {
  const UploadFileScreen({super.key});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  final _service = FileService();
  final _groupService = AcademicGroupService();
  final _parameters = ParametersService();
  final _schedule = ScheduleService();
  final _selectedFiles = <String>{};

  bool _loading = true;
  bool _busy = false;
  double? _uploadProgress;
  List<InstitutionOption> _institutions = [];
  List<AcademicGroup> _groups = [];
  List<userModelv2> _children = [];
  List<FileModel> _files = [];
  FileStorageSummary? _summary;
  String? _institutionId;
  String? _campusId;
  String? _groupId;
  String? _activeStudentId;

  userModelv2 get _user => context.read<UserProviderV2>().user!;
  bool get _isStaff => _user.role == 'Administrador' || _user.role == 'Docente';
  bool get _canCreate =>
      _user.isSuperadmin || _user.permissions.contains('archivos.crear');
  bool get _canDelete =>
      _user.isSuperadmin || _user.permissions.contains('archivos.eliminar');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final user = _user;
      _institutionId = user.institution;
      _campusId = user.campus;
      _institutions = await _parameters.getInstitutions();
      if (user.role == 'Familiar') {
        _children = await _schedule.getUsersByIds(
          userIds: user.studentIds ?? const [],
          institutionId: user.institution,
          campusId: user.campus,
        );
        if (_children.isNotEmpty) {
          final saved = user.activeStudentId ?? '';
          final selected = _children.any((child) => child.id == saved)
              ? saved
              : _children.first.id;
          await _selectChild(selected, reload: false);
        }
      } else if (user.role == 'Estudiante' || user.role == 'Docente') {
        _groupId = user.groupId;
      } else {
        await _loadGroups();
        _groupId = _groups.isEmpty ? null : _groups.first.id;
      }
      await _reloadContent();
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No fue posible cargar Archivos',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGroups() async {
    if (_institutionId == null || _campusId == null) return;
    _groups = await _groupService.list(
      institutionId: _institutionId!,
      campusId: _campusId!,
    );
  }

  Future<void> _reloadContent() async {
    if (_institutionId == null || _campusId == null || _groupId == null) {
      if (mounted) setState(() => _files = []);
      return;
    }
    final results = await Future.wait([
      _service.list(
        institutionId: _institutionId!,
        campusId: _campusId!,
        groupId: _groupId!,
      ),
      if (_isStaff)
        _service.summary(institutionId: _institutionId)
      else
        Future<FileStorageSummary?>.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _files = results.first as List<FileModel>;
      _summary = results.last as FileStorageSummary?;
      _selectedFiles.clear();
    });
  }

  Future<void> _changeTenant(String institution, String campus) async {
    setState(() {
      _loading = true;
      _institutionId = institution;
      _campusId = campus;
      _groupId = null;
    });
    try {
      await _loadGroups();
      _groupId = _groups.isEmpty ? null : _groups.first.id;
      await _reloadContent();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectChild(String id, {bool reload = true}) async {
    final child = _children.firstWhere((item) => item.id == id);
    await ActiveStudentService().select(
      userProvider: context.read<UserProviderV2>(),
      studentId: id,
    );
    _activeStudentId = id;
    _groupId = child.groupId;
    if (reload) await _reloadContent();
  }

  String? _mimeFor(PlatformFile file) {
    return switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => null,
    };
  }

  Future<void> _upload() async {
    if (!_canCreate || _groupId == null) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final mime = _mimeFor(file);
    if (file.bytes == null || mime == null) {
      await DialogUtils.showError(
        context: context,
        title: 'Archivo no permitido',
        message: 'Selecciona un PDF, Word o Excel válido.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _uploadProgress = 0;
    });
    try {
      await _service.upload(
        bytes: file.bytes!,
        name: file.name,
        contentType: mime,
        institutionId: _institutionId!,
        campusId: _campusId!,
        groupId: _groupId!,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress.ratio);
        },
      );
      await _reloadContent();
      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: 'Archivo publicado',
          message: 'La carga y su registro finalizaron correctamente.',
        );
      }
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No fue posible publicar',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _download(FileModel file) async {
    setState(() => _busy = true);
    try {
      final url = await _service.downloadUrl(file);
      await descargarArchivoDesdeURL(url, file.name);
      await UserLogService().logEvent(
        user: _user,
        event: 'file_download',
        extra: {
          'fileId': file.id,
          'name': file.name,
          'groupId': file.groupId,
          'groupName': file.groupName,
          'sizeBytes': file.sizeBytes,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (!_canDelete || _selectedFiles.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar archivos'),
        content: Text(
          'Se eliminarán ${_selectedFiles.length} archivos de Storage y sus '
          'registros. La acción quedará auditada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _service.deleteSelected(_selectedFiles);
      await _reloadContent();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOldFiles() async {
    if (!_user.isSuperadmin) return;
    final count = _summary?.oldFilesCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpieza por antigüedad'),
        content: Text(
          'Se eliminarán todos los archivos con más de 60 días ($count '
          'detectados actualmente). La acción quedará auditada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ejecutar limpieza'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final deleted = await _service.deleteOlderThanRetention();
      await _reloadContent();
      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: 'Limpieza finalizada',
          message: 'Se eliminaron $deleted archivos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }

  InstitutionOption? get _selectedInstitution {
    for (final institution in _institutions) {
      if (institution.id == _institutionId) return institution;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackToDashboardButton(),
        title: const Text('Archivos'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _bootstrap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreate && _groupId != null
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Publicar archivo'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_user.isSuperadmin) _tenantSelectors(),
                    if (_user.role == 'Familiar' && _children.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _activeStudentId,
                        decoration: const InputDecoration(
                          labelText: 'Hijo seleccionado',
                        ),
                        items: _children
                            .map(
                              (child) => DropdownMenuItem(
                                value: child.id,
                                child: Text(
                                  '${child.firstName} ${child.lastName} • '
                                  '${child.groupName ?? 'Sin grupo'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value != null) _selectChild(value);
                              },
                      ),
                    if (_user.role == 'Administrador')
                      DropdownButtonFormField<String>(
                        initialValue: _groupId,
                        decoration: const InputDecoration(labelText: 'Grupo'),
                        items: _groups
                            .map(
                              (group) => DropdownMenuItem(
                                value: group.id,
                                child: Text(group.name),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) async {
                                setState(() => _groupId = value);
                                await _reloadContent();
                              },
                      ),
                    if (_summary != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Almacenamiento del módulo',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: _summary!.ratio),
                              const SizedBox(height: 8),
                              Text(
                                '${_size(_summary!.usedBytes)} de '
                                '${_size(_summary!.limitBytes)} utilizados • '
                                'máximo ${_size(_summary!.maxFileBytes)} por archivo',
                              ),
                              if (_user.isSuperadmin) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _deleteOldFiles,
                                  icon: const Icon(Icons.auto_delete_outlined),
                                  label: Text(
                                    'Eliminar archivos de más de 60 días '
                                    '(${_summary!.oldFilesCount})',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_uploadProgress != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _uploadProgress),
                      Text(
                        '${(_uploadProgress! * 100).toStringAsFixed(0)}% cargado',
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Documentos disponibles',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (_canDelete && _selectedFiles.isNotEmpty)
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _deleteSelected,
                            icon: const Icon(Icons.delete_outline),
                            label: Text('Eliminar (${_selectedFiles.length})'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_files.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No hay archivos para este grupo.'),
                          ),
                        ),
                      )
                    else
                      ..._files.map(
                        (file) => Card(
                          child: CheckboxListTile(
                            value: _selectedFiles.contains(file.id),
                            onChanged:
                                _canDelete &&
                                    (_user.role != 'Docente' ||
                                        file.uploadedBy == _user.id)
                                ? (selected) => setState(() {
                                    if (selected == true) {
                                      _selectedFiles.add(file.id);
                                    } else {
                                      _selectedFiles.remove(file.id);
                                    }
                                  })
                                : null,
                            secondary: Icon(
                              Icons.description_outlined,
                              color: colors.primary,
                            ),
                            title: Text(file.name),
                            subtitle: Text(
                              '${file.groupName} • ${_size(file.sizeBytes)} • '
                              '${DateFormat('dd/MM/yyyy').format(file.createdAt.toDate())}',
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          ),
                        ),
                      ),
                    if (_files.isNotEmpty)
                      ..._files.map(
                        (file) => Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _busy ? null : () => _download(file),
                            icon: const Icon(Icons.download),
                            label: Text('Descargar ${file.name}'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
                if (_busy)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: colors.scrim.withValues(alpha: .13),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _tenantSelectors() {
    final campuses = _selectedInstitution?.campuses ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _institutionId,
              decoration: const InputDecoration(labelText: 'Institución'),
              items: _institutions
                  .map(
                    (institution) => DropdownMenuItem(
                      value: institution.id,
                      child: Text(institution.label),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      final institution = _institutions.firstWhere(
                        (item) => item.id == value,
                      );
                      if (institution.campuses.isNotEmpty) {
                        _changeTenant(value, institution.campuses.first);
                      }
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('$_institutionId:$_campusId'),
              initialValue: _campusId,
              decoration: const InputDecoration(labelText: 'Sede'),
              items: campuses
                  .map(
                    (campus) =>
                        DropdownMenuItem(value: campus, child: Text(campus)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null && _institutionId != null) {
                        _changeTenant(_institutionId!, value);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
