import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_route_service.dart';
import '../../services/daily_route_service.dart';
import 'admin_route_form_body.dart';
import '../../../../models/route/route_model.dart';
import '../../../../providers/user_provider_v2.dart';
import '../../../../utils/dialog_utils.dart';
import '../../utils/route_ui_helpers.dart';

Future<void> mostrarFormularioRuta({
  required BuildContext context,
  RouteModel? rutaModel,
  required VoidCallback onGuardar,
}) async {
  final session = context.read<UserProviderV2>().user;
  if (session == null) {
    await DialogUtils.showError(
      context: context,
      title: 'Sesión no disponible',
      message: 'Inicia sesión nuevamente antes de administrar rutas.',
    );
    return;
  }
  final institutionId = session.institution;
  final campusId = session.campus;
  final performedBy = session.id;
  final adminName = '${session.firstName} ${session.lastName}'.trim();

  final nameController = TextEditingController(text: rutaModel?.name ?? '');
  final startAddressController = TextEditingController(
    text: rutaModel?.startAddress ?? '',
  );
  final managerController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  DateTime? startDate = rutaModel?.startDate;
  DateTime? endDate = rutaModel?.endDate;
  TimeOfDay? startTime = rutaModel?.startTime;
  TimeOfDay? endTime = rutaModel?.endTime;

  final managerId = ValueNotifier<String?>(rutaModel?.manager);
  String? driverId = rutaModel?.driverId;
  List<Map<String, dynamic>> drivers;
  List<Map<String, dynamic>> students;
  List<Map<String, dynamic>> managers;
  try {
    final driverResult = await RouteOperations.call('gestionarConductores', {});
    final rawDrivers = driverResult['items'];
    drivers = rawDrivers is List
        ? rawDrivers
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .where((d) => d['active'] == true || d['id'] == driverId)
              .toList()
        : [];
    final participants = await RouteService().obtenerParticipantes(
      institutionId: institutionId,
      campusId: campusId,
    );
    students = participants['students'] ?? const [];
    managers = participants['managers'] ?? const [];
  } catch (e) {
    nameController.dispose();
    startAddressController.dispose();
    managerController.dispose();
    managerId.dispose();
    if (context.mounted) {
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo abrir el formulario',
        message: routeErrorMessage(e),
      );
    }
    return;
  }

  if (rutaModel?.manager != null) {
    final match = managers.where((g) => g['id'] == rutaModel!.manager).toList();
    if (match.isNotEmpty) {
      final d = match.first;
      final first = (d['firstName'] ?? '').toString();
      final last = (d['lastName'] ?? '').toString();
      managerController.text = ('$first $last').trim();
    }
  }

  final mapped = (rutaModel?.students ?? []).map<Map<String, dynamic>>((id) {
    final m = students.where((e) => e['id'] == id).toList();
    if (m.isNotEmpty) {
      final d = m.first;
      return {
        'id': id,
        'nombre': '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}',
      };
    }
    return {'id': id, 'nombre': '(Desconocido)'};
  }).toList();

  final orderedStudents = ValueNotifier<List<Map<String, dynamic>>>(mapped);
  var saving = false;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surface,
        contentPadding: EdgeInsets.all(16),
        title: Center(
          child: Text(
            rutaModel == null ? 'Crear ruta' : 'Editar ruta',
            style: TextStyle(color: colors.primary),
          ),
        ),
        content: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    // ⬇️ Solo este envoltorio es el cambio clave
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(bottom: 8),
                        child: AdminRouteFormBody(
                          formKey: formKey,
                          nameController: nameController,
                          startAddressController: startAddressController,
                          managerController: managerController,
                          startDate: startDate,
                          endDate: endDate,
                          startTime: startTime,
                          endTime: endTime,
                          onStartDateChanged: (v) =>
                              setState(() => startDate = v),
                          onEndDateChanged: (v) => setState(() => endDate = v),
                          onStartTimeChanged: (v) =>
                              setState(() => startTime = v),
                          onEndTimeChanged: (v) => setState(() => endTime = v),
                          orderedStudents: orderedStudents.value,
                          availableStudents: students,
                          availableManagers: managers,
                          onAddStudent: (st) =>
                              setState(() => orderedStudents.value.add(st)),
                          onReorderStudent: (oldIndex, newIndex) {
                            setState(() {
                              final st = orderedStudents.value.removeAt(
                                oldIndex,
                              );
                              orderedStudents.value.insert(newIndex, st);
                            });
                          },
                          onRemoveStudent: (id) => setState(
                            () => orderedStudents.value.removeWhere(
                              (e) => e['id'] == id,
                            ),
                          ),
                          onSelectManager: (doc) {
                            managerId.value = doc['id'] as String?;
                            final d = doc;
                            final first = (d['firstName'] ?? '').toString();
                            final last = (d['lastName'] ?? '').toString();
                            managerController.text = ('$first $last').trim();
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: driverId,
                      decoration: const InputDecoration(
                        labelText: 'Conductor (hoja de vida sin usuario)',
                      ),
                      items: drivers
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: routeText(d['id']),
                              child: Text(
                                routeText(
                                  d['name'],
                                  fallback: 'Conductor sin nombre',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) => setState(() => driverId = id),
                    ),
                    // Botón dentro de SafeArea inferior para que no lo tape el sistema
                    SafeArea(
                      top: false,
                      child: Semantics(
                        button: true,
                        label: 'Guardar ruta',
                        child: ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (managerId.value == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Selecciona el responsable desde la lista.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (startDate == null ||
                                      endDate == null ||
                                      startTime == null ||
                                      endTime == null ||
                                      orderedStudents.value.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Completa fechas, horarios y estudiantes.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final startMinutes =
                                      startTime!.hour * 60 + startTime!.minute;
                                  final endMinutes =
                                      endTime!.hour * 60 + endTime!.minute;
                                  if (endDate!.isBefore(startDate!) ||
                                      endMinutes <= startMinutes) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'La fecha y la hora finales deben ser posteriores a las iniciales.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => saving = true);

                                  final newRoute = RouteModel(
                                    id: rutaModel?.id ?? '',
                                    name: nameController.text.trim(),
                                    startAddress: startAddressController.text
                                        .trim(),
                                    startDate: startDate,
                                    endDate: endDate,
                                    startTime: startTime,
                                    endTime: endTime,
                                    manager: managerId.value,
                                    driverId: driverId,
                                    students: orderedStudents.value
                                        .map((e) => e['id'] as String)
                                        .toList(),
                                    revision: rutaModel?.revision ?? 0,
                                  );

                                  try {
                                    if (rutaModel == null) {
                                      await RouteService().guardarRuta(
                                        ruta: newRoute,
                                        performedBy: performedBy,
                                        adminName: adminName,
                                        institutionId: institutionId,
                                        campusId: campusId,
                                      );
                                    } else {
                                      await RouteService().guardarRuta(
                                        id: rutaModel.id,
                                        ruta: newRoute,
                                        performedBy: performedBy,
                                        adminName: adminName,
                                        institutionId: institutionId,
                                        campusId: campusId,
                                      );
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                    onGuardar();
                                  } catch (e) {
                                    if (context.mounted) {
                                      setState(() => saving = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            routeErrorMessage(
                                              e,
                                              fallback:
                                                  'No fue posible guardar la ruta.',
                                            ),
                                          ),
                                          backgroundColor: colors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: Icon(Icons.save),
                          label: Text('Guardar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
  nameController.dispose();
  startAddressController.dispose();
  managerController.dispose();
  managerId.dispose();
  orderedStudents.dispose();
}
