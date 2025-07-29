import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../student/layouts/student_dashboard_layout.dart';
import '../pages/access_denied_page.dart';
import '../pages/login_page.dart';

class StudentDashboardGuard extends StatelessWidget {
  const StudentDashboardGuard({super.key});

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

        if (data['rol'] != 'estudiante' || data['estado'] != 'activo') {
          return const AccessDeniedPage();
        }

        return const EstudianteDashboardLayout();
      },
    );
  }
}
