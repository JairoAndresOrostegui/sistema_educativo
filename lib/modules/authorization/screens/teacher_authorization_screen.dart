import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../services/authorization_service.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../widgets/teacher_authorization_dialog.dart';

class AuthorizationTeacherScreen extends StatefulWidget {
  const AuthorizationTeacherScreen({super.key});

  @override
  State<AuthorizationTeacherScreen> createState() =>
      _AuthorizationTeacherScreenState();
}

class _AuthorizationTeacherScreenState
    extends State<AuthorizationTeacherScreen> {
  final _svc = AuthorizationService();
  StreamSubscription<List<AuthorizationRequest>>? _itemsSub;

  userModelv2? _logged;
  bool _isSuperadmin = false;
  List<String> _perms = [];
  late String _institutionId;
  late String _campusId;

  final List<AuthorizationRequest> _items = [];
  final List<dynamic> _cursors = [null];
  bool _loading = false;
  bool _hasNext = false;
  int _pageIndex = 0;
  final int _perPage = 20;
  bool _noGradeNotified = false;

  String? _activeGrade;

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
    _perms = u.permissions;
    _institutionId = u.institution;
    _campusId = u.campus;

    if (!_canView) {
      setState(() {});
      return;
    }

    final g = (u.grade ?? '').trim();
    if (g.isEmpty) {
      setState(() {
        _activeGrade = null;
      });
      if (!_noGradeNotified && mounted) {
        _noGradeNotified = true;
        await DialogUtils.showError(
          context: context,
          title: 'Sin grado asignado',
          message: 'El docente no tiene grado asignado.',
        );
      }
      return;
    } else {
      _activeGrade = g;
    }

    _subscribeToItems();
  }

  DocumentSnapshot<Map<String, dynamic>>? get _cursor =>
      _cursors[_pageIndex] as DocumentSnapshot<Map<String, dynamic>>?;

  Future<void> _reload() async {
    if (_activeGrade == null || _activeGrade!.isEmpty) {
      setState(() {
        _items.clear();
        _hasNext = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _items.clear();
      _hasNext = false;
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
    });
    _subscribeToItems();
  }

  void _subscribeToItems() {
    if (_activeGrade == null || _activeGrade!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _itemsSub?.cancel();
    _itemsSub = _svc
        .watchForGrade(
          institutionId: _institutionId,
          campusId: _campusId,
          grade: _activeGrade!,
          limit: _perPage,
        )
        .listen(
          (items) {
            if (!mounted) return;
            setState(() {
              _items
                ..clear()
                ..addAll(items);
              _hasNext = false;
              _loading = false;
            });
          },
          onError: (Object error) async {
            if (!mounted) return;
            await DialogUtils.showError(
              context: context,
              title: 'Error',
              message: error.toString(),
            );
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  Future<void> _nextPage() async {
    return;
  }

  Future<void> _prevPage() async {
    return;
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

  Color _statusColor(AuthorizationStatus s) {
    switch (s) {
      case AuthorizationStatus.pending:
        return Colors.orange;
      case AuthorizationStatus.approved:
        return Colors.green;
      case AuthorizationStatus.rejected:
        return Colors.redAccent;
      case AuthorizationStatus.finished:
        return Colors.blueGrey;
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
          backgroundColor: Colors.white,
          foregroundColor: Colors.redAccent,
          centerTitle: true,
        ),
        body: const SafeArea(child: Center(child: Text('Acceso denegado.'))),
        backgroundColor: Colors.white,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Autorizaciones (Docente)'),
        leading: const BackToDashboardButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
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
                  color: Colors.white,
                  border: Border.all(color: Colors.red.withValues(alpha: .15)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _activeGrade == null || _activeGrade!.isEmpty
                            ? 'Sin grado asignado'
                            : 'Grado: $_activeGrade',
                      ),
                    ),
                    Text('Total: ${_items.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _activeGrade == null || _activeGrade!.isEmpty
                        ? const Center(
                          child: Text('No hay grado asignado al docente.'),
                        )
                        : _items.isEmpty
                        ? const Center(child: Text('No hay solicitudes'))
                        : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            final sc = _statusColor(r.status);
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
                            final dateLine =
                                r.multiDay
                                    ? '${_fmtD(r.dateFrom)} → ${_fmtD(r.dateTo)}'
                                    : _fmtD(r.dateFrom);
                            final timeLine =
                                r.allDay
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
                                  color: Colors.red.withValues(alpha: .12),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.red.withValues(alpha: .06),
                                    Colors.white,
                                  ],
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.assignment_turned_in,
                                  color: Colors.redAccent,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${r.studentFullName} — ${r.grade}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    chip,
                                  ],
                                ),
                                subtitle: Text(sub),
                                onTap:
                                    () => showDialog(
                                      context: context,
                                      builder:
                                          (_) => AuthorizationDetailsDialog(
                                            request: r,
                                          ),
                                    ),
                              ),
                            );
                          },
                        ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Página ${_pageIndex + 1}'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            _pageIndex == 0 || _loading ? null : _prevPage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: !_hasNext || _loading ? null : _nextPage,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
