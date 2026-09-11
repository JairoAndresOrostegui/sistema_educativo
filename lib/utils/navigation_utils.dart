import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider_v2.dart';

class NavigationUtils {
  static String homeForRole(String? role) {
    final normalized = role?.trim().toLowerCase();
    switch (normalized) {
      case 'administrador':
        return '/admin_dashboard';
      case 'docente':
        return '/teacher_dashboard';
      case 'estudiante':
      case 'familiar':
        return '/student_dashboard';
      default:
        return '/login';
    }
  }

  static void goHome(BuildContext context) {
    final role = context.read<UserProviderV2>().user?.role;
    final route = homeForRole(role);
    context.go(route);
  }
}

class BackToDashboardButton extends StatelessWidget {
  final Color? color;
  const BackToDashboardButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => NavigationUtils.goHome(context),
      icon: Icon(Icons.arrow_back),
      color: color ?? AppPalette.primary,
      tooltip: 'Volver al menú principal',
    );
  }
}
