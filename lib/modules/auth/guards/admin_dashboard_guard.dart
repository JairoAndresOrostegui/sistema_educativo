import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../admin/layouts/admin_dashboard_layout.dart';
import '../pages/access_denied_page.dart';
import '../pages/login_page.dart';

class AdminDashboardGuard extends StatelessWidget {
  const AdminDashboardGuard({super.key});

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
        if (data == null || data['rol'] != 'admin') {
          return const AccessDeniedPage();
        }

        return const AdminDashboardLayout();
      },
    );
  }
}
