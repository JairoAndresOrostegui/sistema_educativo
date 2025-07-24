import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'modules/admin/pages/admin_historial_rutas_screen.dart';
import 'modules/admin/pages/admin_horario_screen.dart';
import 'modules/admin/pages/admin_rutas_screen.dart';
import 'modules/auth/pages/login_page.dart';
import 'modules/auth/guards/admin_dashboard_guard.dart';
import 'modules/auth/guards/docente_dashboard_guard.dart';
import 'modules/auth/guards/estudiante_dashboard_guard.dart';
import 'modules/admin/pages/admin_usuarios_screen.dart';
import 'modules/docente/pages/gestionar_horario_screen.dart';
import 'modules/docente/pages/gestionar_ruta_screen.dart';
import 'modules/docente/pages/subir_archivo_screen.dart';
import 'modules/estudiante/pages/mis_horarios_screen.dart';
import 'modules/estudiante/pages/mis_rutas_screen.dart';
import 'modules/auth/pages/profile_page.dart';
import 'modules/estudiante/pages/ver_archivos_screen.dart';

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
        //Ruta raiz
        '/': (context) => const LoginPage(),

        //Inicio de sesion
        '/login': (context) => const LoginPage(),

        //Rutas de rol
        '/admin_dashboard': (context) => const AdminDashboardGuard(),
        '/docente_dashboard': (context) => const DocenteDashboardGuard(),
        '/estudiante_dashboard': (context) => const EstudianteDashboardGuard(),

        //Rutas generales
        '/perfil': (context) => const ProfilePage(),

        //Rutas del administrador
        '/usuarios': (context) => const AdminUsuariosScreen(),
        '/rutas': (context) => const AdminRutasScreen(),
        '/horario_escolar': (context) => const AdminHorarioScreen(),
        '/documentos_admin': (context) => const SubirArchivoScreen(),
        '/admin_historial_rutas': (context) => const AdminHistorialRutasScreen(),

        //Rutas del docente
        '/rutas_docente': (context) => const GestionarRutaScreen(),
        '/gestionar_horario': (context) => const GestionarHorarioScreen(),
        '/documentos_docente': (context) => const SubirArchivoScreen(),

        //Rutas del estudiante
        '/mis_rutas': (context) => const MisRutasScreen(),
        '/mis_horarios': (context) => const MisHorariosScreen(),
        '/documentos_estudiante': (context) => const VerArchivosScreen(),

        '/logout': (context) {
          FirebaseAuth.instance.signOut();
          return const LoginPage();
        },
      },
    );
  }
}
