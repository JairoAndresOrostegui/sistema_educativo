import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';

import '../../../../models/route/student_route_model.dart';
import 'teacher_route_student_card.dart';

class TeacherRouteStudentList extends StatelessWidget {
  final bool groupSameAddress;
  final List<List<EstudianteRutaDiaria>> groups;
  final List<EstudianteRutaDiaria> students;
  final ScrollController controller;
  final bool rutaPendiente;
  final bool rutaActiva;
  final String Function(EstudianteRutaDiaria) addressForStudent;
  final void Function(String studentId, String value) onAddressDraftChanged;
  final void Function(String studentId, String value) onAddressSubmit;
  final void Function(String studentId, bool? value) onActiveChanged;
  final void Function(EstudianteRutaDiaria student) onToggleRecogido;
  final void Function(EstudianteRutaDiaria student) onSendArrival;
  final void Function(EstudianteRutaDiaria student) onToggleAnulado;

  const TeacherRouteStudentList({
    super.key,
    required this.groupSameAddress,
    required this.groups,
    required this.students,
    required this.controller,
    required this.rutaPendiente,
    required this.rutaActiva,
    required this.addressForStudent,
    required this.onAddressDraftChanged,
    required this.onAddressSubmit,
    required this.onActiveChanged,
    required this.onToggleRecogido,
    required this.onSendArrival,
    required this.onToggleAnulado,
  });

  @override
  Widget build(BuildContext context) {
    if (groupSameAddress) {
      return ListView.builder(
        controller: controller,
        itemCount: groups.length,
        itemBuilder: (_, gi) {
          final group = groups[gi];
          final addr = group.first.direccion.trim();

          return Container(
            margin: EdgeInsets.symmetric(vertical: 8.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.error.withValues(alpha: .15),
              ),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppPalette.error.withValues(alpha: .06),
                  AppPalette.surface,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.onSurface.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (addr.isNotEmpty) ...[
                  Text(
                    addr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.onSurface.withValues(alpha: .87),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
                ...List.generate(group.length, (i) {
                  final s = group[i];
                  return TeacherRouteStudentCard(
                    student: s,
                    rutaPendiente: rutaPendiente,
                    rutaActiva: rutaActiva,
                    addressValue: addressForStudent(s),
                    onAddressDraftChanged: (v) =>
                        onAddressDraftChanged(s.id, v),
                    onAddressSubmit: (v) => onAddressSubmit(s.id, v),
                    onActiveChanged: (val) => onActiveChanged(s.id, val),
                    onToggleRecogido: () => onToggleRecogido(s),
                    onSendArrival: () => onSendArrival(s),
                    onToggleAnulado: () => onToggleAnulado(s),
                    showDivider: i != group.length - 1,
                  );
                }),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: students.length,
      itemBuilder: (_, i) {
        final s = students[i];
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8.0),
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.error.withValues(alpha: .15)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppPalette.error.withValues(alpha: .06),
                AppPalette.surface,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.onSurface.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TeacherRouteStudentCard(
            student: s,
            rutaPendiente: rutaPendiente,
            rutaActiva: rutaActiva,
            addressValue: addressForStudent(s),
            onAddressDraftChanged: (v) => onAddressDraftChanged(s.id, v),
            onAddressSubmit: (v) => onAddressSubmit(s.id, v),
            onActiveChanged: (val) => onActiveChanged(s.id, val),
            onToggleRecogido: () => onToggleRecogido(s),
            onSendArrival: () => onSendArrival(s),
            onToggleAnulado: () => onToggleAnulado(s),
          ),
        );
      },
    );
  }
}
