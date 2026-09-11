import 'dart:typed_data';

import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/profile/services/profile_service.dart';
import 'package:sistema_educativo/modules/profile/services/profile_photo_commit.dart';
import 'package:sistema_educativo/modules/user/services/user_service_v2.dart';

class AdminUserFormController {
  final UserServiceV2 _service = UserServiceV2();
  final ProfileService _profileService = ProfileService();

  Future<bool> validarCamposUnicos({
    required String correoPersonal,
    required String correoInstitucional,
    required String documento,
    required String? excluirId,
    required void Function() onResetSaving,
    required Future<void> Function(String title, String message) onError,
  }) async {
    // La unicidad se valida en backend, dentro de la misma operación que
    // guarda el usuario. Una consulta previa desde el cliente no evita
    // carreras y requeriría leer perfiles fuera del alcance autorizado.
    if (documento.trim().length < 6) {
      onResetSaving();
      await onError(
        'Validacion',
        'El documento debe tener al menos 6 caracteres.',
      );
      return false;
    }

    return true;
  }

  Future<String?> subirFoto({
    required Uint8List? pickedBytes,
    required String uid,
    String? fileName,
  }) async {
    if (pickedBytes == null) return null;
    return _profileService.subirFotoPerfil(
      bytes: pickedBytes,
      uid: uid,
      fileName: fileName,
    );
  }

  Future<String?> guardarNuevo({
    required userModelv2 usuario,
    required Uint8List? fotoBytes,
    String? fotoNombre,
    required userModelv2 usuarioLogueado,
  }) async {
    final uid = await _service.crearUsuarioDesdeAdmin(
      usuario: usuario,
      email: usuario.institutionalEmail,
      password: usuario.document,
      nombres: usuario.firstName,
      apellidos: usuario.lastName,
      rol: usuario.role,
      documento: usuario.document,
    );

    if (fotoBytes != null) {
      String? uploadedUrl;
      try {
        uploadedUrl = await _profileService.subirFotoPerfil(
          bytes: fotoBytes,
          uid: uid,
          fileName: fotoNombre,
        );
        final confirmedUrl = uploadedUrl;
        await commitProfilePhoto(
          confirm: () async {
            await _service.guardarUsuario(
              usuario.copyWith(id: uid, photoUrl: confirmedUrl),
            );
            return '';
          },
          discardUpload: () =>
              _profileService.deleteUploadedProfilePhoto(confirmedUrl),
          cleanupPrevious: (_) async {},
        );
      } catch (_) {
        // La cuenta ya fue creada. No provocar un segundo intento de alta que
        // choque con correo/documento duplicado; la UI informa que solo falta
        // reintentar la foto desde Editar usuario.
        return 'El usuario fue creado, pero la foto no pudo guardarse. '
            'Puedes agregarla al editar el usuario.';
      }
    }
    return null;
  }

  Future<void> guardarExistente({
    required userModelv2 usuario,
    required Uint8List? fotoBytes,
    String? fotoNombre,
    required userModelv2 usuarioLogueado,
  }) async {
    String? nuevaFotoUrl;
    final fotoAnterior = usuario.photoUrl ?? '';
    if (fotoBytes != null) {
      nuevaFotoUrl = await _profileService.subirFotoPerfil(
        bytes: fotoBytes,
        uid: usuario.id,
        fileName: fotoNombre,
      );
    }

    final usuarioEditado = usuario.copyWith(
      photoUrl: nuevaFotoUrl ?? usuario.photoUrl,
    );
    if (nuevaFotoUrl == null) {
      await _service.guardarUsuario(usuarioEditado);
      return;
    }
    final confirmedUrl = nuevaFotoUrl;
    await commitProfilePhoto(
      confirm: () async {
        await _service.guardarUsuario(usuarioEditado);
        return fotoAnterior;
      },
      discardUpload: () =>
          _profileService.deleteUploadedProfilePhoto(confirmedUrl),
      cleanupPrevious: _profileService.deleteUploadedProfilePhoto,
    );
  }
}
