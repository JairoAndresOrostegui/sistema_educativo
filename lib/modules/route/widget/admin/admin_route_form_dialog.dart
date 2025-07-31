import 'package:flutter/material.dart';

import '../../../../services/route/admin_route_service.dart';
import 'admin_route_form_body.dart';
import '../../../../models/route/route_model.dart';

Future<void> mostrarFormularioRuta({
  required BuildContext context,
  RutaModel? rutaModel,
  required VoidCallback onGuardar,
}) async {
  final nombreController = TextEditingController(text: rutaModel?.nombre ?? '');
  final direccionInicioController = TextEditingController(
    text: rutaModel?.direccionInicio ?? '',
  );
  final gestionadorController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  DateTime? fechaInicio = rutaModel?.fechaInicio;
  DateTime? fechaFin = rutaModel?.fechaFin;
  TimeOfDay? horaInicio = rutaModel?.horaInicio;
  TimeOfDay? horaFin = rutaModel?.horaFin;

  final gestionadorId = ValueNotifier<String?>(rutaModel?.gestionador);

  final estudiantesDisponibles =
      await RouteService().obtenerEstudiantesDisponibles();
  final gestionadoresDisponibles =
      await RouteService().obtenerGestionadoresDisponibles();

  if (rutaModel?.gestionador != null) {
    final match =
        gestionadoresDisponibles
            .where((g) => g.id == rutaModel!.gestionador)
            .toList();
    if (match.isNotEmpty) {
      gestionadorController.text =
          '${match.first['nombres']} ${match.first['apellidos']}';
    }
  }

  final estudiantesMapeados =
      (rutaModel?.estudiantes ?? []).map<Map<String, dynamic>>((id) {
        final match = estudiantesDisponibles.where((e) => e.id == id).toList();
        return {
          'id': id,
          'nombre':
              match.isNotEmpty
                  ? '${match.first['nombres']} ${match.first['apellidos']}'
                  : '(Desconocido)',
        };
      }).toList();

  final estudiantesOrdenados = ValueNotifier<List<Map<String, dynamic>>>(
    estudiantesMapeados,
  );

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        title: Center(
          child: Text(
            rutaModel == null ? 'Crear ruta' : 'Editar ruta',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.85,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Expanded(
                    child: AdminRouteFormBody(
                      formKey: formKey,
                      nombreController: nombreController,
                      direccionInicioController: direccionInicioController,
                      gestionadorController: gestionadorController,
                      fechaInicio: fechaInicio,
                      fechaFin: fechaFin,
                      horaInicio: horaInicio,
                      horaFin: horaFin,
                      onFechaInicioChanged:
                          (val) => setState(() => fechaInicio = val),
                      onFechaFinChanged:
                          (val) => setState(() => fechaFin = val),
                      onHoraInicioChanged:
                          (val) => setState(() => horaInicio = val),
                      onHoraFinChanged: (val) => setState(() => horaFin = val),
                      estudiantesOrdenados: estudiantesOrdenados.value,
                      estudiantesDisponibles: estudiantesDisponibles,
                      gestionadoresDisponibles: gestionadoresDisponibles,
                      onAgregarEstudiante:
                          (est) => setState(
                            () => estudiantesOrdenados.value.add(est),
                          ),
                      onReordenarEstudiante: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final est = estudiantesOrdenados.value.removeAt(
                            oldIndex,
                          );
                          estudiantesOrdenados.value.insert(newIndex, est);
                        });
                      },
                      onEliminarEstudiante:
                          (id) => setState(
                            () => estudiantesOrdenados.value.removeWhere(
                              (e) => e['id'] == id,
                            ),
                          ),
                      onSeleccionarGestionador: (doc) {
                        gestionadorId.value = doc.id;
                        gestionadorController.text = doc['nombres'] ?? '';
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    enabled: true,
                    focusable: true,
                    label: 'Guardar ruta',
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final nuevaRuta = RutaModel(
                          id: rutaModel?.id ?? '',
                          nombre: nombreController.text.trim(),
                          direccionInicio:
                              direccionInicioController.text.trim(),
                          fechaInicio: fechaInicio,
                          fechaFin: fechaFin,
                          horaInicio: horaInicio,
                          horaFin: horaFin,
                          gestionador: gestionadorId.value,
                          estudiantes:
                              estudiantesOrdenados.value
                                  .map((e) => e['id'] as String)
                                  .toList(),
                        );

                        try {
                          if (rutaModel == null) {
                            await RouteService().guardarRuta(ruta: nuevaRuta);
                          } else {
                            await RouteService().guardarRuta(
                              id: rutaModel.id,
                              ruta: nuevaRuta,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                          onGuardar();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al guardar la ruta.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
