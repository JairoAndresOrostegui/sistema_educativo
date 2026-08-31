import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../authorization/services/authorization_service.dart';
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
  StreamSubscription<int>? _pendingAuthSub;

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
      pendingEnrollments = await EnrollmentService().countByEstados(
        ['prematriculado', 'pendiente_revision', 'correccion_solicitada'],
        institution: esSuperadmin ? null : user.institution,
        campus: esSuperadmin ? null : user.campus,
      );
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

    if (esSuperadmin ||
        perms.contains('matricula.ver') ||
        perms.contains('matricula.editar')) {
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

    if (esSuperadmin ||
        perms.contains('horarios.ver') ||
        perms.contains('horarios.crear') ||
        perms.contains('horarios.editar') ||
        perms.contains('horarios.eliminar')) {
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

    if (esSuperadmin ||
        perms.contains('autorizaciones.ver') ||
        perms.contains('autorizaciones.editar')) {
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

    if (esSuperadmin || perms.contains('mensajeria.ver')) {
      items.add(
        const MenuItemData(
          label: 'Mensajeria',
          icon: Icons.chat_bubble_outline,
          route: '/messages',
        ),
      );
    }

    if (kIsWeb &&
        (esSuperadmin ||
            perms.contains('sitio_web.ver') ||
            perms.contains('sitio_web.editar'))) {
      items.add(
        const MenuItemData(
          label: 'Sitio web',
          icon: Icons.language,
          route: '/website_admin',
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _menuItems = items;
      isLoading = false;
    });

    _listenPendingAuthorizations(
      user.institution,
      user.campus,
      allCampuses: user.isSuperadmin,
    );
  }

  Future<void> _listenPending() async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('enrollments')
        .where(
          'estado',
          whereIn: [
            'prematriculado',
            'pendiente_revision',
            'correccion_solicitada',
          ],
        );
    if (user.isSuperadmin) {
      final settings = await FirebaseFirestore.instance
          .collection('academic_year_settings')
          .get();
      final ids = settings.docs
          .map((item) => (item.data()['activeYearId'] ?? '').toString())
          .where((item) => item.isNotEmpty)
          .take(30)
          .toList();
      if (ids.isEmpty) return;
      query = query.where('academicYearId', whereIn: ids);
    } else {
      final settings = await FirebaseFirestore.instance
          .collection('academic_year_settings')
          .where('institutionId', isEqualTo: user.institution)
          .where('campusId', isEqualTo: user.campus)
          .limit(1)
          .get();
      if (settings.docs.isEmpty) return;
      query = query.where(
        'academicYearId',
        isEqualTo: settings.docs.first.data()['activeYearId'],
      );
    }
    if (!user.isSuperadmin) {
      query = query
          .where('institution', isEqualTo: user.institution)
          .where('campus', isEqualTo: user.campus);
    }
    _pendingStream = query.snapshots();
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

  void _listenPendingAuthorizations(
    String institutionId,
    String campusId, {
    required bool allCampuses,
  }) {
    _pendingAuthSub?.cancel();
    _pendingAuthSub = AuthorizationService()
        .watchPendingCountForAdmin(
          institutionId: allCampuses ? null : institutionId,
          campusId: allCampuses ? null : campusId,
        )
        .listen((pendingCount) {
          if (!mounted) return;
          setState(() {
            _menuItems = _menuItems
                .map(
                  (m) => m.route == '/admin_authorization'
                      ? MenuItemData(
                          label: m.label,
                          icon: m.icon,
                          route: m.route,
                          badgeCount: pendingCount,
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
