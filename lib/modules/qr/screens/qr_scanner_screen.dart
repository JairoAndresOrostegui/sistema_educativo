import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

final _institutionalQr = RegExp(r'^LLQ1:[A-Za-z0-9_-]{43}$');

bool isInstitutionalQrPayload(String? value) {
  final payload = value?.trim();
  return payload != null && _institutionalQr.hasMatch(payload);
}

Future<String?> scanInstitutionalQr(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QrScannerScreen(),
    ),
  );
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  bool _resolved = false;
  bool _invalidCodeSeen = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_resolved) return;
    String? payload;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (isInstitutionalQrPayload(value)) {
        payload = value;
        break;
      }
    }
    if (payload == null) {
      if (mounted) setState(() => _invalidCodeSeen = true);
      return;
    }
    _resolved = true;
    await _controller.stop().catchError((_) {});
    if (mounted) Navigator.of(context).pop(payload);
  }

  Future<void> _cameraAction(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError =
              'No fue posible cambiar la cámara. Puedes cerrar y reintentar.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leer identificador QR'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        actions: [
          IconButton(
            tooltip: 'Encender o apagar linterna',
            onPressed: () => _cameraAction(_controller.toggleTorch),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            onPressed: () => _cameraAction(_controller.switchCamera),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _detected,
                    onDetectError: (_, _) {
                      if (mounted) {
                        setState(
                          () => _cameraError =
                              'La cámara no pudo procesar la imagen. Reintenta.',
                        );
                      }
                    },
                    errorBuilder: (context, error) => _ScannerUnavailable(
                      permissionDenied:
                          error.errorCode ==
                          MobileScannerErrorCode.permissionDenied,
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.primary, width: 4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Enfoca el código dentro del recuadro. Leerlo solo muestra '
                    'la identidad vigente; no registra asistencia ni autoriza '
                    'ninguna operación.',
                    textAlign: TextAlign.center,
                  ),
                  if (_invalidCodeSeen)
                    Text(
                      'Ese código no pertenece al sistema educativo.',
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  if (_cameraError != null)
                    Text(
                      _cameraError!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerUnavailable extends StatelessWidget {
  const _ScannerUnavailable({required this.permissionDenied});

  final bool permissionDenied;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        permissionDenied
            ? 'La cámara no tiene permiso. Habilítala en Ajustes y vuelve a '
                  'intentarlo, o usa la validación manual.'
            : 'La cámara no está disponible en este dispositivo. Usa la '
                  'validación manual.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
