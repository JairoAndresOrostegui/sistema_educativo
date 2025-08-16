import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_route_service.dart';
import '../widgets/admin/admin_route_form_dialog.dart';
import '../../../models/route/route_model.dart';
import '../../../providers/user_provider_V2.dart';
import '../../../utils/snackbar_utils.dart';

class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  List<RouteModel> routes = [];
  bool isLoading = true;
  bool isSuperadmin = false;
  List<String> permissions = [];
  final ScrollController _routesScrollController = ScrollController();

  late String _institutionId;
  late String _campusId;
  late String _performedBy;
  late String _adminName;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _loadRoutes();
  }

  void _loadSessionData() {
    final user = context.read<UserProviderV2>().user;
    if (user != null) {
      isSuperadmin = user.isSuperadmin;
      permissions = user.permissions;
      _institutionId = user.institution;
      _campusId = user.campus;
      _performedBy = user.id;
      _adminName = '${user.firstName} ${user.lastName}'.trim();
      setState(() {});
    }
  }

  Future<void> _loadRoutes() async {
    setState(() => isLoading = true);
    try {
      routes = await RouteService().obtenerTodasLasRutas(
        institutionId: _institutionId,
        campusId: _campusId,
      );
    } catch (_) {}
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _deleteRoute(RouteModel route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ruta?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await RouteService().eliminarRuta(
          route.id,
          performedBy: _performedBy,
          adminName: _adminName,
          institutionId: _institutionId,
          campusId: _campusId,
        );
        if (!mounted) return;
        await _loadRoutes();
        if (!mounted) return;
        mostrarSnack(context, 'Ruta eliminada correctamente');
      } catch (_) {
        if (!mounted) return;
        mostrarSnack(context, 'Error al eliminar la ruta');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = isSuperadmin || permissions.contains('rutas.crear');
    final canEdit = isSuperadmin || permissions.contains('rutas.editar');
    final canDelete = isSuperadmin || permissions.contains('rutas.eliminar');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('School route management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => mostrarFormularioRuta(
                context: context,
                onGuardar: _loadRoutes,
              ),
              tooltip: 'Crear nueva ruta',
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => mostrarFormularioRuta(
                context: context,
                onGuardar: _loadRoutes,
              ),
              child: const Icon(Icons.add),
              tooltip: 'Crear nueva ruta',
            )
          : null,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : routes.isEmpty
                ? const Center(child: Text('No hay rutas registradas.'))
                : Scrollbar(
                    controller: _routesScrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _routesScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: routes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final route = routes[index];

                        return Semantics(
                          container: true,
                          label:
                              'Ruta ${route.name}. Dirección de inicio: ${route.startAddress}.',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                route.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(route.startAddress),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canEdit)
                                    Semantics(
                                      button: true,
                                      label: 'Editar ruta ${route.name}',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blueAccent,
                                        ),
                                        onPressed: () => mostrarFormularioRuta(
                                          context: context,
                                          rutaModel: route,
                                          onGuardar: _loadRoutes,
                                        ),
                                        tooltip: 'Editar ruta',
                                      ),
                                    ),
                                  if (canDelete)
                                    Semantics(
                                      button: true,
                                      label: 'Eliminar ruta ${route.name}',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => _deleteRoute(route),
                                        tooltip: 'Eliminar ruta',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
