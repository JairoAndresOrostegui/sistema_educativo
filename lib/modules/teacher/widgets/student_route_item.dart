import 'package:flutter/material.dart';
import '../../../models/daily_route_model.dart';
import '../../../models/student_route_model.dart';
import 'teacher_route_form_dialog.dart';

class EstudianteRutaItem extends StatefulWidget {
  final EstudianteRutaDiaria estudiante;
  final EstadoRuta estadoRuta;
  final Function(String, Map<String, dynamic>) onUpdateEstudiante;
  final Function(String, String) onUpdateStudentAddress;
  final Function(EstudianteRutaDiaria) onToggleRecogido;
  final Function(EstudianteRutaDiaria) onSendArrivalNotice;
  final Function(EstudianteRutaDiaria) onToggleAnulado;

  const EstudianteRutaItem({
    super.key,
    required this.estudiante,
    required this.estadoRuta,
    required this.onUpdateEstudiante,
    required this.onUpdateStudentAddress,
    required this.onToggleRecogido,
    required this.onSendArrivalNotice,
    required this.onToggleAnulado,
  });

  @override
  State<EstudianteRutaItem> createState() => _EstudianteRutaItemState();
}

class _EstudianteRutaItemState extends State<EstudianteRutaItem> {
  late TextEditingController _direccionController;

  @override
  void initState() {
    super.initState();
    _direccionController = TextEditingController(
      text: widget.estudiante.direccion,
    );
  }

  @override
  void didUpdateWidget(covariant EstudianteRutaItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.estudiante.direccion != oldWidget.estudiante.direccion) {
      _direccionController.text = widget.estudiante.direccion;
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool recogido = widget.estudiante.recogido;
    final bool esActivo = widget.estudiante.activo;
    final bool esAnulado = widget.estudiante.anulado;
    final bool rutaPendiente = widget.estadoRuta == EstadoRuta.pendiente;
    final bool rutaActiva = widget.estadoRuta == EstadoRuta.activa;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.estudiante.nombre,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: rutaPendiente,
              controller: _direccionController,
              decoration: InputDecoration(
                labelText: 'Dirección',
                border: const OutlineInputBorder(),
                suffixIcon:
                    rutaPendiente
                        ? IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: () {
                            widget.onUpdateStudentAddress(
                              widget.estudiante.id,
                              _direccionController.text,
                            );
                          },
                        )
                        : null,
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: esActivo,
                  onChanged:
                      rutaPendiente
                          ? (val) => widget.onUpdateEstudiante(
                            widget.estudiante.id,
                            {'activo': val},
                          )
                          : null,
                ),
                const Text('Activo hoy'),
              ],
            ),
            if (rutaActiva)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Botón de "Recogido"
                      ElevatedButton.icon(
                        icon: Icon(
                          recogido ? Icons.check_circle : Icons.directions_bus,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              recogido
                                  ? Colors.green
                                  : Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            esAnulado
                                ? null
                                : () =>
                                    widget.onToggleRecogido(widget.estudiante),
                        label: Text(
                          recogido ? 'Recogido' : 'Marcar como recogido',
                        ),
                      ),

                      // Botón de "Aviso de llegada"
                      ElevatedButton.icon(
                        icon: const Icon(Icons.notification_important),
                        label: const Text('Aviso de llegada'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              widget.estudiante.avisoEnviado
                                  ? Colors.green
                                  : Colors.amber,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final confirm = await DialogUtils.showConfirmationDialog(
                            context,
                            title: 'Enviar aviso de llegada',
                            content:
                                widget.estudiante.avisoEnviado
                                    ? 'Ya se ha enviado un aviso de llegada anteriormente.\n¿Deseas reenviarlo?'
                                    : '¿Deseas enviar el aviso de llegada a este estudiante?',
                          );
                          if (confirm == true) {
                            widget.onSendArrivalNotice(widget.estudiante);
                          }
                        },
                      ),

                      // Botón de "Anular"
                      ElevatedButton.icon(
                        icon: Icon(esAnulado ? Icons.block : Icons.cancel),
                        label: Text(esAnulado ? 'Anulado' : 'Anular'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              esAnulado ? Colors.red : Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            recogido
                                ? null
                                : () =>
                                    widget.onToggleAnulado(widget.estudiante),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
