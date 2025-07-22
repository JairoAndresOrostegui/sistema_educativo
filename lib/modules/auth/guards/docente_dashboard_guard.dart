import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/login_page.dart';
import '../pages/access_denied_page.dart';
import '../../docente/layouts/docente_dashboard_layout.dart';

class DocenteDashboardGuard extends StatelessWidget {
  const DocenteDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final funcionalidades = Map<String, dynamic>.from(data?['funcionalidades'] ?? {});
        final esAdminConPermisos = data?['rol'] == 'admin' && funcionalidades['docente'] != null;

        if (data == null || (data['rol'] != 'docente' && !esAdminConPermisos)) {
          return const AccessDeniedPage();
        }

        return const DocenteDashboardLayout();
      },
    );
  }
}
