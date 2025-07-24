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

    final funcionalidades = Map<String, dynamic>.from(
      data['funcionalidades'] ?? {},
    );
    final rol = data['rol'];

    if (rol != 'docente') return;

    final List<MenuItemData> items = [
      const MenuItemData(label: 'Perfil', icon: Icons.person, route: '/perfil'),
    ];

    if (funcionalidades['rutas']?.contains('ver') ?? false) {
      items.add(
        const MenuItemData(
          label: 'Ruta escolar',
          icon: Icons.directions_bus,
          route: '/rutas_docente',
        ),
      );
    }

    if (funcionalidades['usuarios']?.contains('ver') ?? false) {
      items.add(
        const MenuItemData(
          label: 'Gestión de usuarios',
          icon: Icons.group,
          route: '/usuarios',
        ),
      );
    }

    if (funcionalidades['horarios']?.contains('ver') ?? false) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/gestionar_horario',
        ),
      );
    }

    if ((funcionalidades['documentos']?.contains('ver') ?? false)) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_copy,
          route: '/documentos_docente',
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
