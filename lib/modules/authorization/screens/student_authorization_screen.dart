// ignore_for_file: use_build_context_synchronously

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
import '../widgets/student_authorization_dialog.dart';
import '../widgets/teacher_authorization_dialog.dart';

class AuthorizationStudentScreen extends StatefulWidget {
  const AuthorizationStudentScreen({super.key});

  @override
  State<AuthorizationStudentScreen> createState() =>
      _AuthorizationStudentScreenState();
}

class _AuthorizationStudentScreenState
    extends State<AuthorizationStudentScreen> {
  final _svc = AuthorizationService();

  userModelv2? _logged;
  bool _isSuperadmin = false;
  List<String> _perms = [];
  late String _institutionId;
  late String _campusId;

  final List<AuthorizationRequest> _items = [];
  final List<dynamic> _cursors = [null];
  bool _loading = false;
  bool _busy = false;
  bool _hasNext = false;
  int _pageIndex = 0;
  final int _perPage = 20;

  List<_ChildLite> _children = [];
  String?
  _activeStudentId; // para Estudiante = su propio id; para Familiar = activeStudentId

  bool get _canView {
    if (_logged == null) return false;
    return _isSuperadmin || _perms.contains('autorizaciones.ver');
  }

  bool get _canCreate {
    if (_logged == null) return false;
    return _isSuperadmin ||
        (_logged!.role == 'Familiar' &&
            _perms.contains('autorizaciones.crear'));
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
      setState(() {}); // para que build pinte el “acceso denegado”
      return;
    }

    if (u.role == 'Estudiante') {
      _activeStudentId = u.id;
      await _reload();
      return;
    }

    if (u.role == 'Familiar') {
      final kids = await _svc.getChildrenForFamily(
        institutionId: _institutionId,
        campusId: _campusId,
        studentIds: u.studentIds ?? const <String>[],
      );
      _children =
          kids
              .map(
                (e) =>
                    _ChildLite(id: e.id, fullName: e.fullName, grade: e.grade),
              )
              .toList();

      if (_children.isNotEmpty) {
        final currentActive = (u.activeStudentId ?? '').trim();
        final exists = _children.any((c) => c.id == currentActive);
        _activeStudentId = exists ? currentActive : _children.first.id;

        if (!exists) {
          if (!mounted) return;
          final prov = context.read<UserProviderV2>();
          final userNow = prov.user;
          if (userNow != null) {
            prov.setUser(userNow.copyWith(activeStudentId: _activeStudentId));
          }
        }
      }

      await _reload();
      return;
    }

    setState(() {}); // otros roles: solo para completar ciclo
  }

  DocumentSnapshot<Map<String, dynamic>>? get _cursor =>
      _cursors[_pageIndex] as DocumentSnapshot<Map<String, dynamic>>?;

  Future<void> _reload() async {
    if (_activeStudentId == null) {
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
    await _loadPage();
  }

  Future<void> _loadPage() async {
    if (_activeStudentId == null) {
      setState(() => _loading = false);
      return;
    }
    final page = await _svc.listForStudent(
      institutionId: _institutionId,
      campusId: _campusId,
      studentId: _activeStudentId!,
      limit: _perPage,
      startAfter: _cursor,
    );
    setState(() {
      _items.addAll(page.items);
      _hasNext = page.hasNext;
      if (page.lastDoc != null) {
        if (_cursors.length == _pageIndex + 1) {
          _cursors.add(page.lastDoc);
        } else {
          _cursors[_pageIndex + 1] = page.lastDoc;
        }
      }
      _loading = false;
    });
  }

  Future<void> _nextPage() async {
    if (!_hasNext || _loading) return;
    setState(() {
      _pageIndex += 1;
      _loading = true;
    });
    await _loadPage();
  }

  Future<void> _prevPage() async {
    if (_pageIndex == 0 || _loading) return;
    setState(() {
      _pageIndex -= 1;
      _loading = true;
    });
    await _loadPage();
  }

  void _onStudentChanged(String newId) async {
    if (_activeStudentId == newId) return;
    setState(() {
      _activeStudentId = newId;
      _loading = true;
    });
    final prov = context.read<UserProviderV2>();
    final u = prov.user;
    if (u != null) prov.setUser(u.copyWith(activeStudentId: newId));
    await _reload();
  }

  String _fmtD(DateTime? d) =>
      d == null ? '-' : DateFormat('yyyy-MM-dd').format(d);
  String _fmtT(DateTime? d) => d == null ? '-' : DateFormat('HH:mm').format(d);
  String _firstWords(String text, int n) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length <= n) return text.trim();
    return '${parts.take(n).join(' ')}...';
  }

  // === helpers de estado (solo visual) ===
  String _statusLabelEs(AuthorizationStatus s) {
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
        return Colors.grey;
    }
  }

  Future<void> _onCreatePressed() async {
    final ctx = context;
    final requester = context.read<UserProviderV2>().user;
    if (requester == null) return;
    if (_children.isEmpty) {
      await DialogUtils.showError(
        context: ctx,
        title: 'Sin estudiantes',
        message: 'No se encontraron estudiantes vinculados.',
      );
      return;
    }
    final res = await showDialog<CreateAuthorizationResult>(
      context: ctx,
      builder:
          (_) => AuthorizationCreateDialog(
            children:
                _children
                    .map(
                      (e) => StudentChoice(
                        id: e.id,
                        fullName: e.fullName,
                        grade: e.grade,
                      ),
                    )
                    .toList(),
            initialStudentId: _activeStudentId,
          ),
    );
    if (res == null) return;

    if (_busy) return;
    if (!mounted) return;
    setState(() => _busy = true);

    try {
      final kid = _children.firstWhere((c) => c.id == res.studentId);
      final req = AuthorizationRequest(
        id: '',
        institutionId: _institutionId,
        campusId: _campusId,
        studentId: kid.id,
        studentFullName: kid.fullName,
        grade: kid.grade,
        requesterId: '',
        requesterFullName: '',
        allDay: res.allDay,
        multiDay: res.multiDay,
        dateFrom: res.dateFrom,
        dateTo: res.dateTo,
        startTime: res.startTime,
        endTime: res.endTime,
        reason: res.reason,
        status: AuthorizationStatus.pending,
        adminNote: null,
        evidence: null,
        resubmissionOfRequestId: null,
        createdAt: null,
        updatedAt: null,
      );
      await _svc.createRequest(request: req, requester: requester);
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: ctx,
        title: 'Exito',
        message: 'Solicitud enviada.',
      );
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: ctx,
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          title: const Text('Authorizations'),
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
        title: const Text('Autorizaciones'),
        leading: const BackToDashboardButton(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      floatingActionButton:
          _canCreate
              ? FloatingActionButton.extended(
                onPressed: _busy ? null : _onCreatePressed,
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              )
              : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (session.role == 'Familiar' && _children.isNotEmpty)
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: .15),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.red.withValues(alpha: .06),
                            Colors.white,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activeStudentId,
                          isExpanded: true,
                          hint: const Text('Estudiante'),
                          items:
                              _children
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.id,
                                      child: Text('${e.fullName} • ${e.grade}'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) _onStudentChanged(v);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
                  children: [Expanded(child: Text('Total: ${_items.length}'))],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child:
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                        ? const Center(child: Text('No hay solicitudes'))
                        : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final r = _items[i];

                            // estado (visual en español)
                            final statusText = _statusLabelEs(r.status);
                            final statusColor = _statusColor(r.status);

                            final chip = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: .25),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
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

                            return Card(
                              elevation: 0,
                              color: Colors.transparent,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
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

class _ChildLite {
  final String id;
  final String fullName;
  final String grade;
  const _ChildLite({
    required this.id,
    required this.fullName,
    required this.grade,
  });
}
