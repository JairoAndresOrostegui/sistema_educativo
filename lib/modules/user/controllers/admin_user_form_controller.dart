import 'dart:typed_data';

import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/profile/services/profile_service.dart';
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
    final correoPersonalNormalizado = correoPersonal.trim().toLowerCase();
    final correoInstitucionalNormalizado =
        correoInstitucional.trim().toLowerCase();

    // Documento mínimo
    if (documento.trim().length < 6) {
      onResetSaving();
      await onError(
        'Validacion',
        'El documento debe tener al menos 6 caracteres.',
      );
      return false;
    }

    // Correo personal
    if (await _service.existeCorreoPersonal(
      correoPersonalNormalizado,
      excluirId: excluirId,
    )) {
      onResetSaving();
      await onError('Validacion', 'El correo personal ya esta registrado.');
      return false;
    }

    // Correo institucional
    if (await _service.existeCorreoInstitucional(
      correoInstitucionalNormalizado,
      excluirId: excluirId,
    )) {
      onResetSaving();
      await onError(
        'Validacion',
        'El correo institucional ya esta registrado.',
      );
      return false;
    }

    // Documento
    if (await _service.existeDocumento(
      documento.trim(),
      excluirId: excluirId,
    )) {
      onResetSaving();
      await onError('Validacion', 'El documento ya esta registrado.');
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

  Future<void> guardarNuevo({
    required userModelv2 usuario,
    required Uint8List? fotoBytes,
    String? fotoNombre,
    required userModelv2 usuarioLogueado,
  }) async {
    final uid = await _service.crearUsuarioDesdeAdmin(
      email: usuario.institutionalEmail,
      password: usuario.document,
      nombres: usuario.firstName,
      apellidos: usuario.lastName,
      rol: usuario.role,
      documento: usuario.document,
    );

    String? nuevaFotoUrl;
    if (fotoBytes != null) {
      nuevaFotoUrl = await _profileService.subirFotoPerfil(
        bytes: fotoBytes,
        uid: uid,
        fileName: fotoNombre,
      );
    }

    final usuarioConUid = usuario.copyWith(id: uid, photoUrl: nuevaFotoUrl);
    await _service.guardarUsuario(usuarioConUid);
    await _service.registrarHistorial(
      usuario: usuarioConUid,
      accion: 'creado',
      realizadoPor: '${usuarioLogueado.firstName} ${usuarioLogueado.lastName}',
    );
  }

  Future<void> guardarExistente({
    required userModelv2 usuario,
    required Uint8List? fotoBytes,
    String? fotoNombre,
    required userModelv2 usuarioLogueado,
  }) async {
    String? nuevaFotoUrl;
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
    await _service.guardarUsuario(usuarioEditado);
    await _service.registrarHistorial(
      usuario: usuarioEditado,
      accion: 'editado',
      realizadoPor: '${usuarioLogueado.firstName} ${usuarioLogueado.lastName}',
    );
  }
}
