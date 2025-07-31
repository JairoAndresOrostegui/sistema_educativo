import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteRutaDiaria {
  final String id;
  final String nombre;
  final String direccion;
  final bool activo;
  final bool recogido;
  final Timestamp? horaRecogida;
  final bool avisoEnviado;
  final bool anulado;
  final int? orden;
  final int avisosEnviados;

  EstudianteRutaDiaria({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.activo,
    required this.recogido,
    this.horaRecogida,
    required this.avisoEnviado,
    required this.anulado,
    this.orden,
    required this.avisosEnviados,
  });

  factory EstudianteRutaDiaria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EstudianteRutaDiaria(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      direccion: data['direccion'] ?? '',
      activo: data['activo'] ?? false,
      recogido: data['recogido'] ?? false,
      horaRecogida: data['horaRecogida'] as Timestamp?,
      avisoEnviado: data['avisoEnviado'] ?? false,
      anulado: data['anulado'] ?? false,
      orden: data['orden'] ?? 0,
      avisosEnviados: data['avisosEnviados'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      'activo': activo,
      'recogido': recogido,
      'horaRecogida': horaRecogida,
      'avisoEnviado': avisoEnviado,
      'anulado': anulado,
      'orden': orden,
      'avisosEnviados': avisosEnviados,
    };
  }

  EstudianteRutaDiaria copyWith({
    String? id,
    String? nombre,
    String? direccion,
    bool? activo,
    bool? recogido,
    Timestamp? horaRecogida,
    bool? avisoEnviado,
    bool? anulado,
    int? orden,
    int? avisosEnviados,
  }) {
    return EstudianteRutaDiaria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      activo: activo ?? this.activo,
      recogido: recogido ?? this.recogido,
      horaRecogida: horaRecogida ?? this.horaRecogida,
      avisoEnviado: avisoEnviado ?? this.avisoEnviado,
      anulado: anulado ?? this.anulado,
      orden: orden ?? this.orden,
      avisosEnviados: avisosEnviados ?? this.avisosEnviados,
    );
  }
}
