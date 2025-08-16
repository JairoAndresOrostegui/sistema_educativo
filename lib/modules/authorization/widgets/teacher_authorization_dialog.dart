import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/authorization/authorization_request_model.dart';

class AuthorizationDetailsDialog extends StatelessWidget {
  final AuthorizationRequest request;
  const AuthorizationDetailsDialog({super.key, required this.request});

  String _fmtD(DateTime? d) => d == null ? '-' : DateFormat('yyyy-MM-dd').format(d);
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

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request.status);
    final dateLine =
        request.multiDay ? '${_fmtD(request.dateFrom)} → ${_fmtD(request.dateTo)}' : _fmtD(request.dateFrom);
    final timeLine = request.allDay
        ? 'Todo el día'
        : request.endTime != null
            ? '${_fmtT(request.startTime)} - ${_fmtT(request.endTime)}'
            : _fmtT(request.startTime);

    return AlertDialog(
      title: Center(
        child: Text(
          'Detalle de autorización',
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
        ),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sc.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sc.withOpacity(.25)),
              ),
              child: Text(
                _statusLabel(request.status),
                style: TextStyle(color: sc, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Estudiante', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(request.studentFullName)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('Grado', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(request.grade)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(dateLine)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(child: Text('Hora', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text(timeLine)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Motivo', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text((request.reason ?? '').toString().trim().isEmpty ? '-' : request.reason!.trim()),
            ),
            if ((request.adminNote ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Nota del administrador', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(request.adminNote!.trim()),
              ),
            ],
            if ((request.evidence ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Evidencia', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(request.evidence!.trim()),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
