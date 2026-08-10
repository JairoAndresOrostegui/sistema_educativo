import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../services/website_service.dart';

class WebsiteSubmissionsScreen extends StatefulWidget {
  const WebsiteSubmissionsScreen({super.key});

  @override
  State<WebsiteSubmissionsScreen> createState() =>
      _WebsiteSubmissionsScreenState();
}

class _WebsiteSubmissionsScreenState extends State<WebsiteSubmissionsScreen> {
  final WebsiteService _service = WebsiteService();
  final TextEditingController _search = TextEditingController();
  String _filter = 'all';
  String? _selectedId;

  bool _canManage(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    final permissions =
        user?.permissions.map((item) => item.trim().toLowerCase()).toSet() ??
        const <String>{};
    return (user?.isSuperadmin ?? false) ||
        permissions.contains('sitio_web.editar');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_canManage(context)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mensajes del sitio')),
        body: const Center(child: Text('No tienes acceso a este panel.')),
      );
    }
    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al constructor',
          onPressed: () => context.go('/website_admin'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Mensajes del sitio web'),
        actions: [
          IconButton(
            tooltip: 'Abrir constructor del sitio',
            onPressed: () => context.go('/website_admin'),
            icon: const Icon(Icons.web_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<WebsiteSubmission>>(
        stream: _service.watchSubmissions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No fue posible cargar los mensajes.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final query = _search.text.trim().toLowerCase();
          final filtered = all.where((item) {
            final matchesFilter =
                _filter == 'all' ||
                (_filter == 'new' && item.status == 'new') ||
                (_filter == 'read' && item.status != 'new');
            final haystack =
                '${item.name} ${item.email} ${item.phone} ${item.message} ${item.pageId}'
                    .toLowerCase();
            return matchesFilter && (query.isEmpty || haystack.contains(query));
          }).toList();
          final unread = all.where((item) => item.status == 'new').length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final selected = _selected(all, fallbackToFirst: !narrow);
              final showDetail = narrow && _selectedId != null;
              return Padding(
                padding: EdgeInsets.all(narrow ? 12 : 20),
                child: Column(
                  children: [
                    if (!showDetail) _summary(all.length, unread, narrow),
                    if (!showDetail) SizedBox(height: narrow ? 12 : 16),
                    Expanded(
                      child: narrow
                          ? (showDetail
                                ? _detail(selected, showBack: true)
                                : _inbox(filtered))
                          : Row(
                              children: [
                                SizedBox(width: 430, child: _inbox(filtered)),
                                const SizedBox(width: 16),
                                Expanded(child: _detail(selected)),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  WebsiteSubmission? _selected(
    List<WebsiteSubmission> items, {
    required bool fallbackToFirst,
  }) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (item.id == _selectedId) return item;
    }
    return fallbackToFirst ? items.first : null;
  }

  Widget _summary(int total, int unread, bool compact) => Row(
    children: [
      _metric('Total', total, Icons.inbox_outlined, AppPalette.info, compact),
      SizedBox(width: compact ? 6 : 12),
      _metric(
        'Sin leer',
        unread,
        Icons.mark_email_unread_outlined,
        AppPalette.error,
        compact,
      ),
      SizedBox(width: compact ? 6 : 12),
      _metric(
        'Leídos',
        total - unread,
        Icons.drafts_outlined,
        AppPalette.success,
        compact,
      ),
    ],
  );

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
    bool compact,
  ) => Expanded(
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 18,
          vertical: compact ? 10 : 14,
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  Text(
                    '$value',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _inbox(List<WebsiteSubmission> submissions) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nombre, correo o mensaje',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'all', label: Text('Todos')),
              ButtonSegment(value: 'new', label: Text('Sin leer')),
              ButtonSegment(value: 'read', label: Text('Leídos')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
        ),
        const Divider(height: 18),
        Expanded(
          child: submissions.isEmpty
              ? const Center(child: Text('No hay mensajes para mostrar.'))
              : ListView.separated(
                  itemCount: submissions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = submissions[index];
                    final selected =
                        (_selectedId ?? submissions.first.id) == item.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: AppPalette.error.withValues(
                        alpha: 0.08,
                      ),
                      leading: Icon(
                        item.status == 'new'
                            ? Icons.mark_email_unread_outlined
                            : Icons.drafts_outlined,
                        color: item.status == 'new' ? AppPalette.error : null,
                      ),
                      title: Text(
                        item.name.isEmpty ? 'Sin nombre' : item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: item.status == 'new'
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() => _selectedId = item.id);
                        if (item.status == 'new') {
                          _service.markSubmissionRead(item.id);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Widget _detail(WebsiteSubmission? item, {bool showBack = false}) => Card(
    margin: EdgeInsets.zero,
    child: item == null
        ? const Center(
            child: Text('Selecciona un mensaje para ver sus detalles.'),
          )
        : Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBack)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedId = null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a mensajes'),
                  ),
                if (showBack) const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: showBack ? double.infinity : 300,
                      child: Text(
                        item.name.isEmpty ? 'Sin nombre' : item.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => item.status == 'new'
                          ? _service.markSubmissionRead(item.id)
                          : _service.markSubmissionUnread(item.id),
                      icon: Icon(
                        item.status == 'new'
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                      ),
                      label: Text(
                        item.status == 'new'
                            ? 'Marcar leído'
                            : 'Marcar sin leer',
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Eliminar mensaje',
                      color: AppPalette.error,
                      onPressed: () => _delete(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _data(Icons.email_outlined, item.email),
                if (item.phone.isNotEmpty)
                  _data(Icons.phone_outlined, item.phone),
                _data(Icons.description_outlined, 'Página: ${item.pageId}'),
                if (item.createdAt != null)
                  _data(
                    Icons.schedule,
                    DateFormat(
                      'dd/MM/yyyy, h:mm a',
                    ).format(item.createdAt!.toLocal()),
                  ),
                const Divider(height: 36),
                const Text(
                  'Mensaje',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      item.message,
                      style: const TextStyle(fontSize: 17, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );

  Widget _data(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppPalette.onSurface.withValues(alpha: .54),
        ),
        const SizedBox(width: 10),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  Future<void> _delete(WebsiteSubmission item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('Esta acción es permanente. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteSubmission(item.id);
    if (mounted) setState(() => _selectedId = null);
  }
}
