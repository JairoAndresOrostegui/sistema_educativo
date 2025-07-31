// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/files/file_utils.dart';

class ViewFilesScreen extends StatefulWidget {
  const ViewFilesScreen({super.key});

  @override
  State<ViewFilesScreen> createState() => _ViewFilesScreenState();
}

class _ViewFilesScreenState extends State<ViewFilesScreen> {
  List<Map<String, dynamic>> archivos = [];
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    cargarArchivos();
  }

  Future<void> cargarArchivos() async {
    setState(() => cargando = true);

    final user = FirebaseAuth.instance.currentUser!;
    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
    final grado = doc['grado'];

    final snap =
        await FirebaseFirestore.instance
            .collection('archivos')
            .where('grado', isEqualTo: grado)
            .orderBy('fechaSubida', descending: true)
            .get();

    archivos = snap.docs.map((d) => d.data()).toList();

    setState(() => cargando = false);
  }

  Future<void> descargar(Map<String, dynamic> archivo) async {
    try {
      final nombre = archivo['nombre'] ?? 'archivo';
      final url = archivo['url'];
      await descargarArchivoDesdeURL(url, nombre);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al descargar: $e')));
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
        title: const Text(
          'Download file',
        ),
      ),
      body:
          cargando
              ? const Center(child: CircularProgressIndicator())
              : archivos.isEmpty
              ? const Center(child: Text('No hay archivos disponibles.'))
              : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: archivos.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final archivo = archivos[i];
                  final nombre = archivo['nombre'] ?? '';
                  final subidoPor = archivo['subidoPor'] ?? '';
                  final fecha = (archivo['fechaSubida'] as Timestamp).toDate();

                  return Semantics(
                    label:
                        'Archivo: $nombre, subido por $subidoPor el ${fecha.toLocal()}',
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Semantics(
                        label: 'Nombre del archivo: $nombre',
                        child: Text(nombre),
                      ),
                      subtitle: Semantics(
                        label:
                            'Subido por $subidoPor. Fecha: ${fecha.toLocal()}',
                        child: Text(
                          'Subido por: $subidoPor\n${fecha.toLocal()}',
                        ),
                      ),
                      trailing: Semantics(
                        button: true,
                        label: 'Descargar archivo $nombre',
                        enabled: true,
                        focusable: true,
                        child: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => descargar(archivo),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
