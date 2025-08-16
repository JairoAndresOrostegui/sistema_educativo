import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/authorization/authorization_request_model.dart';
import '../../../models/user/userModelV2.dart';
import '../../../providers/user_provider_V2.dart';
import '../services/authorization_service.dart';
import '../widgets/admin_authorization_action_dialog.dart';
import '../widgets/teacher_authorization_dialog.dart';

class AuthorizationAdminScreen extends StatefulWidget {
  const AuthorizationAdminScreen({super.key});

  @override
  State<AuthorizationAdminScreen> createState() =>
      _AuthorizationAdminScreenState();
}

class _AuthorizationAdminScreenState extends State<AuthorizationAdminScreen> {
  final _svc = AuthorizationService();

  UserModelV2? _logged;
  bool _isSuperadmin = false;
  List<String> _perms = [];
  late String _institutionId;
  late String _campusId;

  bool _loading = true;
  List<AuthorizationRequest> _items = [];

  bool get _canView {
    if (_logged == null) return false;
    return _isSuperadmin || _perms.contains('autorizaciones.ver');
  }

  bool get _canEdit {
    if (_logged == null) return false;
    return _isSuperadmin || _perms.contains('autorizaciones.editar');
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
      setState(() => _loading = false);
      return;
    }

    await _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final page = await _svc.listForAdmin(
      institutionId: _institutionId,
      campusId: _campusId,
    );
    setState(() {
      _items = page.items;
      _loading = false;
    });
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
    return parts.take(n).join(' ') + '...';
  }

  Future<void> _manage(AuthorizationRequest r) async {
    if (!_canEdit) return;
    final res = await showDialog<AdminActionResult>(
      context: context,
      builder: (_) => AdminAuthorizationActionDialog(currentStatus: r.status),
    );
    if (res == null) return;
    await _svc.updateStatus(
      id: r.id,
      newStatus: res.newStatus,
      adminNote: res.adminNote,
      evidence: res.evidence,
      admin: _logged!,
    );
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Solicitud actualizada.')));
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      _items.isEmpty
                          ? const Center(child: Text('No hay solicitudes'))
                          : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final r = _items[i];
                              final c = _statusColor(r.status);
                              final chip = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.withOpacity(.25)),
                                ),
                                child: Text(
                                  _statusLabel(r.status),
                                  style: TextStyle(
                                    color: c,
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
                                'Estudiante: ${r.studentFullName} — ${r.grade}',
                                'Fecha: $dateLine',
                                'Hora: $timeLine',
                                if ((r.reason ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
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
                                    color: Colors.red.withOpacity(.12),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.red.withOpacity(.06),
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
                                          r.requesterFullName?.isNotEmpty ==
                                                  true
                                              ? 'Solicitante: ${r.requesterFullName}'
                                              : 'Solicitud',
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
                                  trailing:
                                      _canEdit &&
                                              r.status !=
                                                  AuthorizationStatus.finished
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.manage_accounts,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _manage(r),
                                          )
                                          : null,
                                ),
                              );
                            },
                          ),
                ),
      ),
    );
  }
}
