import 'package:cloud_firestore/cloud_firestore.dart';

class MateriaModel {
  final String materia;
  final Timestamp horaInicio;
  final Timestamp horaFin;
  final String docenteId;

  MateriaModel({
    required this.materia,
    required this.horaInicio,
    required this.horaFin,
    required this.docenteId,
  });

  factory MateriaModel.fromMap(Map<String, dynamic> data) {
    return MateriaModel(
      materia: data['materia'],
      horaInicio: data['horaInicio'] is Timestamp
          ? data['horaInicio']
          : Timestamp.fromDate(DateTime.parse(data['horaInicio'])),
      horaFin: data['horaFin'] is Timestamp
          ? data['horaFin']
          : Timestamp.fromDate(DateTime.parse(data['horaFin'])),
      docenteId: data['docenteId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'materia': materia,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'docenteId': docenteId,
    };
  }
}
