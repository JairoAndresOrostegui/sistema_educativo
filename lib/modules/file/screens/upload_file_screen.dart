// ignore_for_file: use_build_context_synchronously

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/file/file_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
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
  final _parameters = ParametersService();
  final _schedule = ScheduleService();
  final _messageController = TextEditingController();
  final _selectedFiles = <String>{};
  final _selectedGroupIds = <String>{};
  final _selectedStudentIds = <String>{};

  bool _loading = true;
  bool _busy = false;
  double? _uploadProgress;
  List<InstitutionOption> _institutions = [];
  List<userModelv2> _children = [];
  List<FileModel> _files = [];
  FileStorageSummary? _summary;
  FileAudienceOptions? _audienceOptions;
  FileAudienceType _audienceType = FileAudienceType.groups;
  String? _institutionId;
  String? _campusId;
  String? _activeStudentId;

  userModelv2 get _user => context.read<UserProviderV2>().user!;
  bool get _isAdmin => _user.isSuperadmin || _user.role == 'Administrador';
  bool get _isStaff => _isAdmin || _user.role == 'Docente';
  bool get _canCreate =>
      _user.isSuperadmin || _user.permissions.contains('archivos.crear');
  bool get _canDelete =>
      _isAdmin &&
      (_user.isSuperadmin || _user.permissions.contains('archivos.eliminar'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
      }
      await _reloadAll();
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

  Future<void> _reloadAll() async {
    if (_institutionId == null || _campusId == null) return;
    final results = await Future.wait([
      _service.list(
        institutionId: _institutionId!,
        campusId: _campusId!,
        activeStudentId: _user.role == 'Familiar' ? _activeStudentId : null,
      ),
      if (_isStaff)
        _service.summary(institutionId: _institutionId)
      else
        Future<FileStorageSummary?>.value(null),
      if (_canCreate)
        _service.audienceOptions(
          institutionId: _institutionId!,
          campusId: _campusId!,
        )
      else
        Future<FileAudienceOptions?>.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _files = results[0] as List<FileModel>;
      _summary = results[1] as FileStorageSummary?;
      _audienceOptions = results[2] as FileAudienceOptions?;
      _selectedFiles.clear();
      _selectedGroupIds.clear();
      _selectedStudentIds.clear();
    });
  }

  Future<void> _changeTenant(String institution, String campus) async {
    setState(() {
      _loading = true;
      _institutionId = institution;
      _campusId = campus;
    });
    try {
      await _reloadAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectChild(String id, {bool reload = true}) async {
    await ActiveStudentService().select(
      userProvider: context.read<UserProviderV2>(),
      studentId: id,
    );
    _activeStudentId = id;
    if (reload) await _reloadAll();
  }

  String? _mimeFor(PlatformFile file) => switch (file.extension
      ?.toLowerCase()) {
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => null,
  };

  Future<void> _upload() async {
    if (!_canCreate) return;
    if (_audienceType == FileAudienceType.groups && _selectedGroupIds.isEmpty) {
      await _showValidation('Selecciona al menos un grupo.');
      return;
    }
    if (_audienceType == FileAudienceType.students &&
        _selectedStudentIds.isEmpty) {
      await _showValidation('Selecciona al menos un estudiante.');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final mime = _mimeFor(file);
    if (file.bytes == null || mime == null) {
      await _showValidation('Selecciona un PDF, Word o Excel válido.');
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
        audienceType: _audienceType,
        targetGroupIds: _selectedGroupIds.toList(),
        targetStudentIds: _selectedStudentIds.toList(),
        message: _messageController.text.trim(),
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress.ratio);
        },
      );
      _messageController.clear();
      await _reloadAll();
      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: 'Archivo publicado',
          message:
              'El archivo, el mensaje y sus destinatarios quedaron registrados.',
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

  Future<void> _showValidation(String message) => DialogUtils.showError(
    context: context,
    title: 'Falta información',
    message: message,
  );

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
      await _reloadAll();
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
          'detectados). La acción quedará auditada.',
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
      await _reloadAll();
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

  Future<void> _selectGroups() async {
    final temporary = {..._selectedGroupIds};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Seleccionar grupos'),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: (_audienceOptions?.groups ?? const [])
                  .map(
                    (group) => CheckboxListTile(
                      value: temporary.contains(group.id),
                      title: Text(group.name),
                      onChanged: (checked) => setDialogState(() {
                        checked == true
                            ? temporary.add(group.id)
                            : temporary.remove(group.id);
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, temporary),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedGroupIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _selectStudents() async {
    final temporary = {..._selectedStudentIds};
    var search = '';
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final students = (_audienceOptions?.students ?? const []).where((
            item,
          ) {
            final value = '${item.name} ${item.groupName}'.toLowerCase();
            return value.contains(search.toLowerCase());
          }).toList();
          return AlertDialog(
            title: const Text('Seleccionar estudiantes'),
            content: SizedBox(
              width: 520,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o grupo',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setDialogState(() => search = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return CheckboxListTile(
                          value: temporary.contains(student.id),
                          title: Text(student.name),
                          subtitle: Text(student.groupName),
                          onChanged: (checked) => setDialogState(() {
                            checked == true
                                ? temporary.add(student.id)
                                : temporary.remove(student.id);
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, temporary),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      setState(() {
        _selectedStudentIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
      : '${(bytes / 1024).toStringAsFixed(1)} KiB';

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
                                  '${child.firstName} ${child.lastName} • ${child.groupName ?? 'Sin grupo'}',
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
                    if (_summary != null) _storageCard(),
                    if (_canCreate) _publicationCard(),
                    if (_uploadProgress != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _uploadProgress),
                      Text(
                        '${(_uploadProgress! * 100).toStringAsFixed(0)}% cargado',
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Publicaciones disponibles',
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
                            child: Text('No hay publicaciones disponibles.'),
                          ),
                        ),
                      )
                    else
                      ..._files.map((file) => _fileCard(file, colors)),
                    const SizedBox(height: 32),
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

  Widget _publicationCard() {
    final types = _user.role == 'Docente'
        ? const [FileAudienceType.groups, FileAudienceType.students]
        : FileAudienceType.values;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva publicación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FileAudienceType>(
              initialValue: _audienceType,
              decoration: const InputDecoration(labelText: 'Enviar a'),
              items: types
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _audienceType = value;
                        _selectedGroupIds.clear();
                        _selectedStudentIds.clear();
                      });
                    },
            ),
            if (_audienceType == FileAudienceType.groups) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _selectGroups,
                icon: const Icon(Icons.groups_outlined),
                label: Text('Elegir grupos (${_selectedGroupIds.length})'),
              ),
            ],
            if (_audienceType == FileAudienceType.students) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _selectStudents,
                icon: const Icon(Icons.person_search_outlined),
                label: Text(
                  'Buscar estudiantes (${_selectedStudentIds.length})',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLength: 2000,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mensaje o enlace (opcional)',
                hintText: 'Escribe una indicación o pega un enlace.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Elegir archivo y publicar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageCard() => Card(
    margin: const EdgeInsets.only(top: 16),
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
            '${_size(_summary!.usedBytes)} de ${_size(_summary!.limitBytes)} utilizados • máximo ${_size(_summary!.maxFileBytes)} por archivo',
          ),
          if (_user.isSuperadmin) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _deleteOldFiles,
              icon: const Icon(Icons.auto_delete_outlined),
              label: Text(
                'Eliminar archivos de más de 60 días (${_summary!.oldFilesCount})',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _fileCard(FileModel file, ColorScheme colors) {
    final uri = Uri.tryParse(file.message);
    final isLink =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_canDelete)
                  Checkbox(
                    value: _selectedFiles.contains(file.id),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _selectedFiles.add(file.id)
                          : _selectedFiles.remove(file.id);
                    }),
                  ),
              ],
            ),
            Text('${file.audienceLabel} • ${_size(file.sizeBytes)}'),
            Text(
              'Enviado por ${file.uploaderName} • ${DateFormat('dd/MM/yyyy HH:mm').format(file.sentAt.toDate())}',
            ),
            if (file.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (isLink)
                TextButton.icon(
                  onPressed: () =>
                      launchUrl(uri, mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.link),
                  label: Text(file.message),
                )
              else
                SelectableText(file.message),
            ],
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _busy ? null : () => _download(file),
              icon: const Icon(Icons.download),
              label: const Text('Descargar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tenantSelectors() {
    final campuses = _selectedInstitution?.campuses ?? const <String>[];
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _institutionId,
            decoration: const InputDecoration(labelText: 'Institución'),
            items: _institutions
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.label)),
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
    );
  }
}
