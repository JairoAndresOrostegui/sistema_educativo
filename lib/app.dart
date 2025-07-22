import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'modules/admin/pages/admin_rutas_screen.dart';
import 'modules/auth/pages/login_page.dart';
import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/docente_dashboard_guard.dart';
import 'modules/auth/guards/estudiante_dashboard_guard.dart';
import 'modules/admin/pages/admin_usuarios_screen.dart';
import 'modules/docente/pages/gestionar_ruta_screen.dart';
import 'modules/estudiante/pages/mis_rutas_screen.dart';
import 'modules/auth/pages/profile_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Educativo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/admin_dashboard': (context) => const AdminDashboardGuard(),
        '/docente_dashboard': (context) => const DocenteDashboardGuard(),
        '/estudiante_dashboard': (context) => const EstudianteDashboardGuard(),
        '/perfil': (context) => const ProfilePage(),
        '/usuarios': (context) => const AdminUsuariosScreen(),
        '/rutas': (context) => const AdminRutasScreen(),
        '/rutas_docente': (context) => const GestionarRutaScreen(),
        '/mis_rutas': (context) => const MisRutasScreen(),
        '/logout': (context) {
          FirebaseAuth.instance.signOut();
          return const LoginPage();
        },
      },
    );
  }
}
