import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/authServiceV2.dart';
import '../../../providers/user_provider_V2.dart';
import 'loginScreenV2.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  Future<void> _goToLogin(BuildContext context) async {
    final userProvider = context.read<UserProviderV2>();
    final user = userProvider.user;

    try {
      if (user != null) {
        // Registra logout + cierra sesión
        await AuthService().logout(user);
      } else {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      // Si algo falla, intentamos cerrar sesión de Firebase por si acaso
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    // Limpia el estado del provider para no dejar usuario en memoria
    try {
      userProvider.clearUser();
    } catch (_) {
      // Ignora si tu implementación no acepta null
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Acceso denegado'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 80, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'No tienes permiso para acceder a esta sección o tu sesión ha expirado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Volver al inicio de sesión',
                  child: ElevatedButton(
                    onPressed: () => _goToLogin(context),
                    child: const Text('Volver al inicio de sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
