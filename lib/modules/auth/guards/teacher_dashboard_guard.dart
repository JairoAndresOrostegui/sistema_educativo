import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/login_page.dart';
import '../pages/access_denied_page.dart';
import '../../teacher/layouts/teacher_dashboard_layout.dart';

class TeacherDashboardGuard extends StatelessWidget {
  const TeacherDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data();

        if (data == null || data is! Map<String, dynamic>) {
          return const AccessDeniedPage();
        }

        final List<dynamic> funcionalidades =
            data['funcionalidades'] is List
                ? data['funcionalidades'] as List<dynamic>
                : [];

        final bool esAdminConPermisos =
            data['rol'] == 'admin' &&
            funcionalidades.contains('docente.acceso');

        if (data['estado'] != 'activo' ||
            (data['rol'] != 'docente' && !esAdminConPermisos)) {
          return const AccessDeniedPage();
        }

        return const DocenteDashboardLayout();
      },
    );
  }
}
