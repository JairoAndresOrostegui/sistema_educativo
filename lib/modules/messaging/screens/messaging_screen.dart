import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../services/messaging_service.dart';

enum _ChannelView { groups, private }

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final _service = MessagingService();
  final _messageController = TextEditingController();
  userModelv2? _user;
  List<MessagingChildContext> _children = const [];
  String? _activeStudentId;
  String? _selectedChannelId;
  MessageContact? _draftContact;
  _ChannelView _view = _ChannelView.groups;
  bool _loading = true;
  bool _sending = false;

  bool get _isFamily => _user?.role == 'Familiar';
  bool get _isAdmin =>
      _user?.isSuperadmin == true || _user?.role == 'Administrador';
  bool get _allowed {
    final permissions =
        _user?.permissions.map((item) => item.toLowerCase()).toSet() ?? {};
    return _user?.isSuperadmin == true ||
        permissions.contains('mensajeria.ver');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<UserProviderV2>();
    _user = provider.user;
    if (_user == null || !_allowed) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (_isFamily) {
      _children = await _service.getFamilyChildren(_user!);
      if (_children.isNotEmpty) {
        final preferred = (_user!.activeStudentId ?? '').trim();
        _activeStudentId = _children.any((child) => child.id == preferred)
            ? preferred
            : _children.first.id;
        provider.setActiveStudentId(_activeStudentId!);
      }
    } else if (_user!.role == 'Estudiante') {
      _activeStudentId = _user!.id;
    }
    if (_isAdmin) {
      try {
        await _service.syncAcademicChannels(
          institutionId: _user!.institution,
          campusId: _user!.campus,
        );
      } catch (_) {
        // La sincronización automática de backend seguirá disponible.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectChannel(MessageThreadSummary channel) async {
    setState(() {
      _selectedChannelId = channel.id;
      _draftContact = null;
    });
    try {
      await _service.markRead(channel.id);
    } catch (_) {
      // La lectura no impide consultar una conversación ya autorizada.
    }
  }

  Future<void> _newPrivateMessage() async {
    try {
      final contacts = await _service.getAvailableContacts(
        studentContextId: _activeStudentId,
      );
      if (!mounted) return;
      final contact = await showDialog<MessageContact>(
        context: context,
        builder: (_) => _ContactPicker(contacts: contacts),
      );
      if (contact == null) return;
      setState(() {
        _view = _ChannelView.private;
        _selectedChannelId = null;
        _draftContact = contact;
      });
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No fue posible cargar contactos',
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _send(MessageThreadSummary? channel) async {
    if (_sending || _user == null) return;
    final body = _messageController.text.trim();
    if (body.isEmpty || channel == null && _draftContact == null) return;
    setState(() => _sending = true);
    try {
      final channelId = await _service.sendMessage(
        body: body,
        channelId: channel?.id,
        recipientId: _draftContact?.id,
        studentContextId: _draftContact?.studentContextId ?? _activeStudentId,
      );
      _messageController.clear();
      if (!mounted) return;
      setState(() {
        _selectedChannelId = channelId;
        _draftContact = null;
      });
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se envió el mensaje',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleMute(MessageThreadSummary channel) async {
    try {
      await _service.setMuted(channel.id, !channel.mutedByAdmin);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No fue posible cambiar el canal',
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _createServiceChannel(
    List<MessageThreadSummary> channels,
  ) async {
    final result = await showDialog<_ServiceChannelDraft>(
      context: context,
      builder: (_) => _ServiceChannelDialog(
        groups: channels.where((channel) => channel.isAcademicGroup).toList(),
      ),
    );
    if (result == null) return;
    try {
      final id = await _service.createServiceChannel(
        title: result.title,
        category: result.category,
        audienceType: result.audienceType,
        groupIds: result.groupIds,
      );
      if (mounted) setState(() => _selectedChannelId = id);
    } catch (error) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se creó el canal',
          message: error.toString(),
        );
      }
    }
  }

  void _changeChild(String id) {
    context.read<UserProviderV2>().setActiveStudentId(id);
    setState(() {
      _activeStudentId = id;
      _selectedChannelId = null;
      _draftContact = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }
    if (_user == null || !_allowed) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackToDashboardButton(),
          title: const Text('Mensajería'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Acceso denegado.')),
      );
    }
    return StreamBuilder<List<MessageThreadSummary>>(
      stream: _service.watchChannels(_user!),
      builder: (context, snapshot) {
        final channels = snapshot.data ?? const <MessageThreadSummary>[];
        final selected = channels.cast<MessageThreadSummary?>().firstWhere(
          (channel) => channel?.id == _selectedChannelId,
          orElse: () => null,
        );
        final visible = channels
            .where(
              (channel) => _view == _ChannelView.private
                  ? channel.isPrivate
                  : !channel.isPrivate,
            )
            .toList();
        final groupUnread = channels
            .where((channel) => !channel.isPrivate)
            .fold<int>(
              0,
              (total, channel) => total + channel.unreadCountFor(_user!.id),
            );
        final privateUnread = channels
            .where((channel) => channel.isPrivate)
            .fold<int>(
              0,
              (total, channel) => total + channel.unreadCountFor(_user!.id),
            );
        return Scaffold(
          appBar: AppBar(
            leading: const BackToDashboardButton(),
            title: const Text('Mensajería'),
            centerTitle: true,
            actions: [
              if (_isAdmin)
                IconButton(
                  tooltip: 'Crear canal de servicio',
                  onPressed: () => _createServiceChannel(channels),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              IconButton(
                tooltip: 'Mensaje particular',
                onPressed: _newPrivateMessage,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isFamily && _children.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _activeStudentId,
                      decoration: const InputDecoration(
                        labelText: 'Ver mensajes de',
                        prefixIcon: Icon(Icons.family_restroom_outlined),
                      ),
                      items: _children
                          .map(
                            (child) => DropdownMenuItem(
                              value: child.id,
                              child: Text(
                                '${child.fullName} • ${child.groupName}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id != null) _changeChild(id);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  SegmentedButton<_ChannelView>(
                    segments: [
                      ButtonSegment(
                        value: _ChannelView.groups,
                        icon: const Icon(Icons.groups_outlined),
                        label: Text(
                          'Grupos y servicios${groupUnread > 0 ? ' ($groupUnread)' : ''}',
                        ),
                      ),
                      ButtonSegment(
                        value: _ChannelView.private,
                        icon: const Icon(Icons.person_outline),
                        label: Text(
                          'Particulares${privateUnread > 0 ? ' ($privateUnread)' : ''}',
                        ),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (value) => setState(() {
                      _view = value.first;
                      _selectedChannelId = null;
                      _draftContact = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final list = _ChannelList(
                          channels: visible,
                          userId: _user!.id,
                          selectedId: selected?.id,
                          onSelected: _selectChannel,
                        );
                        final chat = _ChatPanel(
                          channel: selected,
                          draftContact: _draftContact,
                          user: _user!,
                          controller: _messageController,
                          sending: _sending,
                          messages: selected == null
                              ? null
                              : _service.watchMessages(selected.id),
                          onSend: () => _send(selected),
                          onToggleMute:
                              _isAdmin &&
                                  selected != null &&
                                  !selected.isPrivate
                              ? () => _toggleMute(selected)
                              : null,
                        );
                        if (constraints.maxWidth >= 850) {
                          return Row(
                            children: [
                              SizedBox(width: 330, child: list),
                              const SizedBox(width: 12),
                              Expanded(child: chat),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(height: 210, child: list),
                            const SizedBox(height: 12),
                            Expanded(child: chat),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

IconData _channelIcon(String key) => switch (key) {
  'school' => Icons.school_outlined,
  'cafeteria' => Icons.lunch_dining_outlined,
  'restaurant' => Icons.restaurant_outlined,
  'route' => Icons.directions_bus_outlined,
  'community' => Icons.campaign_outlined,
  _ => Icons.person_outline,
};

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.userId,
    required this.selectedId,
    required this.onSelected,
  });
  final List<MessageThreadSummary> channels;
  final String userId;
  final String? selectedId;
  final ValueChanged<MessageThreadSummary> onSelected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: channels.isEmpty
          ? const Center(child: Text('No hay conversaciones en esta sección.'))
          : ListView.builder(
              padding: const EdgeInsets.all(6),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final count = channel.unreadCountFor(userId);
                final selected = channel.id == selectedId;
                return Card(
                  color: selected ? scheme.primaryContainer : scheme.surface,
                  elevation: 0,
                  child: ListTile(
                    onTap: () => onSelected(channel),
                    leading: CircleAvatar(
                      backgroundColor: scheme.secondaryContainer,
                      child: Icon(
                        _channelIcon(channel.iconKey),
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      channel.displayTitleFor(userId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        channel.subtitleFor(userId),
                        if ((channel.lastMessage ?? '').isNotEmpty)
                          channel.lastMessage!,
                      ].where((value) => value.isNotEmpty).join('\n'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: count == 0 ? null : Badge(label: Text('$count')),
                  ),
                );
              },
            ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.channel,
    required this.draftContact,
    required this.user,
    required this.controller,
    required this.sending,
    required this.messages,
    required this.onSend,
    required this.onToggleMute,
  });
  final MessageThreadSummary? channel;
  final MessageContact? draftContact;
  final userModelv2 user;
  final TextEditingController controller;
  final bool sending;
  final Stream<List<MessageItem>>? messages;
  final VoidCallback onSend;
  final VoidCallback? onToggleMute;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = channel?.displayTitleFor(user.id) ?? draftContact?.fullName;
    final isAdmin = user.isSuperadmin || user.role == 'Administrador';
    final blocked = channel?.mutedByAdmin == true && !isAdmin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _channelIcon(channel?.iconKey ?? 'private'),
              color: scheme.primary,
            ),
            title: Text(title ?? 'Selecciona una conversación'),
            subtitle: channel == null
                ? null
                : Text(
                    [
                      channel!.subtitleFor(user.id),
                      if (channel!.mutedByAdmin)
                        'Solo administración puede escribir',
                    ].where((value) => value.isNotEmpty).join(' • '),
                  ),
            trailing: onToggleMute == null
                ? null
                : IconButton(
                    tooltip: channel!.mutedByAdmin
                        ? 'Permitir mensajes'
                        : 'Silenciar grupo',
                    onPressed: onToggleMute,
                    icon: Icon(
                      channel!.mutedByAdmin
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                    ),
                  ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: messages == null
                ? const Center(
                    child: Text(
                      'Selecciona un canal o inicia un mensaje particular.',
                    ),
                  )
                : StreamBuilder<List<MessageItem>>(
                    stream: messages,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <MessageItem>[];
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('Aún no hay mensajes.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final message = items[index];
                          final mine = message.senderId == user.id;
                          final readCount =
                              channel?.readCountForSequence(
                                message.sequence,
                                excludingUserId: message.senderId,
                              ) ??
                              0;
                          final audience =
                              ((channel?.memberUserIds.length ?? 1) - 1).clamp(
                                0,
                                9999,
                              );
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 520),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!mine)
                                    Text(
                                      '${message.senderName} • ${message.senderRole}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  SelectableText(message.body),
                                  const SizedBox(height: 3),
                                  if (mine &&
                                      (isAdmin || user.role == 'Docente'))
                                    _ReadReceipt(
                                      channel: channel!,
                                      message: message,
                                      readCount: readCount,
                                      audience: audience,
                                    )
                                  else
                                    Text(
                                      message.createdAt == null
                                          ? ''
                                          : DateFormat(
                                              'dd/MM/yyyy HH:mm',
                                            ).format(message.createdAt!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: title != null && !blocked,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: blocked
                          ? 'Este grupo está silenciado'
                          : 'Escribe un mensaje',
                      prefixIcon: const Icon(Icons.message_outlined),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar',
                  onPressed: sending || title == null || blocked
                      ? null
                      : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadReceipt extends StatelessWidget {
  const _ReadReceipt({
    required this.channel,
    required this.message,
    required this.readCount,
    required this.audience,
  });

  final MessageThreadSummary channel;
  final MessageItem message;
  final int readCount;
  final int audience;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: () => _showReaders(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          '${message.createdAt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(message.createdAt!)}'
          ' • Leído por $readCount de $audience',
          style: style,
        ),
      ),
    );
  }

  Future<void> _showReaders(BuildContext context) async {
    final readers =
        channel.readSequences.entries
            .where(
              (entry) =>
                  entry.key != message.senderId &&
                  entry.value >= message.sequence,
            )
            .toList()
          ..sort((a, b) {
            final aDate = channel.readAtByUser[a.key] ?? DateTime(1900);
            final bDate = channel.readAtByUser[b.key] ?? DateTime(1900);
            return bDate.compareTo(aDate);
          });
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lecturas del mensaje'),
        content: SizedBox(
          width: 460,
          child: readers.isEmpty
              ? const Text('Ningún destinatario lo ha leído todavía.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: readers.length,
                  itemBuilder: (context, index) {
                    final reader = readers[index];
                    final date = channel.readAtByUser[reader.key];
                    return ListTile(
                      leading: const Icon(Icons.done_all_outlined),
                      title: Text(channel.memberNames[reader.key] ?? 'Usuario'),
                      subtitle: Text(
                        [
                          channel.memberRoles[reader.key] ?? '',
                          if (date != null)
                            DateFormat('dd/MM/yyyy HH:mm').format(date),
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.contacts});
  final List<MessageContact> contacts;
  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.contacts
        .where(
          (contact) =>
              '${contact.fullName} ${contact.role} ${contact.groupName ?? ''}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: const Text('Mensaje particular'),
      content: SizedBox(
        width: 480,
        height: 430,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar persona',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No hay contactos disponibles.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final contact = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(contact.fullName),
                          subtitle: Text(
                            [
                              contact.role,
                              contact.groupName ?? '',
                            ].where((value) => value.isNotEmpty).join(' • '),
                          ),
                          onTap: () => Navigator.pop(context, contact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _ServiceChannelDraft {
  const _ServiceChannelDraft(
    this.title,
    this.category,
    this.audienceType,
    this.groupIds,
  );
  final String title, category, audienceType;
  final List<String> groupIds;
}

class _ServiceChannelDialog extends StatefulWidget {
  const _ServiceChannelDialog({required this.groups});
  final List<MessageThreadSummary> groups;
  @override
  State<_ServiceChannelDialog> createState() => _ServiceChannelDialogState();
}

class _ServiceChannelDialogState extends State<_ServiceChannelDialog> {
  final _title = TextEditingController();
  String _category = 'cafeteria';
  String _audience = 'all';
  final Set<String> _groups = {};
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuevo canal de servicio'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Nombre del canal'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Tipo e icono'),
              items: const [
                DropdownMenuItem(value: 'cafeteria', child: Text('Lonchera')),
                DropdownMenuItem(
                  value: 'restaurant',
                  child: Text('Restaurante'),
                ),
                DropdownMenuItem(value: 'route', child: Text('Ruta escolar')),
                DropdownMenuItem(value: 'community', child: Text('Comunidad')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Toda la sede')),
                ButtonSegment(value: 'groups', label: Text('Algunos grupos')),
              ],
              selected: {_audience},
              onSelectionChanged: (value) =>
                  setState(() => _audience = value.first),
            ),
            if (_audience == 'groups') ...[
              const SizedBox(height: 12),
              ...widget.groups.map(
                (group) => CheckboxListTile(
                  value: _groups.contains(group.groupId),
                  title: Text(group.groupName ?? group.title),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _groups.add(group.groupId!);
                    } else {
                      _groups.remove(group.groupId);
                    }
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed:
            _title.text.trim().isEmpty ||
                _audience == 'groups' && _groups.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _ServiceChannelDraft(
                  _title.text.trim(),
                  _category,
                  _audience,
                  _groups.toList(),
                ),
              ),
        child: const Text('Crear canal'),
      ),
    ],
  );
}
