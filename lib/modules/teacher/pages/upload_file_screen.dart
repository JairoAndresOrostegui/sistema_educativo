// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

import '../../../services/firebase_utils.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/grades_utils.dart';

class UploadFileScreen extends StatefulWidget {
  const UploadFileScreen({super.key});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  final _nombreCtrl = TextEditingController();
  String? _grado;
  PlatformFile? _archivo;
  bool _cargando = false;
  List<Map<String, dynamic>> _archivosSubidos = [];
  late String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
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
    if (_nombreCtrl.text.trim().isEmpty || _archivo == null || _grado == null) {
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

      // Agregar ID del documento a su propio registro
      await docRef.update({'id': docRef.id});

      final snap =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .where('grado', isEqualTo: _grado)
              .where('rol', isEqualTo: 'estudiante')
              .where('activo', isEqualTo: true)
              .get();

      final tokens =
          snap.docs
              .map((d) => d.data()['fcmToken'])
              .whereType<String>()
              .toList();

      if (tokens.isNotEmpty) {
        await enviarNotificacion(
          tokens: tokens,
          grado: _grado!,
          titulo: '📎 Nuevo archivo disponible',
          cuerpo: 'Revisa el archivo "$nombreArchivo" que acaban de subir.',
        );
      }

      mostrarSnack(context, '✅ Archivo subido exitosamente.');
      setState(() {
        _nombreCtrl.clear();
        _archivo = null;
        _grado = null;
      });

      _cargarArchivosSubidos(); // recargar lista
    } catch (e) {
      mostrarSnack(context, '❌ Error al subir archivo: $e');
    }

    setState(() => _cargando = false);
  }

  
  Future<void> _cargarArchivosSubidos() async {
    final snap = await FirebaseFirestore.instance
        .collection('archivos')
        .where('uploaderId', isEqualTo: _uid)
        .orderBy('fechaSubida', descending: true)
        .get();

    setState(() {
      _archivosSubidos = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  Future<void> _eliminarArchivo(Map<String, dynamic> archivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Eliminar archivo'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este archivo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmar != true) return;

    try {
      final docId = archivo['id'];
      final path = archivo['storagePath'];
      await FirebaseFirestore.instance
          .collection('archivos')
          .doc(docId)
          .delete();
      await FirebaseStorage.instance.ref(path).delete();
      mostrarSnack(context, '✅ Archivo eliminado.');
      _cargarArchivosSubidos();
    } catch (e) {
      mostrarSnack(context, '❌ Error al eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Subir archivo (word, excel, pdf)',
          style: TextStyle(color: Colors.red),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del archivo',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _grado,
              items:
                  gradosColombia
                      .where((g) => g != 'No aplica')
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
              onChanged: (v) => setState(() => _grado = v),
              decoration: const InputDecoration(labelText: 'Grado'),
            ),
            const SizedBox(height: 16),
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _eliminarArchivo(archivo),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
