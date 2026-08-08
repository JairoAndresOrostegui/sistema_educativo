import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../authorization/services/authorization_service.dart';
import 'dashboard_layout.dart';

class DocenteDashboardLayout extends StatefulWidget {
  const DocenteDashboardLayout({super.key});

  @override
  State<DocenteDashboardLayout> createState() => _DocenteDashboardLayoutState();
}

class _DocenteDashboardLayoutState extends State<DocenteDashboardLayout> {
  List<MenuItemData> _menuItems = [];
  bool isLoading = true;
  StreamSubscription<int>? _pendingAuthSub;

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

    if (user.isSuperadmin ||
        perms.contains('usuarios.ver') ||
        perms.contains('usuarios.editar')) {
      items.add(
        const MenuItemData(
          label: 'Gesti\u00f3n de usuarios',
          icon: Icons.group,
          route: '/admin_user',
        ),
      );
    }

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

    if (user.isSuperadmin ||
        perms.contains('matricula.ver') ||
        perms.contains('matricula.editar')) {
      items.add(
        const MenuItemData(
          label: 'Matrículas',
          icon: Icons.assignment_ind,
          route: '/enrollment',
        ),
      );
    }

    if (user.isSuperadmin || perms.contains('mensajeria.ver')) {
      items.add(
        const MenuItemData(
          label: 'Mensajeria',
          icon: Icons.chat_bubble_outline,
          route: '/messages',
        ),
      );
    }

    setState(() {
      _menuItems = items;
      isLoading = false;
    });

    if (user.isSuperadmin || perms.contains('autorizaciones.ver')) {
      final groupId = (user.groupId ?? '').trim();
      if (groupId.isNotEmpty) {
        _pendingAuthSub?.cancel();
        _pendingAuthSub = AuthorizationService()
            .watchPendingCountForGroup(
              institutionId: user.institution,
              campusId: user.campus,
              groupId: groupId,
            )
            .listen((count) {
              if (!mounted) return;
              setState(() {
                _menuItems = _menuItems
                    .map(
                      (m) => m.route == '/teacher_authorization'
                          ? MenuItemData(
                              label: m.label,
                              icon: m.icon,
                              route: m.route,
                              badgeCount: count,
                            )
                          : m,
                    )
                    .toList();
              });
            });
      }
    }
  }

  @override
  void dispose() {
    _pendingAuthSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Scaffold(
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: AppPalette.primary),
              ),
            ),
          )
        : DashboardLayout(menuItems: _menuItems);
  }
}
