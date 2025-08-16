import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_layout.dart';
import '../../../providers/user_provider_V2.dart';

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
    _buildMenu();
  }

  void _buildMenu() {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;

    final role = user.role.trim().toLowerCase();
    if (!(user.isSuperadmin || role == 'administrador')) return;

    final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();
    final esSuperadmin = user.isSuperadmin;

    final items = <MenuItemData>[
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (esSuperadmin || perms.contains('usuarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gestión de usuarios',
          icon: Icons.group,
          route: '/admin_user',
        ),
      );
    }

    if (esSuperadmin || perms.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gestión de rutas',
          icon: Icons.route,
          route: '/management_route',
        ),
      );
    }

    if (esSuperadmin || perms.contains('horarios.ver')) {
      items.add(
        const MenuItemData(
          label: 'Horario escolar',
          icon: Icons.timer,
          route: '/management_schedule',
        ),
      );
    }

    if (esSuperadmin || perms.contains('archivos.ver')) {
      items.add(
        const MenuItemData(
          label: 'Documentos',
          icon: Icons.file_copy,
          route: '/management_document',
        ),
      );
    }

    if (esSuperadmin || perms.contains('historial_rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Historial administrativo',
          icon: Icons.history,
          route: '/view_history',
        ),
      );
    }

    if (esSuperadmin || perms.contains('autorizaciones.ver')) {
      items.add(
        const MenuItemData(
          label: 'Autorizaciones',
          icon: Icons.policy,
          route: '/admin_authorization',
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
