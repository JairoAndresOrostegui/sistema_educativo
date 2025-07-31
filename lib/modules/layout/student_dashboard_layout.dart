import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../auth/pages/dashboard_layout.dart';

class EstudianteDashboardLayout extends StatefulWidget {
  const EstudianteDashboardLayout({super.key});

  @override
  State<EstudianteDashboardLayout> createState() =>
      _EstudianteDashboardLayoutState();
}

class _EstudianteDashboardLayoutState extends State<EstudianteDashboardLayout> {
  List<MenuItemData> _menuItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMenu();
    _escucharNotificaciones();
  }

  void _escucharNotificaciones() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final titulo = message.notification!.title ?? 'Notificación';
        final cuerpo = message.notification!.body ?? '';
        _mostrarAlerta(titulo, cuerpo);
      }
    });
  }

  void _mostrarAlerta(String titulo, String cuerpo) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(titulo),
            content: Text(cuerpo),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _cargarMenu() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
    final data = doc.data();
    if (data == null || data['rol'] != 'estudiante') return;

    final List<String> funcionalidades =
        (data['funcionalidades'] is List)
            ? List<String>.from(data['funcionalidades'])
            : [];

    final List<MenuItemData> items = [
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (funcionalidades.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Mis rutas',
          icon: Icons.route,
          route: '/my_route',
        ),
      );
    }

    if (funcionalidades.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/my_schedule',
        ),
      );
    }

    if (funcionalidades.contains('documentos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_download,
          route: '/student_document',
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _menuItems = items;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Colors.redAccent),
          ),
        )
        : DashboardLayout(menuItems: _menuItems);
  }
}
