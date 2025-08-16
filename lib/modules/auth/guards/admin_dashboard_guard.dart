import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/admin_dashboard_layout.dart';
import '../../../providers/user_provider_V2.dart';
import '../screens/access_denied_page.dart';
import '../screens/loginScreenV2.dart';

class AdminDashboardGuard extends StatelessWidget {
  const AdminDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProviderV2>().user;
    if (user == null) return const LoginScreen();

    final role = user.role.trim().toLowerCase();
    final status = (user.status).trim().toLowerCase();
    final isActive = status == 'activo';

    final canAccess = user.isSuperadmin || role == 'administrador';
    if (!canAccess || !isActive) return const AccessDeniedPage();

    return const AdminDashboardLayout();
  }
}
