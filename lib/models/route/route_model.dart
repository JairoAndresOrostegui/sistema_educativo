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
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RouteModel(
      id: doc.id,
      name: data['nombre'] ?? '',
      startAddress: data['direccionInicio'] ?? '',
      startDate: FormatUtils.dateTimeDesdeTimestamp(data['fechaInicio']),
      endDate: FormatUtils.dateTimeDesdeTimestamp(data['fechaFin']),
      startTime: FormatUtils.timeOfDayDesdeTimestamp(data['horaInicio']),
      endTime: FormatUtils.timeOfDayDesdeTimestamp(data['horaFin']),
      manager: data['gestionador'],
      driverId: data['driverId'],
      students: List<String>.from(data['estudiantes'] ?? []),
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
