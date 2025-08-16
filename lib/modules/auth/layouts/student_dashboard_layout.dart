import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_V2.dart';
import 'dashboard_layout.dart';

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
    _buildMenu();
    _listenNotifications();
  }

  void _listenNotifications() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      final notif = message.notification;
      if (notif == null) return;
      final titulo = notif.title ?? 'Notificación';
      final cuerpo = notif.body ?? '';
      _showAlert(titulo, cuerpo);
    });
  }

  void _showAlert(String titulo, String cuerpo) {
    if (!mounted) return;
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

  Future<void> _buildMenu() async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;

    final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();

    final items = <MenuItemData>[
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (perms.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Mis rutas',
          icon: Icons.directions_bus,
          route: '/my_route',
        ),
      );
    }

    if (perms.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/my_schedule',
        ),
      );
    }

    if (perms.contains('archivos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_download,
          route: '/student_document',
        ),
      );
    }

    if (perms.contains('autorizaciones.ver')) {
      items.add(
        const MenuItemData(
          label: 'Autorizaciones',
          icon: Icons.policy,
          route: '/student_authorization',
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
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
          ),
        )
        : DashboardLayout(menuItems: _menuItems);
  }
}
