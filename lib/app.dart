import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'modules/auth/providers/user_provider.dart';
import 'modules/auth/pages/login_page.dart';
import 'modules/auth/pages/access_denied_page.dart';
import 'modules/history/admin_history_screen.dart';
import 'modules/profile/pages/profile_page.dart';
import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/teacher_dashboard_guard.dart';
import 'modules/auth/guards/student_dashboard_guard.dart';

import 'modules/user/screen/admin_users_screen.dart';
import 'modules/route/screen/admin_route_screen.dart';
import 'modules/schedule/screen/admin_schedule_screen.dart';

import 'modules/route/screen/teacher_route_screen.dart';
import 'modules/file/upload_file_screen.dart';

import 'modules/route/screen/student_route_screen.dart';
import 'modules/schedule/screen/shared_schedule_screen.dart';
import 'modules/file/view_file_screen.dart';

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
                // Generales
                case '/profile':
                  page = const ProfilePage();
                  break;
                case '/my_schedule':
                  page = const SharedScheduleScreen();
                  break;
                case '/logout':
                  FirebaseAuth.instance.signOut();
                  page = const LoginPage();
                  break;

                // Del administrador
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
                  page = const ManageScheduleScreen();
                  break;
                case '/management_document':
                  page = const UploadFileScreen();
                  break;
                case '/view_history':
                  page = const AdminHistoryScreen();
                  break;

                // Del docente
                case '/teacher_dashboard':
                  page = const TeacherDashboardGuard();
                  break;
                case '/execute_route':
                  page = const ManageRouteScreen();
                  break;
                case '/teacher_document':
                  page = const UploadFileScreen();
                  break;

                // Del estudiante
                case '/student_dashboard':
                  page = const StudentDashboardGuard();
                  break;
                case '/my_route':
                  page = const MyRoutesScreen();
                  break;
                case '/student_document':
                  page = const ViewFilesScreen();
                  break;

                // Acceso denegado
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
      case 'admin':
        return '/admin_dashboard';
      case 'docente':
        return '/teacher_dashboard';
      case 'estudiante':
        return '/student_dashboard';
      default:
        return '/access_denied';
    }
  }
}
