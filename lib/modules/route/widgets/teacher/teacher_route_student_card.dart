import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';

import '../../../../models/route/student_route_model.dart';
import 'teacher_route_form_dialog.dart';

class TeacherRouteStudentCard extends StatelessWidget {
  final EstudianteRutaDiaria student;
  final bool rutaPendiente;
  final bool rutaActiva;
  final String addressValue;
  final ValueChanged<String> onAddressDraftChanged;
  final ValueChanged<String> onAddressSubmit;
  final ValueChanged<bool?> onActiveChanged;
  final VoidCallback onToggleRecogido;
  final VoidCallback onSendArrival;
  final VoidCallback onToggleAnulado;
  final bool showDivider;

  const TeacherRouteStudentCard({
    super.key,
    required this.student,
    required this.rutaPendiente,
    required this.rutaActiva,
    required this.addressValue,
    required this.onAddressDraftChanged,
    required this.onAddressSubmit,
    required this.onActiveChanged,
    required this.onToggleRecogido,
    required this.onSendArrival,
    required this.onToggleAnulado,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final recogido = student.recogido;
    final esActivo = student.activo;
    final esAnulado = student.anulado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(student.nombre, style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        TextFormField(
          enabled: rutaPendiente,
          initialValue: addressValue,
          onChanged: onAddressDraftChanged,
          onFieldSubmitted: onAddressSubmit,
          decoration: InputDecoration(
            labelText: 'Direccion',
            border: OutlineInputBorder(),
            suffixIcon: rutaPendiente
                ? IconButton(
                    tooltip: 'Guardar direccion',
                    icon: Icon(Icons.save),
                    onPressed: () => onAddressSubmit(addressValue),
                  )
                : null,
          ),
        ),
        Row(
          children: [
            Checkbox(
              value: esActivo,
              onChanged: rutaPendiente ? onActiveChanged : null,
            ),
            Text('Activo hoy'),
          ],
        ),
        if (rutaActiva) ...[
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  recogido ? Icons.check_circle : Icons.directions_bus,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: recogido
                      ? AppPalette.success
                      : Theme.of(context).primaryColor,
                  foregroundColor: AppPalette.surface,
                ),
                onPressed: esAnulado ? null : onToggleRecogido,
                label: Text(recogido ? 'Recogido' : 'Marcar como recogido'),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.notification_important),
                label: Text('Aviso de llegada'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: student.avisoEnviado
                      ? AppPalette.success
                      : AppPalette.warning,
                  foregroundColor: AppPalette.surface,
                ),
                onPressed: () async {
                  final confirm = await DialogUtils.showConfirmationDialog(
                    context,
                    title: 'Enviar aviso de llegada',
                    content: student.avisoEnviado
                        ? 'Ya se ha enviado un aviso anteriormente.\n¿Deseas reenviarlo?'
                        : '¿Deseas enviar el aviso de llegada a este estudiante?',
                  );
                  if (confirm == true) {
                    onSendArrival();
                  }
                },
              ),
              ElevatedButton.icon(
                icon: Icon(esAnulado ? Icons.block : Icons.cancel),
                label: Text(esAnulado ? 'Anulado' : 'Anular'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: esAnulado
                      ? AppPalette.error
                      : AppPalette.warning,
                  foregroundColor: AppPalette.surface,
                ),
                onPressed: recogido ? null : onToggleAnulado,
              ),
            ],
          ),
        ],
        if (showDivider) ...[
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
        ],
      ],
    );
  }
}
