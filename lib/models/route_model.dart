import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

class RutaModel {
  final String id;
  final String nombre;
  final String direccionInicio;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final TimeOfDay? horaInicio;
  final TimeOfDay? horaFin;
  final String? gestionador;
  final List<String> estudiantes;

  RutaModel({
    required this.id,
    required this.nombre,
    required this.direccionInicio,
    this.fechaInicio,
    this.fechaFin,
    this.horaInicio,
    this.horaFin,
    this.gestionador,
    required this.estudiantes,
  });

  factory RutaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return RutaModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      direccionInicio: data['direccionInicio'] ?? '',
      fechaInicio: FormatUtils.dateTimeDesdeTimestamp(data['fechaInicio']),
      fechaFin: FormatUtils.dateTimeDesdeTimestamp(data['fechaFin']),
      horaInicio: FormatUtils.timeOfDayDesdeTimestamp(data['horaInicio']),
      horaFin: FormatUtils.timeOfDayDesdeTimestamp(data['horaFin']),
      gestionador: data['gestionador'],
      estudiantes: List<String>.from(data['estudiantes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'direccionInicio': direccionInicio,
      'fechaInicio': FormatUtils.timestampDesdeDateTime(fechaInicio),
      'fechaFin': FormatUtils.timestampDesdeDateTime(fechaFin),
      'horaInicio': FormatUtils.timestampDesdeHora(horaInicio),
      'horaFin': FormatUtils.timestampDesdeHora(horaFin),
      'gestionador': gestionador,
      'estudiantes': estudiantes,
    };
  }
}
