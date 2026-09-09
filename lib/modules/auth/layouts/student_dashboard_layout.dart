import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/active_academic_year_context.dart';
import '../../../utils/parameters_service.dart';
import '../../enrollment/services/enrollment_service.dart';
import '../../messaging/services/messaging_service.dart';
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
  StreamSubscription<int>? _messageUnreadSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  @override
  void initState() {
    super.initState();
    _buildMenu();
    _listenNotifications();
  }

  void _listenNotifications() {
    _foregroundMessageSub?.cancel();
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (!mounted) return;
      final notif = message.notification;
      if (notif == null) return;
      final titulo = notif.title ?? 'Notificación';
      final cuerpo = notif.body ?? '';
      _showAlert(titulo, cuerpo);
    }, onError: (_) {});
  }

  void _showAlert(String titulo, String cuerpo) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
    final role = user.role.trim().toLowerCase();

    final items = <MenuItemData>[
      const MenuItemData(
        label: 'Perfil',
        icon: Icons.person,
        route: '/profile',
      ),
    ];

    if (role == 'familiar' && perms.contains('matricula.ver')) {
      final showEnrollment = await _shouldShowEnrollmentMenu(
        user.id,
        user.institution,
        user.campus,
      );
      if (showEnrollment) {
        items.add(
          const MenuItemData(
            label: 'Matricula',
            icon: Icons.assignment_ind,
            route: '/enrollment',
          ),
        );
      }
    }

    if (role == 'familiar' || role == 'estudiante') {
      items.add(
        const MenuItemData(label: 'QR', icon: Icons.qr_code, route: '/my_qr'),
      );
    }

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

    if (role == 'familiar' && perms.contains('autorizaciones.ver')) {
      items.add(
        const MenuItemData(
          label: 'Autorizaciones',
          icon: Icons.policy,
          route: '/student_authorization',
        ),
      );
    }

    if (perms.contains('mensajeria.ver')) {
      items.add(
        const MenuItemData(
          label: 'Mensajeria',
          icon: Icons.chat_bubble_outline,
          route: '/messages',
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _menuItems = items;
      isLoading = false;
    });
    if (perms.contains('mensajeria.ver')) {
      _messageUnreadSub?.cancel();
      _messageUnreadSub = MessagingService().watchUnreadCount(user).listen((
        unreadCount,
      ) {
        if (!mounted) return;
        setState(
          () => _menuItems = _menuItems
              .map(
                (item) => item.route == '/messages'
                    ? MenuItemData(
                        label: item.label,
                        icon: item.icon,
                        route: item.route,
                        badgeCount: unreadCount,
                      )
                    : item,
              )
              .toList(),
        );
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    _messageUnreadSub?.cancel();
    super.dispose();
  }

  Future<bool> _shouldShowEnrollmentMenu(
    String userId,
    String institutionId,
    String campusId,
  ) async {
    try {
      final params = ParametersService();
      final enabled = await params.getEnrollmentParentEnabled();
      if (!enabled) return false;

      final activeYear = await loadActiveAcademicYear(
        firestore: FirebaseFirestore.instance,
        institutionId: institutionId,
        campusId: campusId,
      );
      final hasMatricula = await EnrollmentService().hasEnrollmentForUser(
        userId: userId,
        estados: ['matriculado'],
        anioMatricula: activeYear.year,
      );
      return !hasMatricula;
    } catch (_) {
      return false;
    }
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
