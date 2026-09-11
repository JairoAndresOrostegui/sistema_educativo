import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/student_dashboard_layout.dart';
import '../../../providers/user_provider_v2.dart';
import '../screens/access_denied_page.dart';
import '../screens/loginScreenV2.dart';
import '../../user/services/active_student_service.dart';
import '../../../utils/user_facing_error.dart';

class StudentDashboardGuard extends StatelessWidget {
  const StudentDashboardGuard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProviderV2>();
    final user = userProvider.user;

    if (user == null) return const _RedirectToLogin();

    final role = user.role.trim().toLowerCase();
    final status = (user.status).trim().toLowerCase();
    final isActive = status == 'activo';
    final isAllowed = role == 'estudiante' || role == 'familiar';

    if (!isAllowed || !isActive) return const AccessDeniedPage();

    final studentIds = user.studentIds ?? const <String>[];
    final activeStudentId = user.activeStudentId?.trim() ?? '';
    if (role == 'familiar' &&
        studentIds.isNotEmpty &&
        !studentIds.contains(activeStudentId)) {
      return _InitializeActiveStudent(studentId: studentIds.first);
    }

    return const EstudianteDashboardLayout();
  }
}

class _InitializeActiveStudent extends StatefulWidget {
  const _InitializeActiveStudent({required this.studentId});

  final String studentId;

  @override
  State<_InitializeActiveStudent> createState() =>
      _InitializeActiveStudentState();
}

class _InitializeActiveStudentState extends State<_InitializeActiveStudent> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _select();
  }

  Future<void> _select() async {
    if (mounted) setState(() => _error = null);
    try {
      await ActiveStudentService().select(
        userProvider: context.read<UserProviderV2>(),
        studentId: widget.studentId,
      );
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo seleccionar el estudiante activo.\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _select,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
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
