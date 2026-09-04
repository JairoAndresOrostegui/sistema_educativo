import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

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
  final bool requiresRequesterEdit;
  final bool isSuperadmin;
  const AdminAuthorizationActionDialog({
    super.key,
    required this.currentStatus,
    this.requiresRequesterEdit = false,
    this.isSuperadmin = false,
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
    _sel = widget.currentStatus == AuthorizationStatus.approved
        ? AuthorizationStatus.finished
        : AuthorizationStatus.pending;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _evidenceCtrl.dispose();
    super.dispose();
  }

  bool get _isOverride =>
      widget.isSuperadmin &&
      widget.currentStatus == AuthorizationStatus.finished;

  bool get _needsNote =>
      _isOverride ||
      _sel == AuthorizationStatus.pending ||
      _sel == AuthorizationStatus.rejected;

  bool get _needsEvidence => _sel == AuthorizationStatus.finished;

  List<DropdownMenuItem<AuthorizationStatus>> get _items {
    if (_isOverride) {
      return const [
        DropdownMenuItem(
          value: AuthorizationStatus.pending,
          child: Text('Reabrir como pendiente'),
        ),
        DropdownMenuItem(
          value: AuthorizationStatus.approved,
          child: Text('Reabrir como aprobada'),
        ),
        DropdownMenuItem(
          value: AuthorizationStatus.rejected,
          child: Text('Reabrir como rechazada'),
        ),
      ];
    }
    if (widget.currentStatus == AuthorizationStatus.approved) {
      return const [
        DropdownMenuItem(
          value: AuthorizationStatus.finished,
          child: Text('Finalizada'),
        ),
      ];
    }

    if (widget.currentStatus == AuthorizationStatus.pending) {
      return const [
        DropdownMenuItem(
          value: AuthorizationStatus.pending,
          child: Text('Pendiente para correccion'),
        ),
        DropdownMenuItem(
          value: AuthorizationStatus.approved,
          child: Text('Aprobada'),
        ),
        DropdownMenuItem(
          value: AuthorizationStatus.rejected,
          child: Text('Rechazada'),
        ),
      ];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text(
          'Gestionar autorización',
          style: TextStyle(
            color: AppPalette.primary,
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
              initialValue: _sel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo estado',
                border: OutlineInputBorder(),
              ),
              items: _items,
              onChanged: (v) => setState(() => _sel = v),
            ),
            const SizedBox(height: 12),
            if (_needsNote)
              TextFormField(
                controller: _noteCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: _isOverride
                      ? 'Motivo obligatorio de reapertura'
                      : _sel == AuthorizationStatus.rejected
                      ? 'Motivo del rechazo'
                      : 'Motivo para correccion',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_needsEvidence) ...[
              TextFormField(
                controller: _evidenceCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Observacion de cierre',
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
