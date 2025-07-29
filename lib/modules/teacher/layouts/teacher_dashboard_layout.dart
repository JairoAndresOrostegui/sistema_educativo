import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/dashboard_layout.dart';

class DocenteDashboardLayout extends StatefulWidget {
  const DocenteDashboardLayout({super.key});

  @override
  State<DocenteDashboardLayout> createState() => _DocenteDashboardLayoutState();
}

class _DocenteDashboardLayoutState extends State<DocenteDashboardLayout> {
  List<MenuItemData> _menuItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMenu();
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
    if (data == null) return;

    final List<String> funcionalidades =
        (data['funcionalidades'] is List)
            ? List<String>.from(data['funcionalidades'])
            : [];

    final String rol = data['rol'] ?? '';

    if (rol != 'docente') return;

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
          label: 'Ruta escolar',
          icon: Icons.directions_bus,
          route: '/manage_routes',
        ),
      );
    }

    if (funcionalidades.contains('usuarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gestión de usuarios',
          icon: Icons.group,
          route: '/users',
        ),
      );
    }

    if (funcionalidades.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/manage_schedule',
        ),
      );
    }

    if (funcionalidades.contains('documentos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_copy,
          route: '/teacher_documents',
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
