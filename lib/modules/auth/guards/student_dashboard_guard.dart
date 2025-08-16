import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/student_dashboard_layout.dart';
import '../../../providers/user_provider_V2.dart';
import '../screens/access_denied_page.dart';
import '../screens/loginScreenV2.dart';

class StudentDashboardGuard extends StatelessWidget {
  const StudentDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProviderV2>();
    final user = userProvider.user;

    if (user == null) return const LoginScreen();

    final role = user.role.trim().toLowerCase();
    final status = (user.status).trim().toLowerCase();
    final isActive = status == 'activo';
    final isAllowed = role == 'estudiante' || role == 'familiar';

    if (!isAllowed || !isActive) return const AccessDeniedPage();

    // Familiar: setear activeStudentId si falta, sin bloquear el build
    if (role == 'familiar' &&
        (user.studentIds?.isNotEmpty ?? false) &&
        (user.activeStudentId == null || user.activeStudentId!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final up = context.read<UserProviderV2>();
        final current = up.user;
        if (current == null) return;
        final stillFamiliar = current.role.trim().toLowerCase() == 'familiar';
        final needsActive =
            (current.activeStudentId == null ||
                current.activeStudentId!.isEmpty);
        final hasKids = current.studentIds?.isNotEmpty ?? false;

        if (stillFamiliar && needsActive && hasKids) {
          up.setUser(
            current.copyWith(activeStudentId: current.studentIds!.first),
          );
        }
      });
    }

    return const EstudianteDashboardLayout();
  }
}
