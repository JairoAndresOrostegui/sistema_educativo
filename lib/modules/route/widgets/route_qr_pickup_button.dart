import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../qr/screens/qr_scanner_screen.dart';
import '../../../utils/user_facing_error.dart';
import '../services/daily_route_service.dart';

/// QR prepares an identity; the operator must confirm the existing pickup action.
class RouteQrPickupButton extends StatefulWidget {
  const RouteQrPickupButton({
    super.key,
    required this.dailyRouteId,
    this.enabled = true,
    this.invoke,
    this.scan,
  });

  final String dailyRouteId;
  final bool enabled;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  invoke;
  final Future<String?> Function(BuildContext)? scan;

  @override
  State<RouteQrPickupButton> createState() => _RouteQrPickupButtonState();
}

class _RouteQrPickupButtonState extends State<RouteQrPickupButton> {
  static int _sequence = 0;
  bool _busy = false;
  bool _confirming = false;
  String? _error;

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) =>
      (widget.invoke ?? RouteOperations.call)(name, data);

  Future<void> _scanPickup() async {
    if (_busy || !widget.enabled) return;
    final dailyRouteId = widget.dailyRouteId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = await (widget.scan ?? scanInstitutionalQr)(context);
      if (payload == null || !mounted) return;
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final prepared = await _call('prepararRecogidaQr', {
        'dailyRouteId': dailyRouteId,
        'payload': payload,
        'source': 'camera',
        'clientPlatform': platform,
      });
      if (!mounted || dailyRouteId != widget.dailyRouteId) return;
      if (prepared['dailyRouteId'] != dailyRouteId ||
          prepared['studentId'] is! String ||
          (prepared['studentId'] as String).isEmpty ||
          prepared['credentialRevision'] is! num) {
        throw StateError('La identificación recibida no está completa.');
      }
      // Reuse this key after an uncertain response; never duplicate a pickup.
      final requestId =
          'qr-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
      var saving = false;
      String? saveError;
      setState(() => _confirming = true);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              scrollable: true,
              title: const Text('Confirmar recogida'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((prepared['studentName'] ?? 'Estudiante').toString()),
                  Text(
                    (prepared['routeName'] ?? 'Recorrido escolar').toString(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirma únicamente si el estudiante ya subió al transporte. '
                    'Leer su QR no registra la recogida.',
                  ),
                  if (saving) const LinearProgressIndicator(),
                  if (saveError != null)
                    Text(
                      saveError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                            saveError = null;
                          });
                          try {
                            await _call('operarRecorrido', {
                              'id': dailyRouteId,
                              'command': 'pickup',
                              'requestId': requestId,
                              'studentId': prepared['studentId'],
                              'identification': {
                                'method': 'qr',
                                'payload': payload,
                                'credentialRevision':
                                    prepared['credentialRevision'],
                                'source': 'camera',
                                'clientPlatform': platform,
                              },
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                                saveError = userFacingError(error);
                              });
                            }
                          }
                        },
                  child: Text(saveError == null ? 'Confirmar' : 'Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton.icon(
        onPressed: _busy || !widget.enabled ? null : _scanPickup,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Recogida con QR'),
      ),
      if (_busy && !_confirming) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
