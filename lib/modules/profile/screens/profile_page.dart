import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/user/userModelV2.dart';
import '../../../providers/user_provider_V2.dart';
import '../services/profile_service.dart';
import '../utils/profile_image_picker.dart';
import '../widgets/profile_field.dart';
import '../../user/widgets/admin_photo_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  UserModelV2? userModel;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final provider = Provider.of<UserProviderV2>(context, listen: false);
    if (mounted) setState(() => userModel = provider.user);
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

      if (url != null && mounted) {
        final provider = Provider.of<UserProviderV2>(context, listen: false);
        final usuarioActual = provider.user;
        if (usuarioActual != null) {
          final nuevoUsuario = usuarioActual.copyWith(photoUrl: url);
          provider.setUser(nuevoUsuario);
          setState(() => userModel = nuevoUsuario);
        }
      }

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
    if (userModel == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("My profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Colors.redAccent),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              children: [
                const SizedBox(height: 20),

                // Foto con borde rojo y sombra
                Center(
                  child: Semantics(
                    label: 'Foto de perfil, pulsa para cambiarla',
                    button: true,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 132,
                          height: 132,
                          child: ProfilePhotoWidget(
                            imageUrl: userModel!.photoUrl,
                            onTap: _seleccionarImagenYSubir,
                            enableHoverEdit: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Botón editar foto solo en mobile
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

                const SizedBox(height: 16),

                _ProfileHeaderCard(user: userModel!),

                const SizedBox(height: 24),

                _ProfileDataCard(user: userModel!),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final UserModelV2 user;
  const _ProfileHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    const TextAlign align = TextAlign.center;

    final fullName = '${user.firstName} ${user.lastName}'.trim();
    final meta = [
      if ((user.role).isNotEmpty) user.role,
      if ((user.grade ?? '').isNotEmpty) '• ${user.grade}',
      if ((user.campus).isNotEmpty) '• ${user.campus}',
    ].join('  ');

    return Semantics(
      label: 'Información principal del perfil',
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(.15)),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.fromRGBO(244, 67, 54, 0.06),
              Colors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              fullName.isEmpty ? '-' : fullName,
              textAlign: align,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meta.isEmpty ? '-' : meta,
              textAlign: align,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent.withOpacity(.9),
              ),
            ),
            if ((user.institution).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                user.institution,
                textAlign: align,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileDataCard extends StatelessWidget {
  final UserModelV2 user;
  const _ProfileDataCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Datos del perfil',
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(.15)),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color.fromRGBO(244, 67, 54, 0.06), Colors.white],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              label: 'Información',
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Información',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
            Container(height: 1, color: Colors.red.withOpacity(.15)),
            const SizedBox(height: 8),
            ProfileField(title: "Nombres", value: user.firstName),
            ProfileField(title: "Apellidos", value: user.lastName),
            ProfileField(title: "Correo personal", value: user.personalEmail),
            ProfileField(
              title: "Correo institucional",
              value: user.institutionalEmail,
            ),
            ProfileField(title: "Documento", value: user.document),
            ProfileField(title: "Tipo de documento", value: user.documentType),
            ProfileField(title: "Dirección", value: user.address ?? ''),
            ProfileField(
              title: "Fecha de nacimiento",
              value:
                  user.birthDate != null
                      ? DateFormat('dd/MM/yyyy').format(user.birthDate!)
                      : '',
            ),
            ProfileField(title: "Grado", value: user.grade ?? ''),
            ProfileField(title: "Rol", value: user.role),
            ProfileField(title: "Institución", value: user.institution),
            ProfileField(title: "Sede", value: user.campus),
            ProfileField(
              title: "Activo",
              value: user.status == 'activo' ? 'Sí' : 'No',
            ),
            for (int i = 0; i < user.phones.length; i++)
              ProfileField(title: "Teléfono ${i + 1}", value: user.phones[i]),
          ],
        ),
      ),
    );
  }
}
