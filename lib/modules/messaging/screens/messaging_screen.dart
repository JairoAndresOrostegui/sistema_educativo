import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/messaging/message_models.dart';
import '../../../models/user/user_model_v2.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../services/messaging_service.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final _svc = MessagingService();
  final _messageCtrl = TextEditingController();

  userModelv2? _logged;
  bool _loading = true;
  bool _loadingContacts = true;
  bool _sending = false;

  List<MessageContact> _contacts = [];
  List<MessagingChildContext> _children = [];

  String? _selectedThreadId;
  MessageContact? _draftContact;
  String? _activeStudentId;

  bool get _hasMessagingPermission {
    final perms =
        _logged?.permissions.map((e) => e.trim().toLowerCase()).toSet() ?? {};
    return (_logged?.isSuperadmin ?? false) ||
        perms.contains('mensajeria.ver');
  }

  bool get _canUseModule {
    final role = (_logged?.role ?? '').trim();
    final roleAllowed =
        role == 'Administrador' ||
        role == 'Docente' ||
        role == 'Estudiante' ||
        role == 'Familiar';
    return roleAllowed && _hasMessagingPermission;
  }

  bool get _isFamily => (_logged?.role ?? '').trim() == 'Familiar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final userProvider = context.read<UserProviderV2>();
    final user = userProvider.user;
    if (user == null) return;

    _logged = user;
    if (!_canUseModule) {
      setState(() => _loading = false);
      return;
    }

    if (_isFamily) {
      _children = await _svc.getFamilyChildren(user);
      if (_children.isNotEmpty) {
        final currentActive = (user.activeStudentId ?? '').trim();
        final exists = _children.any((c) => c.id == currentActive);
        _activeStudentId = exists ? currentActive : _children.first.id;
        if (_activeStudentId != null) {
          userProvider.setActiveStudentId(_activeStudentId!);
        }
      }
    } else if ((user.role).trim() == 'Estudiante') {
      _activeStudentId = user.id;
    }

    await _loadContacts();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadContacts() async {
    final user = _logged;
    if (user == null) return;

    setState(() => _loadingContacts = true);
    final contacts = await _svc.getAvailableContacts(
      user: user,
      studentContextId: _activeStudentId,
    );
    if (!mounted) return;

    setState(() {
      _contacts = contacts;
      _loadingContacts = false;
    });
  }

  void _onSelectThread(MessageThreadSummary thread) {
    setState(() {
      _selectedThreadId = thread.id;
      _draftContact = null;
    });
  }

  void _onStudentChanged(String studentId) async {
    if (_activeStudentId == studentId) return;
    setState(() {
      _activeStudentId = studentId;
      _draftContact = null;
      _loadingContacts = true;
    });
    context.read<UserProviderV2>().setActiveStudentId(studentId);
    await _loadContacts();
  }

  Future<void> _onNewMessage(List<MessageThreadSummary> threads) async {
    if (_loadingContacts) return;
    if (_contacts.isEmpty) {
      await DialogUtils.showError(
        context: context,
        title: 'Sin destinatarios',
        message: 'No hay contactos disponibles para este usuario.',
      );
      return;
    }

    final picked = await showDialog<MessageContact>(
      context: context,
      builder: (_) => _SearchableContactPickerDialog(contacts: _contacts),
    );
    if (picked == null) return;

    final existing = threads.where((t) {
      final peerId = t.peerIdFor(_logged!.id);
      return peerId == picked.id &&
          (t.contextStudentId ?? '') == (picked.studentContextId ?? '');
    }).cast<MessageThreadSummary?>().firstWhere((e) => e != null, orElse: () => null);

    setState(() {
      _selectedThreadId = existing?.id;
      _draftContact = existing == null ? picked : null;
    });
  }

  Future<void> _sendMessage(MessageThreadSummary? activeThread) async {
    final user = _logged;
    if (user == null || _sending) return;

    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final threadRecipientId = activeThread?.peerIdFor(user.id);
    final recipientId = threadRecipientId ?? _draftContact?.id;
    if (recipientId == null) {
      await DialogUtils.showError(
        context: context,
        title: 'Sin destinatario',
        message: 'Selecciona una conversación o crea un mensaje nuevo.',
      );
      return;
    }

    setState(() => _sending = true);

    try {
      if (activeThread == null && (_draftContact?.isGroup ?? false)) {
        final sentCount = await _svc.sendMessageToGroup(
          sender: user,
          group: _draftContact!,
          body: text,
        );
        final scopeName = _draftContact?.fullName ?? 'grupo seleccionado';

        _messageCtrl.clear();
        if (!mounted) return;
        setState(() {
          _selectedThreadId = null;
          _draftContact = null;
        });
        await DialogUtils.showSuccess(
          context: context,
          title: 'Enviado',
          message: 'Mensaje enviado a $sentCount destinatarios de $scopeName.',
        );
        return;
      }

      final threadContextId = activeThread?.contextStudentId ?? _draftContact?.studentContextId;
      final threadContextName =
          activeThread?.contextStudentName ?? _draftContact?.studentContextName;
      final threadContextGrade =
          activeThread?.contextStudentGrade ?? _draftContact?.studentContextGrade;

      final newThreadId = await _svc.sendMessage(
        sender: user,
        recipientId: recipientId,
        threadId: activeThread?.id,
        body: text,
        studentContextId: threadContextId,
        studentContextName: threadContextName,
        studentContextGrade: threadContextGrade,
      );

      _messageCtrl.clear();
      if (!mounted) return;
      setState(() {
        _selectedThreadId = newThreadId;
        _draftContact = null;
      });
    } catch (e) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  MessageThreadSummary? _resolveActiveThread(List<MessageThreadSummary> threads) {
    if (_selectedThreadId == null) return null;
    return threads.where((t) => t.id == _selectedThreadId).cast<MessageThreadSummary?>().firstWhere(
      (t) => t != null,
      orElse: () => null,
    );
  }

  String _subtitleForThread(MessageThreadSummary thread, String currentUserId) {
    final contextName = thread.contextStudentName;
    final contextGrade = thread.contextStudentGrade;
    final peerRole = thread.peerRoleFor(currentUserId);

    if ((contextName ?? '').trim().isNotEmpty) {
      final gradeText = (contextGrade ?? '').trim();
      if (gradeText.isNotEmpty) {
        return '$peerRole • $contextName • $gradeText';
      }
      return '$peerRole • $contextName';
    }
    return peerRole;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserProviderV2>().user;
    if (session == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('No hay sesión activa.'))),
      );
    }

    if (_loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
        ),
      );
    }

    if (!_canUseModule) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mensajería'),
          leading: const BackToDashboardButton(),
          backgroundColor: Colors.white,
          foregroundColor: Colors.redAccent,
          centerTitle: true,
        ),
        backgroundColor: Colors.white,
        body: const SafeArea(child: Center(child: Text('Acceso denegado.'))),
      );
    }

    return StreamBuilder<List<MessageThreadSummary>>(
      stream: _svc.watchThreadsForUser(
        institutionId: session.institution,
        campusId: session.campus,
        userId: session.id,
      ),
      builder: (context, snapshot) {
        final threads = snapshot.data ?? const <MessageThreadSummary>[];
        final activeThread = _resolveActiveThread(threads);
        final currentTitle =
            activeThread != null
                ? activeThread.peerNameFor(session.id)
                : _draftContact?.fullName ?? 'Selecciona una conversación';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Mensajería'),
            leading: const BackToDashboardButton(),
            backgroundColor: Colors.white,
            foregroundColor: Colors.redAccent,
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () => _onNewMessage(threads),
                icon: const Icon(Icons.edit_square),
                tooltip: 'Nuevo mensaje',
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isFamily && _children.isNotEmpty) ...[
                    _FamilyChildSelector(
                      children: _children,
                      activeStudentId: _activeStudentId,
                      onChanged: _onStudentChanged,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.withValues(alpha: .15)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Conversaciones: ${threads.length} • $currentTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_loadingContacts)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        if (isWide) {
                          return Row(
                            children: [
                              SizedBox(
                                width: 320,
                                child: _ThreadsPane(
                                  threads: threads,
                                  currentUserId: session.id,
                                  selectedThreadId: activeThread?.id,
                                  subtitleBuilder: (t) => _subtitleForThread(t, session.id),
                                  onTap: _onSelectThread,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ChatPane(
                                  thread: activeThread,
                                  draftContact: _draftContact,
                                  currentUserId: session.id,
                                  messageCtrl: _messageCtrl,
                                  sending: _sending,
                                  stream: activeThread == null ? null : _svc.watchMessages(activeThread.id),
                                  formatDate: _formatDate,
                                  onSend: () => _sendMessage(activeThread),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: _ThreadsPane(
                                threads: threads,
                                currentUserId: session.id,
                                selectedThreadId: activeThread?.id,
                                subtitleBuilder: (t) => _subtitleForThread(t, session.id),
                                onTap: _onSelectThread,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _ChatPane(
                                thread: activeThread,
                                draftContact: _draftContact,
                                currentUserId: session.id,
                                messageCtrl: _messageCtrl,
                                sending: _sending,
                                stream: activeThread == null ? null : _svc.watchMessages(activeThread.id),
                                formatDate: _formatDate,
                                onSend: () => _sendMessage(activeThread),
                              ),
                            ),
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

class _FamilyChildSelector extends StatelessWidget {
  const _FamilyChildSelector({
    required this.children,
    required this.activeStudentId,
    required this.onChanged,
  });

  final List<MessagingChildContext> children;
  final String? activeStudentId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: .15)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.red.withValues(alpha: .06), Colors.white],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeStudentId,
              isExpanded: true,
              hint: const Text('Estudiante'),
              items:
                  children
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Text('${e.fullName} • ${e.grade}'),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadsPane extends StatelessWidget {
  const _ThreadsPane({
    required this.threads,
    required this.currentUserId,
    required this.selectedThreadId,
    required this.subtitleBuilder,
    required this.onTap,
  });

  final List<MessageThreadSummary> threads;
  final String currentUserId;
  final String? selectedThreadId;
  final String Function(MessageThreadSummary thread) subtitleBuilder;
  final ValueChanged<MessageThreadSummary> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: .12)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withValues(alpha: .04), Colors.white],
        ),
      ),
      child:
          threads.isEmpty
              ? const Center(child: Text('No hay conversaciones'))
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: threads.length,
                itemBuilder: (_, i) {
                  final thread = threads[i];
                  final selected = thread.id == selectedThreadId;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected
                                ? Colors.redAccent
                                : Colors.red.withValues(alpha: .10),
                      ),
                      color:
                          selected
                              ? Colors.red.withValues(alpha: .08)
                              : Colors.transparent,
                    ),
                    child: ListTile(
                      onTap: () => onTap(thread),
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.redAccent),
                      title: Text(
                        thread.peerNameFor(currentUserId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          subtitleBuilder(thread),
                          if ((thread.lastMessage ?? '').trim().isNotEmpty) thread.lastMessage!,
                        ].where((e) => e.trim().isNotEmpty).join('\n'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.thread,
    required this.draftContact,
    required this.currentUserId,
    required this.messageCtrl,
    required this.sending,
    required this.stream,
    required this.formatDate,
    required this.onSend,
  });

  final MessageThreadSummary? thread;
  final MessageContact? draftContact;
  final String currentUserId;
  final TextEditingController messageCtrl;
  final bool sending;
  final Stream<List<MessageItem>>? stream;
  final String Function(DateTime? value) formatDate;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final title = thread?.peerNameFor(currentUserId) ?? draftContact?.fullName;
    final subtitle = [
      if ((thread?.peerRoleFor(currentUserId) ?? draftContact?.role ?? '').trim().isNotEmpty)
        thread?.peerRoleFor(currentUserId) ?? draftContact!.role,
      if ((thread?.contextStudentName ?? draftContact?.studentContextName ?? '').trim().isNotEmpty)
        'Contexto: ${thread?.contextStudentName ?? draftContact!.studentContextName}',
    ].join(' • ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: .12)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withValues(alpha: .04), Colors.white],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: Colors.red.withValues(alpha: .10)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Sin conversación seleccionada',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (subtitle.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(color: Colors.black.withValues(alpha: .65)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                stream == null
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Selecciona una conversación o crea una nueva.'),
                      ),
                    )
                    : StreamBuilder<List<MessageItem>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        final messages = snapshot.data ?? const <MessageItem>[];
                        if (messages.isEmpty) {
                          return const Center(child: Text('Aún no hay mensajes.'));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final msg = messages[i];
                            final mine = msg.senderId == currentUserId;
                            return Align(
                              alignment:
                                  mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 420),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      mine
                                          ? Colors.redAccent
                                          : Colors.red.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      mine
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                  children: [
                                    if (!mine)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          msg.senderName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      msg.body,
                                      style: TextStyle(
                                        color: mine ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDate(msg.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            mine
                                                ? Colors.white.withValues(alpha: .85)
                                                : Colors.black.withValues(alpha: .55),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.red.withValues(alpha: .10)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: sending ? null : onSend,
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  child:
                      sending
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ContactPickerDialog extends StatelessWidget {
  const _ContactPickerDialog({required this.contacts});

  final List<MessageContact> contacts;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo mensaje'),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: contacts.length,
          itemBuilder: (_, i) {
            final c = contacts[i];
            final meta = [
              c.role,
              if ((c.grade ?? '').trim().isNotEmpty) c.grade!,
              if ((c.studentContextName ?? '').trim().isNotEmpty) c.studentContextName!,
            ].join(' • ');
            return ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.redAccent),
              title: Text(c.fullName),
              subtitle: Text(meta),
              onTap: () => Navigator.pop(context, c),
            );
          },
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

class _SearchableContactPickerDialog extends StatefulWidget {
  const _SearchableContactPickerDialog({required this.contacts});

  final List<MessageContact> contacts;

  @override
  State<_SearchableContactPickerDialog> createState() =>
      _SearchableContactPickerDialogState();
}

class _SearchableContactPickerDialogState
    extends State<_SearchableContactPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MessageContact> get _visibleContacts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.contacts.take(5).toList();
    }

    return widget.contacts.where((c) {
      final haystack = [
        c.fullName,
        c.role,
        c.groupType ?? '',
        c.targetRole ?? '',
        c.grade ?? '',
        c.targetGrade ?? '',
        c.studentContextName ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _visibleContacts;

    return AlertDialog(
      title: const Text('Nuevo mensaje'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar por grado o estudiante',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: contacts.isEmpty
                  ? const Center(
                      child: Text('No se encontraron destinatarios.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: contacts.length,
                      itemBuilder: (_, i) {
                        final c = contacts[i];
                        final meta = [
                          c.role,
                          if (c.isGroup &&
                              (c.targetGrade ?? '').trim().isNotEmpty)
                            'Envio masivo',
                          if (c.isGroup &&
                              (c.targetRole ?? '').trim().isNotEmpty)
                            'Rol: ${c.targetRole}',
                          if ((c.groupType ?? '').trim() == 'all_users')
                            'Envio masivo',
                          if ((c.grade ?? '').trim().isNotEmpty) c.grade!,
                          if ((c.studentContextName ?? '').trim().isNotEmpty)
                            c.studentContextName!,
                        ].join(' • ');
                        return ListTile(
                          leading: Icon(
                            c.isGroup
                                ? Icons.groups_outlined
                                : Icons.person_outline,
                            color: Colors.redAccent,
                          ),
                          title: Text(c.fullName),
                          subtitle: Text(meta),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (_query.trim().isEmpty && widget.contacts.length > 5)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Mostrando 5 de ${widget.contacts.length}',
              style: TextStyle(color: Colors.black.withValues(alpha: .6)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
