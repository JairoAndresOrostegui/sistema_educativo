import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../utils/imagen/profile_image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User user;
  Map<String, dynamic>? userData;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser!;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
    if (doc.exists) {
      setState(() {
        userData = doc.data()!;
      });
    }
  }

  Future<void> _seleccionarImagenYSubir() async {
    try {
      final (archivoBytes, nombreOriginal) = await pickImage();

      if (archivoBytes == null) return;

      final nombreArchivo = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Validar el nombre original, no el generado
      if (!(nombreOriginal.toLowerCase().endsWith('.jpg') ||
          nombreOriginal.toLowerCase().endsWith('.jpeg') ||
          nombreOriginal.toLowerCase().endsWith('.png'))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Solo se permiten imágenes JPG o PNG."),
            ),
          );
        }
        return;
      }
      final ref = FirebaseStorage.instance.ref().child(
        "fotos_perfil/${user.uid}/$nombreArchivo",
      );

      final uploadTask = await ref.putData(
        Uint8List.fromList(archivoBytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({'fotoUrl': url});

      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil actualizada")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al subir imagen: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Perfil del Usuario"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 1,
        leading: const BackButton(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: MouseRegion(
                    cursor:
                        kIsWeb
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                    onEnter: (_) {
                      if (kIsWeb) setState(() => _hovering = true);
                    },
                    onExit: (_) {
                      if (kIsWeb) setState(() => _hovering = false);
                    },
                    child: GestureDetector(
                      onTap: _seleccionarImagenYSubir,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          userData!["fotoUrl"] != null &&
                                  userData!["fotoUrl"].toString().isNotEmpty
                              ? CircleAvatar(
                                radius: 60,
                                backgroundImage: NetworkImage(
                                  userData!["fotoUrl"],
                                ),
                              )
                              : const Icon(
                                Icons.account_circle,
                                size: 120,
                                color: Color.fromARGB(255, 31, 155, 212),
                              ),
                          if (kIsWeb && _hovering)
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(100),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'Editar foto',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _seleccionarImagenYSubir,
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          "Editar foto",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 60),
                _dato("Nombres", userData!["nombres"]),
                _dato("Apellidos", userData!["apellidos"]),
                _dato("Correo", userData!["correo"]),
                _dato("Correo institucional", userData!["correoInstitucional"]),
                _dato("Documento", userData!["documento"]),
                _dato("Tipo de documento", userData!["tipoDocumento"]),
                _dato("Teléfono 1", userData!["telefono1"]),
                _dato("Teléfono 2", userData!["telefono2"]),
                _dato("Dirección", userData!["direccion"]),
                _dato("Fecha de nacimiento", userData!["fechaNacimiento"]),
                _dato("Grado", userData!["grado"]),
                _dato("Rol", userData!["rol"]),
                _dato(
                  "Activo",
                  userData!["activo"] == true
                      ? "Sí"
                      : userData!["activo"] == false
                      ? "No"
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dato(String titulo, dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$titulo: ",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              valor.toString(),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
