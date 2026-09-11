import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/user_facing_error.dart';
import 'qr_scanner_screen.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, this.manage = false, this.invoke, this.scan});
  final bool manage;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  invoke;
  final Future<String?> Function(BuildContext)? scan;
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  List<Map<String, dynamic>> _entities = [];
  Map<String, dynamic>? _selected;
  String? _payload, _error;
  String? _credentialStatus;
  int? _credentialRevision;
  String _search = '';
  bool _busy = true;
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async => widget.invoke != null
      ? await widget.invoke!(name, data)
      : Map<String, dynamic>.from(
          (await FirebaseFunctions.instance.httpsCallable(name).call(data)).data
              as Map,
        );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = context.read<UserProviderV2>().user!;
      final own = {
        'targetType': 'user',
        'targetId': user.id,
        'name': '${user.firstName} ${user.lastName}',
        'role': user.role,
        'institutionId': user.institution,
        'campusId': user.campus,
      };
      var entities = <Map<String, dynamic>>[own];
      if (widget.manage) {
        entities = ((await _call('listarEntidadesQr', {}))['entities'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (user.role == 'Familiar') {
        final children =
            (await _call('obtenerHijosVinculados', {}))['children'] as List;
        entities.addAll(
          children.map(
            (child) => {
              'targetType': 'user',
              'targetId': child['id'],
              'name': '${child['firstName']} ${child['lastName']}',
              'role': 'Estudiante',
              'groupName': child['groupName'],
            },
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _entities = entities;
        _busy = false;
      });
      if (!widget.manage) await _select(own);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _select(Map<String, dynamic> entity) async {
    setState(() {
      _selected = entity;
      _payload = null;
      _credentialStatus = null;
      _credentialRevision = null;
      _busy = true;
      _error = null;
    });
    try {
      final user = context.read<UserProviderV2>().user!;
      if (!widget.manage &&
          user.role == 'Familiar' &&
          entity['targetId'] != user.id) {
        await _call('seleccionarHijoActivo', {'studentId': entity['targetId']});
        if (!mounted) return;
        context.read<UserProviderV2>().setActiveStudentId(
          entity['targetId'] as String,
        );
      }
      final result = await _call('obtenerCredencialQr', {
        'targetType': entity['targetType'],
        'targetId': entity['targetId'],
      });
      if (mounted) {
        setState(() {
          _payload = result['payload'] is String
              ? result['payload'] as String
              : null;
          _credentialStatus = (result['status'] ?? 'active').toString();
          _credentialRevision = (result['revision'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _text(String title) async {
    var text = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: TextField(
          onChanged: (value) => text = value,
          maxLength: title == 'Identificador de evento' ? 120 : 100,
          decoration: const InputDecoration(labelText: 'Texto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _event() async {
    final title = await _text('Identificador de evento');
    if (title == null || title.isEmpty || !mounted) return;
    final user = context.read<UserProviderV2>().user!;
    final scope =
        _selected ??
        {'institutionId': user.institution, 'campusId': user.campus};
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call('crearIdentificadorEventoQr', {
        'title': title,
        'institutionId': scope['institutionId'],
        'campusId': scope['campusId'],
      });
      await _load();
      if (mounted) await _select({...result, 'name': title, 'role': 'Evento'});
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingError(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _manage(String action) async {
    if (_selected == null || _credentialRevision == null) {
      setState(() => _error = 'Recarga la credencial antes de modificarla.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'revoke' ? 'Revocar QR' : 'Reemplazar QR'),
        content: const Text(
          'El código anterior dejará de funcionar. La acción se auditará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call('administrarCredencialQr', {
        'targetType': _selected!['targetType'],
        'targetId': _selected!['targetId'],
        'action': action,
        'confirmation': '$action:${_selected!['targetId']}',
        'expectedRevision': _credentialRevision,
      });
      if (mounted) {
        setState(() {
          _payload = null;
          _credentialStatus = (result['status'] ?? '').toString();
          _credentialRevision = (result['revision'] as num?)?.toInt();
        });
      }
      if (action == 'rotate') await _select(_selected!);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final payload = await _text('Validar identificador QR');
    if (payload == null || payload.isEmpty || !mounted) return;
    await _resolvePayload(payload, source: 'manual');
  }

  Future<void> _scan() async {
    final payload = await (widget.scan ?? scanInstitutionalQr)(context);
    if (payload == null || !mounted) return;
    await _resolvePayload(payload, source: 'camera');
  }

  Future<void> _resolvePayload(String payload, {required String source}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _call('resolverCredencialQr', {
        'payload': payload,
        'source': source,
        'clientPlatform': kIsWeb
            ? 'web'
            : defaultTargetPlatform.name.toLowerCase(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text((result['name'] ?? 'Identificador').toString()),
          content: Text(
            'Tipo: ${result['targetType'] == 'user' ? 'Usuario' : 'Evento'}\n'
            '${(result['children'] is List ? result['children'] as List : const <dynamic>[]).whereType<Map>().map((c) => '${c['name'] ?? ''} · ${c['groupName'] ?? ''}').join('\n')}\n'
            'Identificación válida. No registra asistencia ni autoriza entregas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<UserProviderV2>().user;
    final canEdit =
        widget.manage &&
        (user?.isSuperadmin == true ||
            (user?.permissions.contains('codigoqr.editar') ?? false));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.manage ? 'Identificadores QR' : 'Mi identificación QR',
        ),
        centerTitle: true,
        leading: const BackToDashboardButton(),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.primary,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Un QR identifica; no es una firma digital ni acredita quién lo presenta. No lo compartas públicamente.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
            if (widget.manage)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar usuario o evento',
                ),
                onChanged: (value) =>
                    setState(() => _search = value.toLowerCase()),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _resolve,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Validar manualmente'),
                ),
                if (widget.manage)
                  FilledButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Leer con cámara'),
                  ),
                if (widget.manage)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _event,
                    icon: const Icon(Icons.event),
                    label: const Text('Identificador de evento'),
                  ),
              ],
            ),
            if (widget.manage)
              const Text(
                'El evento se crea en la sede de la entidad seleccionada; sin selección, en tu sede.',
              ),
            if (widget.manage && _payload != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _selected = null;
                        _payload = null;
                        _credentialStatus = null;
                        _credentialRevision = null;
                      }),
                child: const Text('Elegir otra entidad'),
              ),
            if (widget.manage && _payload == null && _entities.length > 20)
              const Text(
                'Se muestran hasta 20 coincidencias. Usa el buscador para localizar la entidad.',
              ),
            for (final entity
                in _entities
                    .where(
                      (e) =>
                          '${e['name']} ${e['role']} ${e['campusId']}'
                              .toLowerCase()
                              .contains(_search) &&
                          (!widget.manage || _payload == null),
                    )
                    .take(widget.manage ? 20 : _entities.length))
              ListTile(
                title: Text((entity['name'] ?? 'Sin nombre').toString()),
                subtitle: Text(
                  '${entity['role']} · ${entity['groupName'] ?? entity['campusId'] ?? ''}',
                ),
                selected:
                    _selected?['targetId'] == entity['targetId'] &&
                    _selected?['targetType'] == entity['targetType'],
                trailing: const Icon(Icons.qr_code),
                onTap: _busy ? null : () => _select(entity),
              ),
            if (_selected != null) ...[
              const Divider(),
              Text(
                (_selected!['name'] ?? 'Sin nombre').toString(),
                textAlign: TextAlign.center,
              ),
              if (_credentialStatus == 'revoked')
                Text(
                  'Credencial revocada. Puedes reemplazarla para emitir una nueva.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              if (_payload != null) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: QrImageView(
                      data: _payload!,
                      backgroundColor: scheme.surface,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: scheme.onSurface,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _payload!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Identificador copiado.')),
                    );
                  },
                  child: const Text('Copiar identificador'),
                ),
              ],
              if (canEdit)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy || _credentialStatus != 'active'
                          ? null
                          : () => _manage('revoke'),
                      child: const Text('Revocar'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _manage('rotate'),
                      child: const Text('Reemplazar'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
