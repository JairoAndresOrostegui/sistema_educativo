import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../enrollment/services/enrollment_service.dart';
import 'dashboard_layout.dart';

class AdminDashboardLayout extends StatefulWidget {
  const AdminDashboardLayout({super.key});

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  List<MenuItemData> _menuItems = [];
  bool isLoading = true;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _buildMenu();
    _listenPending();
  }

  Future<void> _buildMenu() async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;

    final role = user.role.trim().toLowerCase();
    if (!(user.isSuperadmin || role == 'administrador')) return;

    final perms = user.permissions.map((e) => e.trim().toLowerCase()).toSet();
    final esSuperadmin = user.isSuperadmin;

    int pendingEnrollments = 0;
    try {
      pendingEnrollments = await EnrollmentService()
          .countByEstados(['prematriculado', 'pendiente_revision']);
    } catch (_) {
      pendingEnrollments = 0;
    }

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
          label: 'Gesti\u00f3n de usuarios',
          icon: Icons.group,
          route: '/admin_user',
        ),
      );
    }

    items.add(
      const MenuItemData(
        label: 'Par\u00e1metros',
        icon: Icons.tune,
        route: '/admin_parameters',
      ),
    );

    if (esSuperadmin || perms.contains('matricula.ver')) {
      items.add(
        MenuItemData(
          label: 'Matr\u00edculas',
          icon: Icons.assignment_ind,
          route: '/enrollment',
          badgeCount: pendingEnrollments,
        ),
      );
    }

    if (esSuperadmin || perms.contains('rutas.ver')) {
      items.add(
        const MenuItemData(
          label: 'Gesti\u00f3n de rutas',
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

    if (esSuperadmin ||
        perms.contains('codigoqr.crear') ||
        perms.contains('codigoqr.editar')) {
      items.add(
        const MenuItemData(
          label: 'QR',
          icon: Icons.qr_code,
          route: '/admin_qr',
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _menuItems = items;
      isLoading = false;
    });
  }

  void _listenPending() {
    _pendingStream = FirebaseFirestore.instance
        .collection('enrollments')
        .where('estado', whereIn: ['prematriculado', 'pendiente_revision'])
        .snapshots();
    _pendingSub = _pendingStream!.listen((snapshot) {
      final count = snapshot.size;
      if (!mounted) return;
      setState(() {
        _menuItems = _menuItems
            .map(
              (m) => m.route == '/enrollment'
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

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
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
