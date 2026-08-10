import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../services/user_service_v2.dart';
import '../widgets/admin/admin_photo_widget.dart';
import '../widgets/admin/admin_user_form_widget.dart';
import '../widgets/admin/teacher_bulk_import_dialog.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _busquedaController = TextEditingController();
  String _textoBusqueda = '';
  List<userModelv2> usuarios = [];
  bool isLoading = true;
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
        isSuperadmin: esSuperadminActual,
      );
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'Error al cargar usuarios',
          message: e.toString(),
        );
      }
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final logged = context.watch<UserProviderV2>().user!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: const Text('Gestión de usuarios'),
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.primary,
        centerTitle: true,
        surfaceTintColor: AppPalette.transparent,
        elevation: 1,
        leading: const BackToDashboardButton(),
        actions: [
          if (esSuperadminActual)
            IconButton(
              tooltip: 'Importar docentes',
              onPressed: _mostrarImportacionDocentes,
              icon: const Icon(Icons.upload_file),
            ),
        ],
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: .15),
                        ),
                        color: AppPalette.surfaceContainer,
                      ),
                      child: TextField(
                        controller: _busquedaController,
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppPalette.primary,
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
                    child: usuarios.isEmpty
                        ? const Center(
                            child: Text('No hay usuarios disponibles'),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              bottom:
                                  96 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: usuarios.length,
                            itemBuilder: (context, index) {
                              final user = usuarios[index];
                              final fullName =
                                  '${user.firstName} ${user.lastName}'
                                      .toLowerCase();
                              final correo = user.personalEmail.toLowerCase();

                              if (_textoBusqueda.isNotEmpty &&
                                  !fullName.contains(_textoBusqueda) &&
                                  !correo.contains(_textoBusqueda)) {
                                return const SizedBox.shrink();
                              }

                              final puedeEditar =
                                  user.status != 'eliminado' &&
                                  (esSuperadminActual ||
                                      (user.role != 'Administrador' &&
                                          !user.isSuperadmin)) &&
                                  (esSuperadminActual ||
                                      funcionalidadesActual.contains(
                                        'usuarios.editar',
                                      ));
                              final puedeEliminar =
                                  esSuperadminActual ||
                                  funcionalidadesActual.contains(
                                    'usuarios.eliminar',
                                  );

                              // No permitir que un admin se elimine a sí mismo
                              final isSelf = logged.id == user.id;
                              final isAdminUser = user.role == 'Administrador';
                              final puedeEliminarEste =
                                  puedeEliminar &&
                                  !isSelf &&
                                  (esSuperadminActual || !isAdminUser);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppPalette.primary.withValues(
                                        alpha: .15,
                                      ),
                                    ),
                                    color: AppPalette.surfaceContainer,
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
                                      '${user.personalEmail} - ${user.status.toUpperCase()}',
                                    ),
                                    trailing: isMobile
                                        ? null
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (puedeEditar)
                                                IconButton(
                                                  tooltip: 'Editar',
                                                  icon: Icon(
                                                    Icons.edit,
                                                    color: AppPalette.success,
                                                  ),
                                                  onPressed: () =>
                                                      _mostrarFormulario(
                                                        usuario: user,
                                                      ),
                                                ),
                                              if (puedeEliminarEste)
                                                IconButton(
                                                  tooltip: 'Eliminar',
                                                  icon: Icon(
                                                    Icons.delete,
                                                    color: AppPalette.primary,
                                                  ),
                                                  onPressed: () =>
                                                      _eliminarUsuario(user),
                                                ),
                                            ],
                                          ),
                                    onTap: () => _mostrarFormulario(
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

  Future<void> _eliminarUsuario(userModelv2 usuario) async {
    final logged = context.read<UserProviderV2>().user!;
    final isSelf = logged.id == usuario.id;
    final isAdminUser = usuario.role == 'Administrador';

    if (isSelf && isAdminUser) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'Accion no permitida',
          message: 'No puedes eliminar tu propio usuario de Administrador.',
        );
      }
      return;
    }

    try {
      final impact = await _userService.obtenerImpactoEliminacion(usuario.id);
      if (!mounted) return;

      final selectedMode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            esSuperadminActual ? 'Eliminacion definitiva' : 'Retirar usuario',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${usuario.firstName} ${usuario.lastName} tiene '
                    '${impact.linkedRecords} registros institucionales '
                    'relacionados.',
                  ),
                  const SizedBox(height: 12),
                  if (!esSuperadminActual && impact.linkedRecords > 0)
                    const Text(
                      'Recomendacion: dejalo inactivo. No podra iniciar '
                      'sesion y se conservara visible para administrar '
                      'su informacion institucional.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (esSuperadminActual)
                    const Text(
                      'La eliminacion definitiva resolvera estas '
                      'relaciones y conservara el registro de auditoria. '
                      'Esta decision quedara bajo tu responsabilidad.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  ...impact.items.where((item) => item.count > 0).map((item) {
                    final action = switch (item.action) {
                      'delete' => 'se eliminaran',
                      'unlink' => 'se desvincularan',
                      _ => 'se conservaran como auditoria',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('- ${item.label}: ${item.count} ($action)'),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            if (!esSuperadminActual)
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, 'inactive'),
                child: const Text('Dejar inactivo'),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
              ),
              onPressed: () => Navigator.pop(
                dialogContext,
                esSuperadminActual ? 'permanent' : 'soft',
              ),
              child: Text(
                esSuperadminActual ? 'Continuar' : 'Retirar del listado',
              ),
            ),
          ],
        ),
      );

      if (selectedMode == null || !mounted) return;
      if (selectedMode == 'permanent') {
        final confirmation = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ultima confirmacion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escribe ELIMINAR para confirmar la eliminacion '
                  'definitiva y en cascada.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmacion',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                ),
                onPressed: () => Navigator.pop(
                  dialogContext,
                  confirmation.text.trim() == 'ELIMINAR',
                ),
                child: const Text('Eliminar definitivamente'),
              ),
            ],
          ),
        );
        confirmation.dispose();
        if (confirmed != true) return;
      }

      await _userService.eliminar(usuario, mode: selectedMode);
      await _cargarUsuarios();

      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: selectedMode == 'inactive'
              ? 'Usuario inactivo'
              : selectedMode == 'soft'
              ? 'Usuario retirado'
              : 'Usuario eliminado',
          message: selectedMode == 'inactive'
              ? 'El usuario ya no puede iniciar sesion.'
              : selectedMode == 'soft'
              ? 'Solo el superadministrador podra verlo desde ahora.'
              : 'La cascada termino y se conservo su auditoria.',
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'Error al eliminar usuario',
          message: e.toString(),
        );
      }
    }
  }

  void _mostrarFormulario({
    userModelv2? usuario,
    bool soloLectura = false,
  }) async {
    final bool? resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminUserFormWidget(
        usuario: usuario,
        soloLectura: soloLectura,
        onSuccess: () {},
      ),
    );

    if (resultado == true) {
      if (!mounted) return;
      await _cargarUsuarios();
      if (mounted) {
        await DialogUtils.showSuccess(
          context: context,
          title: 'Usuario guardado',
          message: 'El usuario se guardo correctamente.',
        );
      }
    }
  }

  Future<void> _mostrarImportacionDocentes() async {
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (ctx) => const TeacherBulkImportDialog(),
    );

    if (shouldRefresh == true) {
      if (!mounted) return;
      await _cargarUsuarios();
    }
  }
}
