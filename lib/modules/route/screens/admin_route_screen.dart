import 'package:flutter/material.dart';
import '../widgets/route_history_dialog.dart';
import '../widgets/route_admin_tools.dart';
import 'package:provider/provider.dart';

import '../services/admin_route_service.dart';
import '../widgets/admin/admin_route_form_dialog.dart';
import '../../../models/route/route_model.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../utils/route_ui_helpers.dart';

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
  String? _loadError;
  final ScrollController _routesScrollController = ScrollController();

  String _institutionId = '';
  String _campusId = '';
  String _performedBy = '';
  String _adminName = '';

  @override
  void initState() {
    super.initState();
    if (_loadSessionData()) {
      _loadRoutes();
    } else {
      isLoading = false;
      _loadError = 'Tu sesión no está disponible. Inicia sesión nuevamente.';
    }
  }

  bool _loadSessionData() {
    final user = context.read<UserProviderV2>().user;
    if (user == null) return false;
    isSuperadmin = user.isSuperadmin;
    permissions = user.permissions;
    _institutionId = user.institution;
    _campusId = user.campus;
    _performedBy = user.id;
    _adminName = '${user.firstName} ${user.lastName}'.trim();
    return true;
  }

  Future<void> _loadRoutes() async {
    setState(() => isLoading = true);
    try {
      final loaded = await RouteService().obtenerTodasLasRutas(
        institutionId: _institutionId,
        campusId: _campusId,
      );
      if (mounted) {
        setState(() {
          routes = loaded;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _loadError = routeErrorMessage(
            e,
            fallback: 'No se pudieron consultar las rutas.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteRoute(RouteModel route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar ruta?'),
        content: Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
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
        await DialogUtils.showSuccess(
          context: context,
          title: 'Ruta eliminada',
          message: 'Ruta eliminada correctamente',
        );
      } catch (e) {
        if (!mounted) return;
        await DialogUtils.showError(
          context: context,
          title: 'Error',
          message: routeErrorMessage(
            e,
            fallback: 'No fue posible eliminar la ruta.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canCreate = isSuperadmin || permissions.contains('rutas.crear');
    final canEdit = isSuperadmin || permissions.contains('rutas.editar');
    final canDelete = isSuperadmin || permissions.contains('rutas.eliminar');

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('Rutas escolares'),
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        centerTitle: true,
        leading: BackToDashboardButton(),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Herramientas de ruta',
            onSelected: (value) =>
                showRouteAdminTools(context, drivers: value == 'drivers'),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'drivers', child: Text('Conductores')),
              if (canEdit)
                const PopupMenuItem(
                  value: 'changes',
                  child: Text('Cambios de parada'),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Historial de recogidas',
            onPressed: () => showRouteHistory(context),
            icon: const Icon(Icons.history),
          ),
          if (canCreate)
            IconButton(
              icon: Icon(Icons.add),
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
              tooltip: 'Crear nueva ruta',
              child: Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadRoutes,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : routes.isEmpty
            ? Center(child: Text('No hay rutas registradas.'))
            : Scrollbar(
                controller: _routesScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _routesScrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: routes.length,
                  separatorBuilder: (context, _) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final route = routes[index];

                    return Semantics(
                      container: true,
                      label:
                          'Ruta ${route.name}. Dirección de inicio: ${route.startAddress}.',
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: colors.surfaceContainerLow,
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            route.name,
                            style: TextStyle(fontWeight: FontWeight.w700),
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
                                    icon: Icon(
                                      Icons.edit,
                                      color: colors.primary,
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
                                    icon: Icon(
                                      Icons.delete,
                                      color: colors.error,
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
