// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../services/file_service.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../providers/user_provider_V2.dart';
import '../../../utils/parameters_service.dart';
import '../../../utils/notification_service.dart'; // enviarNotificacion

class UploadFileScreen extends StatefulWidget {
  const UploadFileScreen({super.key});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  final _params = ParametersService();
  final _scrollCtrl = ScrollController();

  String? _grade;
  PlatformFile? _pickedFile;
  bool _loading = false;
  List<Map<String, dynamic>> _uploadedFiles = [];
  bool _canCreate = false;
  bool _canDelete = false;
  List<String> _grades = [];

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProviderV2>().user!;
    final permissions = user.permissions;
    _canCreate = permissions.contains('archivos.crear');
    _canDelete = permissions.contains('archivos.eliminar');
    _loadGrades();
    _loadUploadedFiles();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    try {
      final params = await _params.getGrades();
      if (!mounted) return;
      setState(() {
        _grades =
            params
                .map((p) => p.valor.trim())
                .where((g) => g.toLowerCase() != 'no aplica')
                .toList();
      });
    } catch (_) {}
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      mostrarSnack(context, 'No file selected.');
      return;
    }

    final file = result.files.first;
    final ext = file.extension?.toLowerCase();

    if (!['pdf', 'doc', 'docx', 'xls', 'xlsx'].contains(ext)) {
      mostrarSnack(context, 'Only PDF, Word or Excel files are allowed.');
      return;
    }

    if (file.bytes == null) {
      mostrarSnack(context, 'Error reading file.');
      return;
    }

    setState(() => _pickedFile = file);
  }

  List<String> _extractTokens(Map<String, dynamic> data) {
    final out = <String>[];
    final t1 = data['fcmToken'];
    if (t1 is String && t1.trim().isNotEmpty) out.add(t1.trim());
    final tN = data['fcmTokens'];
    if (tN is List) {
      out.addAll(
        tN.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }
    return out;
  }

  Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }

  Future<void> _upload() async {
    if (!_canCreate) return;

    if (_pickedFile == null || _grade == null) {
      mostrarSnack(context, 'All fields are required.');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = context.read<UserProviderV2>().user!;
      final uploaderId = user.id;
      final uploaderName = '${user.firstName} ${user.lastName}';
      final institutionId = user.institution;
      final campusId = user.campus;

      final originalName = _pickedFile!.name;
      final storageName =
          '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final storagePath = 'files/$_grade/$storageName';

      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putData(_pickedFile!.bytes!);
      final url = await ref.getDownloadURL();

      final docRef = await FirebaseFirestore.instance.collection('files').add({
        'grade': _grade,
        'name': originalName,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploaderId,
        'uploaderName': uploaderName,
        'storagePath': storagePath,
        'institutionId': institutionId,
        'campusId': campusId,
      });
      await docRef.update({'id': docRef.id});

      final usersCol = FirebaseFirestore.instance.collection('users');

      final stuSnap =
          await usersCol
              .where('institution', isEqualTo: institutionId)
              .where('campus', isEqualTo: campusId)
              .where('role', isEqualTo: 'Estudiante')
              .where('grade', isEqualTo: _grade)
              .where('status', isEqualTo: 'activo')
              .get();

      final studentIds = stuSnap.docs.map((d) => d.id).toList();

      final stuTokens = <String>{};
      for (final d in stuSnap.docs) {
        stuTokens.addAll(_extractTokens(d.data()));
      }

      final famTokens = <String>{};
      for (final chunk in _chunks(studentIds, 10)) {
        if (chunk.isEmpty) continue;
        final famSnap =
            await usersCol
                .where('institution', isEqualTo: institutionId)
                .where('campus', isEqualTo: campusId)
                .where('role', isEqualTo: 'Familiar')
                .where('status', isEqualTo: 'activo')
                .where('studentIds', arrayContainsAny: chunk)
                .get();
        for (final d in famSnap.docs) {
          famTokens.addAll(_extractTokens(d.data()));
        }
      }

      final tokens = {...stuTokens, ...famTokens}.toList();
      if (tokens.isNotEmpty) {
        await enviarNotificacion(
          tokens: tokens,
          titulo: '📎 New file available',
          cuerpo: 'Check the file "$originalName" recently uploaded.',
          grado: _grade,
        );
      }

      mostrarSnack(context, '✅ File uploaded successfully.');
      setState(() {
        _pickedFile = null;
      });

      _loadUploadedFiles();
    } catch (e) {
      mostrarSnack(context, '❌ Error uploading file: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _loadUploadedFiles() async {
    final user = context.read<UserProviderV2>().user!;
    final files = await FileService().getUploadedFiles(
      currentUser: user,
      selectedGrade: _grade,
    );
    setState(() => _uploadedFiles = files);
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    if (!_canDelete) return;

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Delete file'),
              content: const Text('Are you sure you want to delete this file?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );

      if (confirm != true) return;

      final docId = file['id'] as String?;
      final url = file['url'] as String?;
      if (docId == null || url == null) {
        mostrarSnack(context, 'Invalid file reference.');
        return;
      }

      await FileService().deleteFile(docId, url);

      if (!mounted) return;
      mostrarSnack(context, '✅ File deleted.');

      await _loadUploadedFiles();
    } catch (e) {
      if (mounted) mostrarSnack(context, '❌ Error deleting: $e');
    }
  }

  BoxDecoration _boxDecoration(BuildContext context) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.red.withOpacity(.15)),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.red.withOpacity(.06), Colors.white],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(140, 44),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        title: const Text('Upload file (Word, Excel, PDF)'),
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 960 : 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Caja de carga / filtros
                    Container(
                      decoration: _boxDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Grade selector
                          Text(
                            'Share with grade',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.redAccent.withOpacity(.95),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _grade,
                            items:
                                _grades
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) async {
                              setState(() => _grade = v);
                              await _loadUploadedFiles();
                            },
                            decoration: InputDecoration(
                              labelText: 'Grade',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(.25),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.4,
                                ),
                              ),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botón seleccionar archivo + nombre
                          if (_canCreate)
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _selectFile,
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Select file'),
                                  style: _primaryButtonStyle(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child:
                                        _pickedFile == null
                                            ? const SizedBox.shrink()
                                            : Text(
                                              _pickedFile!.name,
                                              key: ValueKey(_pickedFile!.name),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 16),

                          // Botón subir
                          if (_canCreate)
                            Align(
                              alignment: Alignment.centerLeft,
                              child:
                                  _loading
                                      ? const SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : ElevatedButton.icon(
                                        onPressed: _upload,
                                        icon: const Icon(Icons.upload),
                                        label: const Text('Upload'),
                                        style: _primaryButtonStyle(),
                                      ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Caja listado
                    Container(
                      decoration: _boxDecoration(context),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.folder, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text(
                                'Your uploaded files',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_uploadedFiles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No files uploaded yet.'),
                            )
                          else
                            ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _uploadedFiles.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final file = _uploadedFiles[i];
                                final name = file['name']?.toString() ?? '';
                                final grade = file['grade']?.toString() ?? '';
                                final ts = file['createdAt'];
                                final date =
                                    ts is Timestamp
                                        ? ts.toDate()
                                        : DateTime.now();

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOut,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(.15),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.red.withOpacity(.06),
                                        Colors.white,
                                      ],
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Grade: $grade • ${date.toLocal()}',
                                    ),
                                    trailing:
                                        _canDelete
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed:
                                                  () => _deleteFile(file),
                                            )
                                            : null,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
