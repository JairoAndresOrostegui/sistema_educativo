import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/student_dashboard_guard.dart';
import 'modules/auth/guards/teacher_dashboard_guard.dart';
import 'modules/auth/screens/access_denied_page.dart';
import 'modules/auth/screens/loginScreenV2.dart';
import 'modules/auth/services/auth_service_v2.dart';
import 'modules/authorization/screens/admin_authorization_screen.dart';
import 'modules/authorization/screens/student_authorization_screen.dart';
import 'modules/authorization/screens/teacher_authorization_screen.dart';
import 'modules/file/screens/upload_file_screen.dart';
import 'modules/file/screens/view_file_screen.dart';
import 'modules/history/screens/admin_history_screen.dart';
import 'modules/messaging/screens/messaging_screen.dart';
import 'modules/profile/screens/profile_page.dart';
import 'modules/route/screens/admin_route_screen.dart';
import 'modules/route/screens/student_route_screen.dart';
import 'modules/route/screens/teacher_route_screen.dart';
import 'modules/parameters/screens/admin_parameters_screen.dart';
import 'modules/qr/screens/admin_qr_screen.dart';
import 'modules/qr/screens/student_qr_screen.dart';
import 'modules/schedule/screens/admin_schedule_screen.dart';
import 'modules/schedule/screens/student_schedule_screen.dart';
import 'modules/schedule/screens/teacher_schedule_screen.dart';
import 'modules/enrollment/screens/enrollment_form_screen.dart';
import 'modules/enrollment/screens/admin_enrollment_screen.dart';
import 'modules/user/screens/admin_users_screen.dart';
import 'modules/website/screens/public_website_screen.dart';
import 'modules/website/screens/website_editor_screen.dart';
import 'providers/user_provider_v2.dart';
import 'utils/app_navigator.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router == null) {
      final userProvider = context.read<UserProviderV2>();
      _router = _buildRouter(userProvider);
    }
  }

  GoRouter _buildRouter(UserProviderV2 userProvider) {
    bool hasMessagingAccess(dynamic user) {
      if (user == null) return false;
      final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();
      return user.isSuperadmin || perms.contains('mensajeria.ver');
    }

    bool hasWebsiteAccess(dynamic user) {
      if (!kIsWeb || user == null) return false;
      final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();
      return user.isSuperadmin ||
          perms.contains('sitio_web.ver') ||
          perms.contains('sitio_web.editar');
    }

    String homeForRole(String? role) {
      switch (role) {
        case 'Administrador':
          return '/admin_dashboard';
        case 'Docente':
          return '/teacher_dashboard';
        case 'Estudiante':
        case 'Familiar':
          return '/student_dashboard';
        default:
          return '/access_denied';
      }
    }

    bool allowedForRole(dynamic user, String path) {
      final role = user?.role as String?;
      const commons = {'/profile', '/logout', '/access_denied'};
      if (commons.contains(path)) return true;

      switch (role) {
        case 'Administrador':
          return {
            '/admin_dashboard',
            '/admin_user',
            '/management_route',
            '/management_schedule',
            '/management_document',
            '/view_history',
            '/admin_authorization',
            '/enrollment',
            '/admin_parameters',
            '/admin_qr',
            if (hasWebsiteAccess(user)) '/website_admin',
            if (hasMessagingAccess(user)) '/messages',
          }.contains(path);
        case 'Docente':
          return {
            '/teacher_dashboard',
            '/execute_route',
            '/teacher_schedule',
            '/teacher_document',
            '/teacher_authorization',
            if (hasMessagingAccess(user)) '/messages',
          }.contains(path);
        case 'Estudiante':
        case 'Familiar':
          return {
            '/student_dashboard',
            '/my_route',
            '/my_schedule',
            '/student_document',
            '/student_authorization',
            '/enrollment',
            '/student_qr',
            if (hasMessagingAccess(user)) '/messages',
          }.contains(path);
        default:
          return false;
      }
    }

    return GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: kIsWeb ? '/' : '/login',
      refreshListenable: userProvider,
      errorBuilder: (context, state) => const AccessDeniedPage(),
      redirect: (context, state) {
        final user = userProvider.user;
        final currentPath = state.uri.path;
        final loggingIn = currentPath == '/login';
        const publicWebsitePaths = {
          '/',
          '/about',
          '/admissions',
          '/learning',
          '/news-events',
          '/parents',
        };
        const publicPaths = {
          ...publicWebsitePaths,
          '/login',
          '/enrollment_public',
        };

        if (!kIsWeb && publicWebsitePaths.contains(currentPath)) {
          return '/login';
        }
        if (publicWebsitePaths.contains(currentPath)) return null;

        if (user == null) {
          return publicPaths.contains(currentPath) ? null : '/login';
        }

        final home = homeForRole(user.role);
        if (loggingIn) return home;

        if (!allowedForRole(user, currentPath)) {
          return '/access_denied';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PublicWebsiteScreen(slug: 'home'),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const PublicWebsiteScreen(slug: 'about'),
        ),
        GoRoute(
          path: '/admissions',
          builder:
              (context, state) => const PublicWebsiteScreen(slug: 'admissions'),
        ),
        GoRoute(
          path: '/learning',
          builder:
              (context, state) => const PublicWebsiteScreen(slug: 'learning'),
        ),
        GoRoute(
          path: '/news-events',
          builder:
              (context, state) =>
                  const PublicWebsiteScreen(slug: 'news-events'),
        ),
        GoRoute(
          path: '/parents',
          builder:
              (context, state) => const PublicWebsiteScreen(slug: 'parents'),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/enrollment_public',
          builder:
              (context, state) => const EnrollmentFormScreen(
                isPublicLink: true,
                modeOverride: EnrollmentEntryMode.publico,
              ),
        ),
        GoRoute(
          path: '/access_denied',
          builder: (context, state) => const AccessDeniedPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/logout',
          builder: (context, state) => const _LogoutRedirect(),
        ),
        // Admin
        GoRoute(
          path: '/admin_dashboard',
          builder: (context, state) => const AdminDashboardGuard(),
        ),
        GoRoute(
          path: '/admin_user',
          builder: (context, state) => const AdminUsersScreen(),
        ),
        GoRoute(
          path: '/management_route',
          builder: (context, state) => const AdminRoutesScreen(),
        ),
        GoRoute(
          path: '/management_schedule',
          builder: (context, state) => const ScheduleAdminScreen(),
        ),
        GoRoute(
          path: '/management_document',
          builder: (context, state) => const UploadFileScreen(),
        ),
        GoRoute(
          path: '/view_history',
          builder: (context, state) => const AdminHistoryScreen(),
        ),
        GoRoute(
          path: '/admin_authorization',
          builder: (context, state) => const AuthorizationAdminScreen(),
        ),
        GoRoute(
          path: '/admin_parameters',
          builder: (context, state) => const AdminParametersScreen(),
        ),
        GoRoute(
          path: '/admin_qr',
          builder: (context, state) => const AdminQrScreen(),
        ),
        GoRoute(
          path: '/website_admin',
          builder: (context, state) => const WebsiteEditorScreen(),
        ),
        // Docente
        GoRoute(
          path: '/teacher_dashboard',
          builder: (context, state) => const TeacherDashboardGuard(),
        ),
        GoRoute(
          path: '/execute_route',
          builder: (context, state) => const ManageRouteScreen(),
        ),
        GoRoute(
          path: '/teacher_schedule',
          builder: (context, state) => const TeacherScheduleScreen(),
        ),
        GoRoute(
          path: '/teacher_document',
          builder: (context, state) => const UploadFileScreen(),
        ),
        GoRoute(
          path: '/teacher_authorization',
          builder: (context, state) => const AuthorizationTeacherScreen(),
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const MessagingScreen(),
        ),
        // Estudiante / Familiar
        GoRoute(
          path: '/student_dashboard',
          builder: (context, state) => const StudentDashboardGuard(),
        ),
        GoRoute(
          path: '/my_route',
          builder: (context, state) => const MyRoutesScreen(),
        ),
        GoRoute(
          path: '/my_schedule',
          builder: (context, state) => const StudentScheduleScreen(),
        ),
        GoRoute(
          path: '/student_document',
          builder: (context, state) => const ViewFilesScreen(),
        ),
        GoRoute(
          path: '/enrollment',
          builder: (context, state) {
            final user = context.read<UserProviderV2>().user;
            final role = (user?.role ?? '').trim().toLowerCase();
            final isAdmin =
                (user?.isSuperadmin ?? false) || role == 'administrador';
            if (isAdmin) return const AdminEnrollmentScreen();
            return const EnrollmentFormScreen();
          },
        ),
        GoRoute(
          path: '/student_authorization',
          builder: (context, state) => const AuthorizationStudentScreen(),
        ),
        GoRoute(
          path: '/student_qr',
          builder: (context, state) => const StudentQrScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) return const SizedBox.shrink();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Sistema Educativo',
      theme: ThemeData(primarySwatch: Colors.indigo),
      routerConfig: router,
    );
  }
}

class _LogoutRedirect extends StatefulWidget {
  const _LogoutRedirect();

  @override
  State<_LogoutRedirect> createState() => _LogoutRedirectState();
}

class _LogoutRedirectState extends State<_LogoutRedirect> {
  @override
  void initState() {
    super.initState();
    final router = GoRouter.of(context);
    final up = context.read<UserProviderV2>();
    final user = up.user;

    Future.microtask(() => _handleLogout(router, up, user));
  }

  Future<void> _handleLogout(
    GoRouter router,
    UserProviderV2 up,
    dynamic user,
  ) async {
    try {
      if (user != null) {
        await AuthService().logout(user);
      } else {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      // ignorar errores de logout para no bloquear la UI
    } finally {
      up.clearUser();
      if (mounted) {
        router.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
