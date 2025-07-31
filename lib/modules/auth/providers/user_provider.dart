import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum EstadoUsuario { cargando, autenticado, noAutenticado, error }

class UsuarioProvider extends ChangeNotifier {
  UsuarioModel? _usuario;
  EstadoUsuario _estado = EstadoUsuario.cargando;

  UsuarioModel? get usuario => _usuario;
  EstadoUsuario get estado => _estado;

  Future<void> cargarUsuario(String? uid) async {
    if (uid == null) {
      _estado = EstadoUsuario.noAutenticado;
      notifyListeners();
      return;
    }

    try {
      _estado = EstadoUsuario.cargando;
      notifyListeners();

      final doc =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        _estado = EstadoUsuario.noAutenticado;
        notifyListeners();
        return;
      }

      _usuario = UsuarioModel.fromFirestore(doc.data()!, doc.id);
      _estado = EstadoUsuario.autenticado;
      notifyListeners();
    } catch (e) {
      _estado = EstadoUsuario.error;
      notifyListeners();
    }
  }

  void limpiarUsuario() {
    _usuario = null;
    _estado = EstadoUsuario.noAutenticado;
    notifyListeners();
  }

  Future<void> actualizarUsuario() async {
    if (_usuario?.id == null) return;
    await cargarUsuario(_usuario!.id);
  }
}
