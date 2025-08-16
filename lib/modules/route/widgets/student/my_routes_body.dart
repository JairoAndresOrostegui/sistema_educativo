import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_route_service.dart';
import '../../../../models/route/route_model.dart';
import '../../../../providers/user_provider_V2.dart';
import '../admin/admin_route_form_body.dart';

Future<void> mostrarFormularioRuta({
  required BuildContext context,
  RouteModel? rutaModel,
  required VoidCallback onGuardar,
}) async {
  final session = context.read<UserProviderV2>().user!;
  final institutionId = session.institution;
  final campusId = session.campus;

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

  // 🔒 SIEMPRE filtra por institution/campus
  final students = await RouteService().obtenerEstudiantesDisponibles(
    institutionId: institutionId,
    campusId: campusId,
  );
  final managers = await RouteService().obtenerGestionadoresDisponibles(
    institutionId: institutionId,
    campusId: campusId,
  );

  if (rutaModel?.manager != null) {
    final match = managers.where((g) => g.id == rutaModel!.manager).toList();
    if (match.isNotEmpty) {
      final d = match.first.data() ?? {};
      final first = (d['firstName'] ?? '').toString();
      final last = (d['lastName'] ?? '').toString();
      managerController.text = ('$first $last').trim();
    }
  }

  final mapped =
      (rutaModel?.students ?? []).map<Map<String, dynamic>>((id) {
        final m = students.where((e) => e.id == id).toList();
        if (m.isNotEmpty) {
          final d = m.first.data() ?? {};
          return {
            'id': id,
            'nombre': '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}',
          };
        }
        return {'id': id, 'nombre': '(Desconocido)'};
      }).toList();

  final orderedStudents = ValueNotifier<List<Map<String, dynamic>>>(mapped);

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
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AdminRouteFormBody(
                          formKey: formKey,
                          nameController: nameController,
                          startAddressController: startAddressController,
                          managerController: managerController,
                          startDate: startDate,
                          endDate: endDate,
                          startTime: startTime,
                          endTime: endTime,
                          onStartDateChanged:
                              (v) => setState(() => startDate = v),
                          onEndDateChanged: (v) => setState(() => endDate = v),
                          onStartTimeChanged:
                              (v) => setState(() => startTime = v),
                          onEndTimeChanged: (v) => setState(() => endTime = v),
                          orderedStudents: orderedStudents.value,
                          availableStudents: students,
                          availableManagers: managers,
                          onAddStudent:
                              (st) =>
                                  setState(() => orderedStudents.value.add(st)),
                          onReorderStudent: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final st = orderedStudents.value.removeAt(
                                oldIndex,
                              );
                              orderedStudents.value.insert(newIndex, st);
                            });
                          },
                          onRemoveStudent:
                              (id) => setState(
                                () => orderedStudents.value.removeWhere(
                                  (e) => e['id'] == id,
                                ),
                              ),
                          onSelectManager: (doc) {
                            managerId.value = doc.id;
                            final d = doc.data() ?? {};
                            final first = (d['firstName'] ?? '').toString();
                            final last = (d['lastName'] ?? '').toString();
                            managerController.text = ('$first $last').trim();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SafeArea(
                      top: false,
                      child: Semantics(
                        button: true,
                        label: 'Guardar ruta',
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final newRoute = RouteModel(
                              id: rutaModel?.id ?? '',
                              name: nameController.text.trim(),
                              startAddress: startAddressController.text.trim(),
                              startDate: startDate,
                              endDate: endDate,
                              startTime: startTime,
                              endTime: endTime,
                              manager: managerId.value,
                              students:
                                  orderedStudents.value
                                      .map((e) => e['id'] as String)
                                      .toList(),
                            );

                            try {
                              final performedBy = session.id;
                              final adminName =
                                  '${session.firstName} ${session.lastName}'
                                      .trim();

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
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error al guardar la ruta.'),
                                    backgroundColor: Colors.redAccent,
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
}
