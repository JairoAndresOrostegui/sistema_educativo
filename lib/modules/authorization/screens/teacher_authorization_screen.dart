import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../services/authorization_service.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/user_facing_error.dart';
import '../widgets/teacher_authorization_dialog.dart';

class AuthorizationTeacherScreen extends StatefulWidget {
  final AuthorizationService? service;

  const AuthorizationTeacherScreen({super.key, this.service});

  @override
  State<AuthorizationTeacherScreen> createState() =>
      _AuthorizationTeacherScreenState();
}

class _AuthorizationTeacherScreenState
    extends State<AuthorizationTeacherScreen> {
  late final _svc = widget.service ?? AuthorizationService();
  StreamSubscription<List<AuthorizationRequest>>? _itemsSub;

  userModelv2? _logged;
  bool _isSuperadmin = false;
  List<String> _perms = [];
  late String _institutionId;
  late String _campusId;

  final List<AuthorizationRequest> _items = [];
  bool _loading = true;
  Object? _loadError;
  final int _perPage = 20;

  String? _activeGroupId;

  bool get _canView {
    if (_logged == null) return false;
    return _isSuperadmin || _perms.contains('autorizaciones.ver');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final u = context.read<UserProviderV2>().user;
    if (u == null) return;

    _logged = u;
    _isSuperadmin = u.isSuperadmin;
    _perms = u.permissions
        .map((permission) => permission.trim().toLowerCase())
        .where((permission) => permission.isNotEmpty)
        .toList();
    _institutionId = u.institution;
    _campusId = u.campus;

    if (!_canView) {
      setState(() {});
      return;
    }

    final groupId = (u.groupId ?? '').trim();
    if (groupId.isEmpty) {
      setState(() {
        _activeGroupId = null;
        _loading = false;
      });
      return;
    } else {
      _activeGroupId = groupId;
    }

    _subscribeToItems();
  }

  void _subscribeToItems() {
    if (_activeGroupId == null || _activeGroupId!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _itemsSub?.cancel();
    _itemsSub = _svc
        .watchForGroup(
          institutionId: _institutionId,
          campusId: _campusId,
          groupId: _activeGroupId!,
          limit: _perPage,
        )
        .listen(
          (items) {
            if (!mounted) return;
            setState(() {
              _items
                ..clear()
                ..addAll(items);
              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _loadError = error;
              _loading = false;
            });
          },
        );
  }

  String _fmtD(DateTime? d) =>
      d == null ? '-' : DateFormat('yyyy-MM-dd').format(d);
  String _fmtT(DateTime? d) => d == null ? '-' : DateFormat('HH:mm').format(d);

  String _statusLabel(AuthorizationStatus s) {
    switch (s) {
      case AuthorizationStatus.pending:
        return 'Pendiente';
      case AuthorizationStatus.approved:
        return 'Aprobada';
      case AuthorizationStatus.rejected:
        return 'Rechazada';
      case AuthorizationStatus.finished:
        return 'Finalizada';
    }
  }

  Color _statusColor(ColorScheme colors, AuthorizationStatus s) {
    switch (s) {
      case AuthorizationStatus.pending:
        return colors.tertiary;
      case AuthorizationStatus.approved:
        return colors.primary;
      case AuthorizationStatus.rejected:
        return colors.error;
      case AuthorizationStatus.finished:
        return colors.secondary;
    }
  }

  String _firstWords(String text, int n) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length <= n) return text.trim();
    return '${parts.take(n).join(' ')}...';
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = context.watch<UserProviderV2>().user;
    if (session == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('No hay sesión activa.'))),
      );
    }

    if (!_canView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Autorizaciones'),
          leading: const BackToDashboardButton(),
          backgroundColor: colors.surface,
          foregroundColor: colors.primary,
          centerTitle: true,
        ),
        body: const SafeArea(child: Center(child: Text('Acceso denegado.'))),
        backgroundColor: colors.surface,
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Autorizaciones (Docente)'),
        leading: const BackToDashboardButton(),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.onSurface.withValues(alpha: .03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _activeGroupId == null || _activeGroupId!.isEmpty
                            ? 'Sin grupo asignado'
                            : 'Grupo: ${_logged?.groupName ?? ''}',
                      ),
                    ),
                    Text('Total: ${_items.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userFacingError(
                                _loadError!,
                                fallback:
                                    'No se pudieron cargar las autorizaciones.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _subscribeToItems,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _activeGroupId == null || _activeGroupId!.isEmpty
                    ? const Center(
                        child: Text('No hay grupo asignado al docente.'),
                      )
                    : _items.isEmpty
                    ? const Center(child: Text('No hay solicitudes'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final r = _items[i];
                          final sc = _statusColor(colors, r.status);
                          final chip = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: sc.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sc.withValues(alpha: .25),
                              ),
                            ),
                            child: Text(
                              _statusLabel(r.status),
                              style: TextStyle(
                                color: sc,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          );
                          final dateLine = r.multiDay
                              ? '${_fmtD(r.dateFrom)} → ${_fmtD(r.dateTo)}'
                              : _fmtD(r.dateFrom);
                          final timeLine = r.allDay
                              ? 'Todo el día'
                              : r.endTime != null
                              ? '${_fmtT(r.startTime)} - ${_fmtT(r.endTime)}'
                              : _fmtT(r.startTime);
                          final sub = [
                            'Fecha: $dateLine',
                            'Hora: $timeLine',
                            if ((r.reason ?? '').toString().trim().isNotEmpty)
                              'Motivo: ${_firstWords(r.reason!, 40)}',
                          ].join('\n');

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: .12),
                              ),
                              color: colors.surfaceContainer,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.assignment_turned_in,
                                color: colors.primary,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${r.studentFullName} — ${r.groupName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  chip,
                                ],
                              ),
                              subtitle: Text(sub),
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    AuthorizationDetailsDialog(request: r),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
