import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'modules/auth/providers/user_provider.dart';
import 'modules/auth/pages/login_page.dart';
import 'modules/auth/pages/access_denied_page.dart';
import 'modules/profile/pages/profile_page.dart';
import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/teacher_dashboard_guard.dart';
import 'modules/auth/guards/student_dashboard_guard.dart';

import 'modules/admin/pages/admin_users_screen.dart';
import 'modules/admin/pages/admin_routes_screen.dart';
import 'modules/admin/pages/admin_schedule_screen.dart';
import 'modules/admin/pages/admin_route_history_screen.dart';

import 'modules/teacher/pages/manage_route_screen.dart';
import 'modules/teacher/pages/manage_schedule_screen.dart';
import 'modules/teacher/pages/upload_file_screen.dart';

import 'modules/student/pages/my_routes_screen.dart';
import 'modules/student/pages/my_schedule_screen.dart';
import 'modules/student/pages/view_files_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema Educativo',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Consumer<UsuarioProvider>(
        builder: (context, usuarioProvider, child) {
          final estado = usuarioProvider.estado;
          final usuario = usuarioProvider.usuario;

          if (estado == EstadoUsuario.cargando) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (estado == EstadoUsuario.noAutenticado || usuario == null) {
            return const LoginPage();
          }
          final String initialRouteName = _routeByRol(usuario.rol);

          return Navigator(
            initialRoute: initialRouteName,
            onGenerateRoute: (settings) {
              Widget page;
              switch (settings.name) {
                case '/profile':
                  page = const ProfilePage();
                  break;
                case '/admin_dashboard':
                  page = const AdminDashboardGuard();
                  break;
                case '/docente_dashboard':
                  page = const TeacherDashboardGuard();
                  break;
                case '/estudiante_dashboard':
                  page = const StudentDashboardGuard();
                  break;
                case '/users':
                  page = const AdminUsersScreen();
                  break;
                case '/routes':
                  page = const AdminRoutesScreen();
                  break;
                case '/school_schedule':
                  page = const AdminScheduleScreen();
                  break;
                case '/admin_documents':
                  page = const UploadFileScreen();
                  break;
                case '/admin_route_history':
                  page = const AdminRouteHistoryScreen();
                  break;
                case '/manage_routes':
                  page = const ManageRouteScreen();
                  break;
                case '/manage_schedule':
                  page = const ManageScheduleScreen();
                  break;
                case '/teacher_documents':
                  page = const UploadFileScreen();
                  break;
                case '/my_routes':
                  page = const MyRoutesScreen();
                  break;
                case '/my_schedule':
                  page = const MyScheduleScreen();
                  break;
                case '/student_documents':
                  page = const ViewFilesScreen();
                  break;
                case '/logout':
                  FirebaseAuth.instance.signOut();
                  page = const LoginPage();
                  break;
                default:
                  page = const AccessDeniedPage();
                  break;
              }
              return MaterialPageRoute(builder: (context) => page, settings: settings);
            },
          );
        },
      ),
    );
  }

  String _routeByRol(String? rol) {
    switch (rol) {
      case 'admin':
        return '/admin_dashboard';
      case 'docente':
        return '/docente_dashboard';
      case 'estudiante':
        return '/estudiante_dashboard';
      default:
        return '/access_denied';
    }
  }
}
