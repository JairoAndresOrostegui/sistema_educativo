import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model.dart';
import 'package:sistema_educativo/utils/snackbar_utils.dart';
import 'package:sistema_educativo/modules/auth/widgets/profile_photo_widget.dart';

import '../../../services/auth/auth_service.dart';
import '../../auth/providers/user_provider.dart';
import '../widget/admin_user_form_widget.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  List<UsuarioModel> usuarios = [];
  bool isLoading = true;
  String nombreCompleto = '';
  bool esSuperadminActual = false;

  List<String> funcionalidadesActual = [];

  final List<String> roles = ['admin', 'docente', 'estudiante'];
  final List<String> tipoDocumentoOpciones = [
    'Registro Civil',
    'Tarjeta de Identidad',
    'Cédula',
    'Pasaporte',
  ];

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
    _cargarUsuarios();
    _busquedaController.addListener(() {
      setState(() {
        _textoBusqueda = _busquedaController.text.toLowerCase();
      });
    });
  }

  Future<void> _verificarPermisos() async {
    final userProvider = context.read<UsuarioProvider>();
    if (userProvider == null) return;
    final user = userProvider.usuario!;
    esSuperadminActual = user.esSuperadmin;
    funcionalidadesActual = user.funcionalidades;
    nombreCompleto = '${user.nombres} ${user.apellidos}';
  }

  Future<void> _cargarUsuarios() async {
    setState(() => isLoading = true);
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    usuarios =
        snapshot.docs
            .map((doc) => UsuarioModel.fromFirestore(doc.data(), doc.id))
            .toList();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        elevation: 1,
      ),
      floatingActionButton:
          (esSuperadminActual ||
                  funcionalidadesActual.contains('usuarios.crear'))
              ? FloatingActionButton(
                onPressed: () => _mostrarFormulario(),
                child: const Icon(Icons.add),
              )
              : null,
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _busquedaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar usuario...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final user = usuarios[index];
                        final fullName =
                            '${user.nombres} ${user.apellidos}'.toLowerCase();
                        final correo = user.correoPersonal.toLowerCase();

                        if (_textoBusqueda.isNotEmpty &&
                            !fullName.contains(_textoBusqueda) &&
                            !correo.contains(_textoBusqueda)) {
                          return const SizedBox.shrink();
                        }

                        final puedeEditar =
                            esSuperadminActual ||
                            funcionalidadesActual.contains('usuarios.editar');
                        final puedeEliminar =
                            esSuperadminActual ||
                            funcionalidadesActual.contains('usuarios.eliminar');

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: Semantics(
                              label: 'Foto de perfil',
                              enabled: true,
                              focusable: true,
                              child: ProfilePhotoWidget(
                                imageUrl: user.fotoUrl,
                                enableHoverEdit: false,
                                radius: 24,
                                iconSize: 48,
                              ),
                            ),
                            title: Text('${user.nombres} ${user.apellidos}'),
                            subtitle: Text(user.correoPersonal),
                            trailing:
                                isMobile
                                    ? null
                                    : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (puedeEditar)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.green,
                                            ),
                                            onPressed:
                                                () => _mostrarFormulario(
                                                  usuario: user,
                                                ),
                                          ),
                                        if (puedeEliminar)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _eliminarUsuario(user.id),
                                          ),
                                      ],
                                    ),
                            onTap:
                                () => _mostrarFormulario(
                                  usuario: user,
                                  soloLectura: !puedeEditar,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  void _eliminarUsuario(String id) async {
    final usuario = usuarios.firstWhere((u) => u.id == id);

    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que deseas eliminar a ${usuario.nombres} ${usuario.apellidos}?\n\nEsta acción eliminará su cuenta del sistema y no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmacion != true) return;

    try {
      await UsuarioService().registrarHistorialUsuario(
        usuario: usuario,
        accion: 'eliminado',
        realizadoPor: nombreCompleto,
      );
      // 1. Eliminar de Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(id).delete();

      // 2. Eliminar de Firebase Auth
      await UsuarioService().eliminarUsuarioAuth(id);

      // 3. Refrescar lista
      await _cargarUsuarios();

      if (mounted) mostrarSnack(context, 'Usuario eliminado correctamente');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Error al eliminar usuario: $e');
    }
  }

  void _mostrarFormulario({UsuarioModel? usuario, bool soloLectura = false}) {
    showDialog(
      context: context,
      builder:
          (ctx) => AdminUserFormWidget(
            usuario: usuario,
            soloLectura: soloLectura,
            onSuccess: () {
              Navigator.of(ctx).pop();
              _cargarUsuarios();
            },
          ),
    );
  }
}
