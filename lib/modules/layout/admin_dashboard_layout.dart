import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/pages/dashboard_layout.dart';

class AdminDashboardLayout extends StatefulWidget {
  const AdminDashboardLayout({super.key});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  List<MenuItemData> _menuItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
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
    final bool esSuperadmin = data['esSuperadmin'] == true;

    final List<MenuItemData> items = [
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (esSuperadmin || funcionalidades.contains('usuarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gestión de usuarios',
          icon: Icons.group,
          route: '/admin_user',
        ),
      );
    }

    if (esSuperadmin || funcionalidades.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gestión de rutas',
          icon: Icons.route,
          route: '/management_route',
        ),
      );
    }

    if (esSuperadmin || funcionalidades.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/management_schedule',
        ),
      );
    }

    if (esSuperadmin || funcionalidades.contains('documentos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_copy,
          route: '/management_document',
        ),
      );
    }

    if (esSuperadmin || funcionalidades.contains('historial_rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Historial administrativo',
          icon: Icons.file_copy,
          route: '/view_history',
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
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : DashboardLayout(menuItems: _menuItems);
  }
}
