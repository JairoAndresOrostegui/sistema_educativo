import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/userModelV2.dart';
import 'package:sistema_educativo/providers/user_provider_V2.dart';
import '../../../utils/snackbar_utils.dart';
import '../services/user_service_v2.dart';
import '../widgets/admin_photo_widget.dart';
import '../widgets/admin_user_form_widget.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  List<UserModelV2> usuarios = [];
  bool isLoading = true;
  String nombreCompleto = '';
  bool esSuperadminActual = false;
  List<String> funcionalidadesActual = [];
  late String institutionId;
  late String campusId;

  final UserServiceV2 _userService = UserServiceV2();

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

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _verificarPermisos() {
    final userProvider = context.read<UserProviderV2>();
    final user = userProvider.user!;
    esSuperadminActual = user.isSuperadmin;
    funcionalidadesActual = user.permissions;
    nombreCompleto = '${user.firstName} ${user.lastName}';
    institutionId = user.institution;
    campusId = user.campus;
  }

  Future<void> _cargarUsuarios() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      usuarios = await _userService.obtenerTodos(
        institutionId: institutionId,
        campusId: campusId,
      );
    } catch (e) {
      // ignore
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final logged = context.watch<UserProviderV2>().user!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Users management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
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
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withOpacity(.15),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.red.withOpacity(.06), Colors.white],
                          ),
                        ),
                        child: TextField(
                          controller: _busquedaController,
                          decoration: const InputDecoration(
                            hintText: 'Buscar usuario...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.redAccent,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          usuarios.isEmpty
                              ? const Center(
                                child: Text('No hay usuarios disponibles'),
                              )
                              : ListView.builder(
                                itemCount: usuarios.length,
                                itemBuilder: (context, index) {
                                  final user = usuarios[index];
                                  final fullName =
                                      '${user.firstName} ${user.lastName}'
                                          .toLowerCase();
                                  final correo =
                                      user.personalEmail.toLowerCase();

                                  if (_textoBusqueda.isNotEmpty &&
                                      !fullName.contains(_textoBusqueda) &&
                                      !correo.contains(_textoBusqueda)) {
                                    return const SizedBox.shrink();
                                  }

                                  final puedeEditar =
                                      esSuperadminActual ||
                                      funcionalidadesActual.contains(
                                        'usuarios.editar',
                                      );
                                  final puedeEliminar =
                                      esSuperadminActual ||
                                      funcionalidadesActual.contains(
                                        'usuarios.eliminar',
                                      );

                                  // No permitir que un admin se elimine a sí mismo
                                  final isSelf = logged.id == user.id;
                                  final isAdminUser =
                                      user.role == 'Administrador';
                                  final puedeEliminarEste =
                                      puedeEliminar && !(isSelf && isAdminUser);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(.15),
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.red.withOpacity(.06),
                                            Colors.white,
                                          ],
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Semantics(
                                          label: 'Foto de perfil',
                                          enabled: true,
                                          focusable: true,
                                          child: ProfilePhotoWidget(
                                            imageUrl: user.photoUrl ?? '',
                                            enableHoverEdit: false,
                                            radius: 24,
                                            iconSize: 48,
                                          ),
                                        ),
                                        title: Text(
                                          '${user.firstName} ${user.lastName}',
                                        ),
                                        subtitle: Text(
                                          '${user.personalEmail} • ${user.status.toUpperCase()}',
                                        ),
                                        trailing:
                                            isMobile
                                                ? null
                                                : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (puedeEditar)
                                                      IconButton(
                                                        tooltip: 'Editar',
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          color: Colors.green,
                                                        ),
                                                        onPressed:
                                                            () =>
                                                                _mostrarFormulario(
                                                                  usuario: user,
                                                                ),
                                                      ),
                                                    if (puedeEliminarEste)
                                                      IconButton(
                                                        tooltip: 'Eliminar',
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed:
                                                            () =>
                                                                _eliminarUsuario(
                                                                  user,
                                                                ),
                                                      ),
                                                  ],
                                                ),
                                        onTap:
                                            () => _mostrarFormulario(
                                              usuario: user,
                                              soloLectura: !puedeEditar,
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _eliminarUsuario(UserModelV2 usuario) async {
    final logged = context.read<UserProviderV2>().user!;
    final isSelf = logged.id == usuario.id;
    final isAdminUser = usuario.role == 'Administrador';

    if (isSelf && isAdminUser) {
      if (mounted)
        mostrarSnack(
          context,
          'No puedes eliminar tu propio usuario de Administrador.',
        );
      return;
    }

    final confirmacion = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que deseas eliminar a ${usuario.firstName} ${usuario.lastName}?\n'
              'Esta acción eliminará su cuenta del sistema y no se puede deshacer.',
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
      await _userService.registrarHistorial(
        usuario: usuario,
        accion: 'eliminado',
        realizadoPor: nombreCompleto,
      );
      await _userService.eliminar(usuario);
      await _cargarUsuarios();

      if (mounted) mostrarSnack(context, 'Usuario eliminado correctamente');
    } catch (e) {
      if (mounted) mostrarSnack(context, 'Error al eliminar usuario: $e');
    }
  }

  void _mostrarFormulario({
    UserModelV2? usuario,
    bool soloLectura = false,
  }) async {
    final bool? resultado = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AdminUserFormWidget(
            usuario: usuario,
            soloLectura: soloLectura,
            onSuccess: () {},
          ),
    );

    if (resultado == true) {
      if (!mounted) return;
      await _cargarUsuarios();
      if (mounted) {
        mostrarSnack(context, 'Usuario guardado con éxito');
      }
    }
  }
}
