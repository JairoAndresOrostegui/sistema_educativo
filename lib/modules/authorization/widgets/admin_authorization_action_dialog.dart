import 'package:flutter/material.dart';

import '../../../models/authorization/authorization_request_model.dart';

class AdminActionResult {
  final AuthorizationStatus newStatus;
  final String? adminNote;
  final String? evidence;
  const AdminActionResult({
    required this.newStatus,
    this.adminNote,
    this.evidence,
  });
}

class AdminAuthorizationActionDialog extends StatefulWidget {
  final AuthorizationStatus currentStatus;
  const AdminAuthorizationActionDialog({
    super.key,
    required this.currentStatus,
  });

  @override
  State<AdminAuthorizationActionDialog> createState() =>
      _AdminAuthorizationActionDialogState();
}

class _AdminAuthorizationActionDialogState
    extends State<AdminAuthorizationActionDialog> {
  AuthorizationStatus? _sel;
  final _noteCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sel = widget.currentStatus;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _evidenceCtrl.dispose();
    super.dispose();
  }

  bool get _needsNote =>
      _sel == AuthorizationStatus.pending ||
      _sel == AuthorizationStatus.rejected;

  bool get _needsEvidence => _sel == AuthorizationStatus.finished;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text(
          'Gestionar autorización',
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AuthorizationStatus>(
              value: _sel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo estado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: AuthorizationStatus.pending,
                  child: Text('Pendiente'),
                ),
                DropdownMenuItem(
                  value: AuthorizationStatus.approved,
                  child: Text('Aprobada'),
                ),
                DropdownMenuItem(
                  value: AuthorizationStatus.rejected,
                  child: Text('Rechazada'),
                ),
                DropdownMenuItem(
                  value: AuthorizationStatus.finished,
                  child: Text('Finalizada'),
                ),
              ],
              onChanged: (v) => setState(() => _sel = v),
            ),
            const SizedBox(height: 12),
            if (_needsNote)
              TextFormField(
                controller: _noteCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nota para el padre/estudiante',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_needsEvidence) ...[
              TextFormField(
                controller: _evidenceCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Evidencia de salida',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (_sel == null) return;
            if (_needsNote && _noteCtrl.text.trim().isEmpty) return;
            if (_needsEvidence && _evidenceCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              AdminActionResult(
                newStatus: _sel!,
                adminNote: _noteCtrl.text.trim().isEmpty
                    ? null
                    : _noteCtrl.text.trim(),
                evidence: _evidenceCtrl.text.trim().isEmpty
                    ? null
                    : _evidenceCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
