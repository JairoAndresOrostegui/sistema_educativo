import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../../../services/profile_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/images/profile_image_picker.dart';
import '../widgets/profile_field.dart';
import '../../auth/widgets/profile_photo_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  late User user;
  final _usuarioService = UsuarioService();
  UsuarioModel? usuario;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser!;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final result = await _usuarioService.obtenerUsuarioActual();
    if (mounted) setState(() => usuario = result);
  }

  Future<void> _seleccionarImagenYSubir() async {
    try {
      final (archivoBytes, nombreOriginal) = await pickImage();
      if (archivoBytes == null) return;

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

      final url = await _profileService.uploadProfilePhoto(
        Uint8List.fromList(archivoBytes),
        nombreOriginal,
      );

      if (url != null) await _loadUserData();

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
    if (usuario == null) {
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
                  child: ProfilePhotoWidget(
                    imageUrl: usuario!.fotoUrl,
                    onTap: _seleccionarImagenYSubir,
                    enableHoverEdit: true,
                  ),
                ),
                if (!kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Semantics(
                        label: 'Botón para cambiar la foto de perfil',
                        button: true,
                        enabled: true,
                        focusable: true,
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
                  ),
                const SizedBox(height: 60),
                ProfileField(title: "Nombres", value: usuario!.nombres),
                ProfileField(title: "Apellidos", value: usuario!.apellidos),
                ProfileField(
                  title: "Correo personal",
                  value: usuario!.correoPersonal,
                ),
                ProfileField(
                  title: "Correo institucional",
                  value: usuario!.correoInstitucional,
                ),
                ProfileField(title: "Documento", value: usuario!.documento),
                ProfileField(
                  title: "Tipo de documento",
                  value: usuario!.tipoDocumento,
                ),
                ProfileField(
                  title: "Dirección",
                  value: usuario!.direccionResidencia ?? '',
                ),
                ProfileField(
                  title: "Fecha de nacimiento",
                  value: usuario!.fechaNacimiento ?? '',
                ),
                ProfileField(title: "Grado", value: usuario!.grado ?? ''),
                ProfileField(title: "Rol", value: usuario!.rol),
                ProfileField(title: "Institución", value: usuario!.institucion),
                ProfileField(title: "Sede", value: usuario!.sede),
                ProfileField(
                  title: "Activo",
                  value: usuario!.estado == 'activo' ? 'Sí' : 'No',
                ),
                for (int i = 0; i < usuario!.telefonos.length; i++)
                  ProfileField(
                    title: "Teléfono ${i + 1}",
                    value: usuario!.telefonos[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
