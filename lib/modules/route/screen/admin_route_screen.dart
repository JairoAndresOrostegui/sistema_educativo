import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/route/admin_route_service.dart';
import '../widget/admin/admin_route_form_dialog.dart';
import '../../../models/route/route_model.dart';
import '../../../models/user/user_model.dart';
import '../../../utils/snackbar_utils.dart';

class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  List<RutaModel> rutas = [];
  bool isLoading = true;
  bool esSuperadminActual = false;
  List<String> funcionalidadesActual = [];

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
    _cargarRutas();
  }

  Future<void> _verificarPermisos() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(currentUid)
            .get();
    if (!doc.exists) return;
    final user = UsuarioModel.fromFirestore(doc.data()!, doc.id);
    esSuperadminActual = user.esSuperadmin;
    funcionalidadesActual = user.funcionalidades;
    setState(() {});
  }

  Future<void> _cargarRutas() async {
    setState(() => isLoading = true);
    rutas = await RouteService().obtenerTodasLasRutas();
    setState(() => isLoading = false);
  }

  Future<void> _eliminarRuta(RutaModel ruta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar ruta?'),
            content: const Text('Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      try {
        await RouteService().eliminarRuta(ruta.id);
        _cargarRutas();
        if (mounted) mostrarSnack(context, 'Ruta eliminada correctamente');
      } catch (e) {
        if (mounted) mostrarSnack(context, 'Error al eliminar la ruta');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('School route management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          if (esSuperadminActual ||
              funcionalidadesActual.contains('rutas.crear'))
            IconButton(
              icon: const Icon(Icons.add),
              onPressed:
                  () => mostrarFormularioRuta(
                    context: context,
                    onGuardar: _cargarRutas,
                  ),
            ),
        ],
      ),
      floatingActionButton:
          (esSuperadminActual || funcionalidadesActual.contains('rutas.crear'))
              ? FloatingActionButton(
                onPressed:
                    () => mostrarFormularioRuta(
                      context: context,
                      onGuardar: _cargarRutas,
                    ),
                child: const Icon(Icons.add),
                tooltip: 'Crear nueva ruta',
              )
              : null,
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : rutas.isEmpty
              ? const Center(child: Text('No hay rutas registradas.'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rutas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ruta = rutas[index];
                  final nombre = ruta.nombre;
                  final direccion = ruta.direccionInicio;

                  final puedeEditar =
                      esSuperadminActual ||
                      funcionalidadesActual.contains('rutas.editar');
                  final puedeEliminar =
                      esSuperadminActual ||
                      funcionalidadesActual.contains('rutas.eliminar');

                  return Card(
                    elevation: 3,
                    child: ListTile(
                      title: Text(nombre),
                      subtitle: Text(direccion),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (puedeEditar)
                            Semantics(
                              button: true,
                              label: 'Editar ruta $nombre',
                              enabled: true,
                              focusable: true,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed:
                                    () => mostrarFormularioRuta(
                                      context: context,
                                      rutaModel: ruta,
                                      onGuardar: _cargarRutas,
                                    ),
                                tooltip: 'Editar ruta',
                              ),
                            ),
                          if (puedeEliminar)
                            Semantics(
                              button: true,
                              label: 'Eliminar ruta $nombre',
                              enabled: true,
                              focusable: true,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _eliminarRuta(ruta),
                                tooltip: 'Eliminar ruta',
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
