import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_layout.dart';
import '../../../providers/user_provider_v2.dart';

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
    _buildMenu();
  }

  void _buildMenu() {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;

    final role = user.role.trim().toLowerCase();
    if (!(user.isSuperadmin || role == 'docente')) return;

    final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();

    final items = <MenuItemData>[
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (user.isSuperadmin || perms.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Ruta escolar',
          icon: Icons.directions_bus,
          route: '/execute_route',
        ),
      );
    }

    if (user.isSuperadmin || perms.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/teacher_schedule',
        ),
      );
    }

    if (user.isSuperadmin || perms.contains('archivos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_copy,
          route: '/teacher_document',
        ),
      );
    }

    if (user.isSuperadmin || perms.contains('autorizaciones.ver')) {
      items.add(
        const MenuItemData(
          label: 'Autorizaciones',
          icon: Icons.policy,
          route: '/teacher_authorization',
        ),
      );
    }

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
