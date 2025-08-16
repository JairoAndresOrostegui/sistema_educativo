import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sistema_educativo/providers/user_provider_V2.dart';

import 'modules/auth/screens/loginScreenV2.dart';
import 'modules/auth/screens/access_denied_page.dart';
import 'modules/authorization/screens/admin_authorization_screen.dart';
import 'modules/authorization/screens/student_authorization_screen.dart';
import 'modules/authorization/screens/teacher_authorization_screen.dart';
import 'modules/history/screens/admin_history_screen.dart';
import 'modules/profile/screens/profile_page.dart';
import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/teacher_dashboard_guard.dart';
import 'modules/auth/guards/student_dashboard_guard.dart';
import 'modules/schedule/screens/student_schedule_screen.dart';
import 'modules/schedule/screens/teacher_schedule_screen.dart';
import 'modules/user/screens/admin_users_screen.dart';
import 'modules/route/screens/admin_route_screen.dart';
import 'modules/schedule/screens/admin_schedule_screen.dart';
import 'modules/route/screens/teacher_route_screen.dart';
import 'modules/file/screens/upload_file_screen.dart';
import 'modules/route/screens/student_route_screen.dart';
import 'modules/file/screens/view_file_screen.dart';

// NEW: para disparar logout con log y limpiar provider
import 'modules/auth/services/authServiceV2.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema Educativo',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Consumer<UserProviderV2>(
        builder: (context, usuarioProvider, child) {
          final usuario = usuarioProvider.user;

          if (usuario == null) {
            return const LoginScreen();
          }

          final String initialRouteName = _routeByRol(usuario.role);

          return Navigator(
            initialRoute: initialRouteName,
            onGenerateRoute: (settings) {
              Widget page;
              switch (settings.name) {
                // Generales
                case '/profile':
                  page = const ProfilePage();
                  break;
                case '/logout':
                  page = const _LogoutRedirect();
                  break;

                case '/access_denied':
                  page = const AccessDeniedPage();
                  break;

                // Admin
                case '/admin_dashboard':
                  page = const AdminDashboardGuard();
                  break;
                case '/admin_user':
                  page = const AdminUsersScreen();
                  break;
                case '/management_route':
                  page = const AdminRoutesScreen();
                  break;
                case '/management_schedule':
                  page = const ScheduleAdminScreen();
                  break;
                case '/management_document':
                  page = const UploadFileScreen();
                  break;
                case '/view_history':
                  page = const AdminHistoryScreen();
                  break;
                case '/admin_authorization':
                  page = const AuthorizationAdminScreen();
                  break;

                // Docente
                case '/teacher_dashboard':
                  page = const TeacherDashboardGuard();
                  break;
                case '/execute_route':
                  page = const ManageRouteScreen();
                  break;
                case '/teacher_schedule':
                  page = const TeacherScheduleScreen();
                  break;
                case '/teacher_document':
                  page = const UploadFileScreen();
                  break;
                case '/teacher_authorization':
                  page = const AuthorizationTeacherScreen();
                  break;

                // Estudiante/Familiar
                case '/student_dashboard':
                  page = const StudentDashboardGuard();
                  break;
                case '/my_route':
                  page = const MyRoutesScreen();
                  break;
                case '/my_schedule':
                  page = const StudentScheduleScreen();
                  break;
                case '/student_document':
                  page = const ViewFilesScreen();
                  break;
                case '/student_authorization':
                  page = const AuthorizationStudentScreen();
                  break;

                default:
                  page = const AccessDeniedPage();
                  break;
              }
              return MaterialPageRoute(
                builder: (context) => page,
                settings: settings,
              );
            },
          );
        },
      ),
    );
  }

  String _routeByRol(String? rol) {
    switch (rol) {
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
    // Microtask para no interferir con la construcción de la ruta
    Future.microtask(() async {
      final up = context.read<UserProviderV2>();
      final user = up.user;

      try {
        if (user != null) {
          await AuthService().logout(user); // guarda log + signOut
        } else {
          await FirebaseAuth.instance.signOut();
        }
      } catch (_) {
        // ignorar errores de logout para no bloquear la UI
      } finally {
        up.clearUser();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla de transición
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
