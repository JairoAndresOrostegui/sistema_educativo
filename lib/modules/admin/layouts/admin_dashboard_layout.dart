import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/dashboard_layout.dart';

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

    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    final data = doc.data();

    if (data == null) return;

    final funcionalidades = Map<String, dynamic>.from(data['funcionalidades'] ?? {});
    final esSuperadmin = data['esSuperadmin'] == true;

    final List<MenuItemData> items = [
      const MenuItemData(label: 'Perfil', icon: Icons.person, route: '/perfil'),
    ];

    if (esSuperadmin || (funcionalidades['usuarios']?.contains('ver') ?? false)) {
      items.add(const MenuItemData(label: 'Gestión de usuarios', icon: Icons.group, route: '/usuarios'));
    }

    if (esSuperadmin || (funcionalidades['rutas']?.contains('ver') ?? false)) {
      items.add(const MenuItemData(label: 'Gestión de rutas', icon: Icons.route, route: '/rutas'));
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
