import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/navigation_utils.dart';
import '../../user/services/user_service_v2.dart';
import '../../../models/user/user_model_v2.dart';

class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  final UserServiceV2 _userService = UserServiceV2();
  bool _loading = true;
  String _selectedRole = 'padres';
  List<userModelv2> _allUsers = [];
  List<userModelv2> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final user = context.read<UserProviderV2>().user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final all = await _userService.obtenerTodos(
        institutionId: user.institution,
        campusId: user.campus,
      );
      _allUsers = all;
      _users = _filterUsers(_allUsers, _selectedRole);
    } catch (_) {
      _allUsers = [];
      _users = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<userModelv2> _filterUsers(List<userModelv2> all, String roleKey) {
    final roleSet = _roleValues(roleKey);
    return all
        .where(
          (u) => roleSet.contains(u.role.trim().toLowerCase()),
        )
        .toList()
      ..sort(
        (a, b) =>
            '${a.firstName} ${a.lastName}'.compareTo(
              '${b.firstName} ${b.lastName}',
            ),
      );
  }

  Set<String> _roleValues(String roleKey) {
    switch (roleKey) {
      case 'docentes':
        return {'docente'};
      case 'estudiantes':
        return {'estudiante'};
      case 'padres':
      default:
        return {'familiar', 'padre', 'madre'};
    }
  }

  Future<void> _showQr(userModelv2 user) async {
    final payload = jsonEncode({
      'uid': user.id,
      'role': user.role,
      'document': user.document,
    });

    if (!mounted) return;
    try {
      await _userService.actualizarQr(uid: user.id, payload: payload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el QR.')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QrDetailScreen(user: user, payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = const [
      {'key': 'padres', 'label': 'Padres'},
      {'key': 'estudiantes', 'label': 'Estudiantes'},
      {'key': 'docentes', 'label': 'Docentes'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR'),
        leading: const BackToDashboardButton(),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Tipo de usuario:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items:
                            roles
                                .map(
                                  (r) => DropdownMenuItem<String>(
                                    value: r['key'],
                                    child: Text(r['label']!),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedRole = value;
                            _users = _filterUsers(_allUsers, _selectedRole);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _users.isEmpty
                    ? const Center(
                      child: Text('No hay usuarios disponibles.'),
                    )
                    : ListView.separated(
                      itemCount: _users.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final u = _users[index];
                        final name =
                            '${u.firstName} ${u.lastName}'.trim().isEmpty
                                ? 'Sin nombre'
                                : '${u.firstName} ${u.lastName}'.trim();
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(
                            '${u.role} • ${u.document.isEmpty ? 'Sin documento' : u.document}',
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _showQr(u),
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Generar QR'),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}

class _QrDetailScreen extends StatelessWidget {
  final userModelv2 user;
  final String payload;

  const _QrDetailScreen({
    required this.user,
    required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        '${user.firstName} ${user.lastName}'.trim().isEmpty
            ? 'Sin nombre'
            : '${user.firstName} ${user.lastName}'.trim();
    final subtitle =
        '${user.role} - ${user.document.isEmpty ? 'Sin documento' : user.document}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de usuario'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: payload,
                size: 240,
                backgroundColor: Colors.white,
                errorStateBuilder: (_, __) {
                  return const Text(
                    'No se pudo generar el QR.',
                    style: TextStyle(color: Colors.redAccent),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}




