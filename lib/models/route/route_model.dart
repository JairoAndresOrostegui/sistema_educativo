import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/format_utils.dart';

class RouteModel {
  final String id;
  final String name;
  final String startAddress;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? manager;
  final String? driverId;
  final List<String> students;
  final int revision;

  const RouteModel({
    required this.id,
    required this.name,
    required this.startAddress,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.manager,
    this.driverId,
    required this.students,
    this.revision = 0,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    String text(String key) => data[key] is String ? data[key] as String : '';
    final rawStudents = data['estudiantes'];
    return RouteModel(
      id: doc.id,
      name: text('nombre'),
      startAddress: text('direccionInicio'),
      startDate: FormatUtils.dateTimeDesdeTimestamp(data['fechaInicio']),
      endDate: FormatUtils.dateTimeDesdeTimestamp(data['fechaFin']),
      startTime: FormatUtils.timeOfDayDesdeTimestamp(data['horaInicio']),
      endTime: FormatUtils.timeOfDayDesdeTimestamp(data['horaFin']),
      manager: data['gestionador'] is String
          ? data['gestionador'] as String
          : null,
      driverId: data['driverId'] is String ? data['driverId'] as String : null,
      students: rawStudents is List
          ? rawStudents.whereType<String>().toList(growable: false)
          : const [],
      revision: (data['revision'] as num?)?.toInt() ?? 0,
    );
  }

  RouteModel copyWithId(String newId) {
    return RouteModel(
      id: newId,
      name: name,
      startAddress: startAddress,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      manager: manager,
      driverId: driverId,
      students: students,
      revision: revision,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'direccionInicio': startAddress,
      'fechaInicio': FormatUtils.timestampDesdeDateTime(startDate),
      'fechaFin': FormatUtils.timestampDesdeDateTime(endDate),
      'horaInicio': FormatUtils.timestampDesdeHora(startTime),
      'horaFin': FormatUtils.timestampDesdeHora(endTime),
      'gestionador': manager,
      'driverId': driverId,
      'estudiantes': students,
    };
  }
}
