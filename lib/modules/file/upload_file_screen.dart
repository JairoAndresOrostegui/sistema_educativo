// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../services/file/file_service.dart';
import '../../services/notification/notification_service.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/grades_utils.dart';
import '../auth/providers/user_provider.dart';

class UploadFileScreen extends StatefulWidget {
  const UploadFileScreen({super.key});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  String? _grado;
  PlatformFile? _archivo;
  bool _cargando = false;
  List<Map<String, dynamic>> _archivosSubidos = [];
  late String _uid;
  bool _puedeCrear = false;
  bool _puedeEliminar = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;

    final userProvider = context.read<UsuarioProvider>();
    final user = userProvider.usuario!;
    final funcionalidades = user.funcionalidades;

    _puedeCrear = funcionalidades.contains('documentos.crear');
    _puedeEliminar = funcionalidades.contains('documentos.eliminar');

    _cargarArchivosSubidos();
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      mostrarSnack(context, 'No se seleccionó ningún archivo.');
      return;
    }

    final archivo = result.files.first;
    final extension = archivo.extension?.toLowerCase();

    if (!['pdf', 'doc', 'docx', 'xls', 'xlsx'].contains(extension)) {
      mostrarSnack(context, 'Solo se permiten archivos PDF, Word o Excel.');
      return;
    }

    if (archivo.bytes == null) {
      mostrarSnack(context, 'Error al leer el archivo.');
      return;
    }

    setState(() => _archivo = archivo);
  }

  Future<void> _subir() async {
    if (!_puedeCrear) return;

    if (_archivo == null || _grado == null) {
      mostrarSnack(context, 'Todos los campos son obligatorios.');
      return;
    }

    setState(() => _cargando = true);

    try {
      final userSnap =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_uid)
              .get();
      final nombreCompleto = '${userSnap['nombres']} ${userSnap['apellidos']}';
      final nombreArchivo = _archivo!.name;
      final nombreFinal =
          '${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo';

      final ref = FirebaseStorage.instance.ref().child(
        'archivos/$_grado/$nombreFinal',
      );
      await ref.putData(_archivo!.bytes!);
      final url = await ref.getDownloadURL();

      final docRef = await FirebaseFirestore.instance
          .collection('archivos')
          .add({
            'grado': _grado,
            'nombre': nombreArchivo,
            'url': url,
            'fechaSubida': Timestamp.now(),
            'subidoPor': nombreCompleto,
            'uploaderId': _uid,
            'storagePath': 'archivos/$_grado/$nombreFinal',
          });

      await docRef.update({'id': docRef.id});

      final snap =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .where('grado', isEqualTo: _grado)
              .where('rol', isEqualTo: 'estudiante')
              .where('estado', isEqualTo: 'activo')
              .get();

      final tokens =
          snap.docs
              .map((d) => d.data()['fcmTokens'])
              .whereType<List>()
              .expand((list) => list)
              .whereType<String>()
              .where((token) => token.trim().isNotEmpty)
              .toList();

      if (tokens.isNotEmpty) {
        await enviarNotificacion(
          tokens: tokens,
          grado: _grado!,
          titulo: '📎 Nuevo archivo disponible',
          cuerpo: 'Revisa el archivo "$nombreArchivo" que acaban de subir.',
        );
      } else {}

      mostrarSnack(context, '✅ Archivo subido exitosamente.');
      setState(() {
        _archivo = null;
        _grado = null;
      });

      _cargarArchivosSubidos();
    } catch (e) {
      mostrarSnack(context, '❌ Error al subir archivo: $e');
    }

    setState(() => _cargando = false);
  }

  Future<void> _cargarArchivosSubidos() async {
    final archivos = await ArchivoService().obtenerArchivosSubidos(
      gradoSeleccionado: _grado,
    );
    setState(() => _archivosSubidos = archivos);
  }

  Future<void> _eliminarArchivo(Map<String, dynamic> archivo) async {
    if (!_puedeEliminar) return;

    try {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: const Text('Eliminar archivo'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este archivo?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                },
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Eliminar'),
              ),
            ],
          );
        },
      );

      if (confirmar != true) {
        return;
      }

      final docId = archivo['id'];
      final path = archivo['storagePath'];

      await FirebaseStorage.instance.refFromURL(archivo['url']).delete();

      await FirebaseFirestore.instance
          .collection('archivos')
          .doc(docId)
          .delete();

      if (!mounted) {
        return;
      }

      mostrarSnack(context, '✅ Archivo eliminado.');

      await _cargarArchivosSubidos();
    } catch (e) {
      if (mounted) mostrarSnack(context, '❌ Error al eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        title: const Text('Upload file (word, excel, pdf)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _grado,
              items:
                  gradosColombia
                      .where((g) => g != 'No aplica')
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
              onChanged: (v) async {
                setState(() => _grado = v);
                await _cargarArchivosSubidos();
              },
              decoration: const InputDecoration(labelText: 'Grado'),
            ),
            const SizedBox(height: 16),
            if (_puedeCrear)
              ElevatedButton.icon(
                onPressed: _seleccionarArchivo,
                icon: const Icon(Icons.attach_file),
                label: const Text('Seleccionar archivo'),
              ),
            if (_archivo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _archivo!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 24),
            if (_puedeCrear)
              _cargando
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                    onPressed: _subir,
                    icon: const Icon(Icons.upload),
                    label: const Text('Subir archivo'),
                  ),
            const Divider(height: 40),
            const Text(
              'Tus archivos subidos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._archivosSubidos.map((archivo) {
              final nombre = archivo['nombre'] ?? '';
              final grado = archivo['grado'] ?? '';
              final fecha = (archivo['fechaSubida'] as Timestamp).toDate();

              return ListTile(
                title: Text(nombre),
                subtitle: Text('Grado: $grado • ${fecha.toLocal()}'),
                trailing:
                    _puedeEliminar
                        ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarArchivo(archivo),
                        )
                        : null,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
