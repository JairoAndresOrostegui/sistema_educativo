import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/admin_dashboard_layout.dart';
import '../../../providers/user_provider_v2.dart';
import '../screens/access_denied_page.dart';
import '../screens/loginScreenV2.dart';

class AdminDashboardGuard extends StatelessWidget {
  const AdminDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    if (user == null) return const _RedirectToLogin();

    final role = user.role.trim().toLowerCase();
    final status = (user.status).trim().toLowerCase();
    final isActive = status == 'activo';

    final canAccess = user.isSuperadmin || role == 'administrador';
    if (!canAccess || !isActive) return const AccessDeniedPage();

    return const AdminDashboardLayout();
  }
}

class _RedirectToLogin extends StatefulWidget {
  const _RedirectToLogin();

  @override
  State<_RedirectToLogin> createState() => _RedirectToLoginState();
}

class _RedirectToLoginState extends State<_RedirectToLogin> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
