import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso denegado')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'No tienes permiso para acceder a esta sección o tu sesión ha expirado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text('Volver al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
