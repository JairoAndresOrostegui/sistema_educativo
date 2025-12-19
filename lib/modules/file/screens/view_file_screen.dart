// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/file/file_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/user_log_service.dart';
import '../../schedule/services/schedule_service.dart';
import '../services/file_service.dart';
import '../utils/file_utils.dart';

class ViewFilesScreen extends StatefulWidget {
  const ViewFilesScreen({super.key});

  @override
  State<ViewFilesScreen> createState() => _ViewFilesScreenState();
}

class _ViewFilesScreenState extends State<ViewFilesScreen> {
  final FileService _fileService = FileService();
  final ScheduleService _scheduleService = ScheduleService();
  final ScrollController _listCtrl = ScrollController();

  bool _loading = false;
  List<FileModel> _files = [];

  // Familiar
  List<userModelv2> _children = [];
  String? _activeStudentId;
  String? _activeGrade;

  // Descarga
  final Set<String> _downloaded = <String>{};
  String? _downloading;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    _bootstrap();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final user = context.read<UserProviderV2>().user!;
      if (user.role == 'Estudiante') {
        _activeGrade = user.grade;
        await _loadFilesByGrade();
      } else if (user.role == 'Familiar') {
        final ids = user.studentIds ?? const <String>[];
        if (ids.isNotEmpty) {
          final kids = await _scheduleService.getUsersByIds(
            userIds: ids,
            institutionId: user.institution,
            campusId: user.campus,
          );
          _children = kids;
          String initialId =
              user.activeStudentId ?? (kids.isNotEmpty ? kids.first.id : '');
          if (initialId.isEmpty || !kids.any((e) => e.id == initialId)) {
            initialId = kids.first.id;
          }
          _activeStudentId = initialId;
          final sel = _children.firstWhere((e) => e.id == _activeStudentId);
          _activeGrade = sel.grade;
          await _loadFilesByGrade();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFilesByGrade() async {
    if (_activeGrade == null || _activeGrade!.isEmpty) {
      setState(() => _files = []);
      return;
    }

    final current = context.read<UserProviderV2>().user!;
    final list = await _fileService.getFilesByGrade(
      institutionId: current.institution,
      campusId: current.campus,
      grade: _activeGrade!,
    );

    list.sort((a, b) => (b.createdAt.seconds).compareTo(a.createdAt.seconds));

    final downloadedKeys = await UserLogService().getDownloadedFileKeys(
      userId: current.id,
      grade: _activeGrade!,
      limit: 100,
    );

    if (!mounted) return;
    setState(() {
      _files = list;
      _downloaded
        ..clear()
        ..addAll(downloadedKeys);
    });
  }

  Future<void> _onChildChanged(String newId) async {
    if (_activeStudentId == newId) return;
    setState(() {
      _activeStudentId = newId;
      _loading = true;
    });
    final sel = _children.firstWhere((e) => e.id == newId);
    _activeGrade = sel.grade;
    await _loadFilesByGrade();
    if (mounted) setState(() => _loading = false);
  }

  String _fileKey(FileModel f) => f.id.isNotEmpty ? f.id : f.url;

  Future<void> _onDownloadTap(FileModel file) async {
    final key = _fileKey(file);
    if (mounted) setState(() => _downloading = key);

    try {
      await descargarArchivoDesdeURL(
        file.url,
        file.name.isEmpty ? 'archivo' : file.name,
      );

      final user = context.read<UserProviderV2>().user!;
      try {
        await UserLogService().logEvent(
          user: user,
          event: 'file_download',
          extra: {
            'fileId': file.id,
            'name': file.name,
            'grade': file.grade,
            'url': file.url,
            'uploadedBy': file.uploadedBy,
          },
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _downloaded.add(key);
      });
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error al descargar',
        message: '$e',
      );
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  List<MapEntry<String, List<FileModel>>> _groupsByMonthDesc() {
    final map = <String, List<FileModel>>{};
    final labels = <String, String>{};

    for (final f in _files) {
      final dt = f.createdAt.toDate();
      final key = DateFormat('yyyy-MM').format(dt);
      final label = _capitalize(DateFormat('MMMM yyyy', 'es').format(dt));
      labels[key] = label;
      map.putIfAbsent(key, () => []).add(f);
    }
    return map.entries.map((e) => MapEntry(labels[e.key]!, e.value)).toList();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.redAccent.withValues(alpha: .15)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  BoxDecoration _itemDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.redAccent.withValues(alpha: .15)),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.redAccent.withValues(alpha: .06), Colors.white],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    final groups = _groupsByMonthDesc();
    final isWide = MediaQuery.of(context).size.width >= 920;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        leading: const BackToDashboardButton(),
        title: const Text('Download file'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 960 : 720),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          if (user?.role == 'Familiar' && _children.isNotEmpty)
                            Container(
                              decoration: _boxDecoration(),
                              padding: const EdgeInsets.all(12),
                              child: DropdownButtonFormField<String>(
                                initialValue: _activeStudentId,
                                decoration: InputDecoration(
                                  labelText: 'Estudiante',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.redAccent.withValues(
                                        alpha: .25,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                items:
                                    _children
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e.id,
                                            child: Text(
                                              '${e.firstName} ${e.lastName} • ${e.grade ?? '-'}',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  if (v != null) _onChildChanged(v);
                                },
                              ),
                            ),
                          if (user?.role == 'Familiar' && _children.isNotEmpty)
                            const SizedBox(height: 12),
                          Expanded(
                            child:
                                _files.isEmpty
                                    ? Container(
                                      decoration: _boxDecoration(),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 28,
                                        horizontal: 16,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'No hay archivos disponibles.',
                                        ),
                                      ),
                                    )
                                    : Scrollbar(
                                      controller: _listCtrl,
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        controller: _listCtrl,
                                        itemCount: groups.length,
                                        itemBuilder: (context, idx) {
                                          final label = groups[idx].key;
                                          final items = groups[idx].value;

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 14,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: _boxDecoration(),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 4,
                                                        bottom: 8,
                                                      ),
                                                  child: Text(
                                                    label,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                                ListView.separated(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount: items.length,
                                                  separatorBuilder:
                                                      (context, _) =>
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                  itemBuilder: (_, i) {
                                                    final f = items[i];
                                                    final date =
                                                        f.createdAt.toDate();
                                                    final dateStr = DateFormat(
                                                      'yyyy-MM-dd HH:mm',
                                                    ).format(date);

                                                    final key = _fileKey(f);
                                                    final isLoading =
                                                        _downloading == key;
                                                    final isDownloaded =
                                                        _downloaded.contains(
                                                          key,
                                                        );

                                                    return AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 200,
                                                      ),
                                                      curve: Curves.easeOut,
                                                      decoration:
                                                          _itemDecoration(),
                                                      child: ListTile(
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 6,
                                                            ),
                                                        leading: const Icon(
                                                          Icons
                                                              .insert_drive_file_rounded,
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                        title: Text(
                                                          f.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        subtitle: Text(
                                                          'Subido por: ${f.uploaderName}\n$dateStr',
                                                        ),
                                                        trailing:
                                                            isLoading
                                                                ? const SizedBox(
                                                                  height: 24,
                                                                  width: 24,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                )
                                                                : IconButton(
                                                                  icon: Icon(
                                                                    Icons
                                                                        .download,
                                                                    color:
                                                                        isDownloaded
                                                                            ? Colors.green
                                                                            : Colors.redAccent,
                                                                  ),
                                                                  onPressed:
                                                                      () =>
                                                                          _onDownloadTap(
                                                                            f,
                                                                          ),
                                                                ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
