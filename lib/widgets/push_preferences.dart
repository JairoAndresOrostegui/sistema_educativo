import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/firebase_utils.dart';
import '../utils/push_notifications.dart';

class PushPreferences extends StatefulWidget {
  const PushPreferences({super.key});
  @override
  State<PushPreferences> createState() => _PushPreferencesState();
}

class _PushPreferencesState extends State<PushPreferences> {
  bool _busy = false;
  String? _message;
  Future<void> _change(bool enabled) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (enabled) {
        final ok = await enablePushFromHome();
        if (!ok) {
          _message = kIsWeb
              ? 'En el navegador abre los permisos de este sitio → Notificaciones → Permitir. Después pulsa Activar nuevamente.'
              : 'Permite las notificaciones en Ajustes de la aplicación y vuelve a pulsar Activar.';
        }
      } else {
        await PushDeviceSession.action('disable');
      }
    } catch (_) {
      _message =
          'No se pudo guardar. Reintenta; si usaste otro equipo del mismo tipo, vuelve a iniciar sesión aquí.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PushDeviceSession.enabled,
            builder: (context, enabled, _) => SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificaciones en este equipo'),
              subtitle: Text(
                enabled
                    ? 'Activadas. No cambia tu otro dispositivo.'
                    : 'Desactivadas o sin permiso. Pulsa para activar.',
              ),
              value: enabled,
              onChanged: _busy ? null : _change,
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: PushDeviceSession.error,
            builder: (_, error, _) =>
                error == null ? const SizedBox.shrink() : Text(error),
          ),
          if (_message != null) Text(_message!),
          if (!kIsWeb)
            TextButton.icon(
              onPressed: openAppSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir ajustes del teléfono'),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
