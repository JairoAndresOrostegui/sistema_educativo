import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteRutaDiaria {
  final String id;

  // Propiedades (con nombres en español para no romper UI actual)
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

  // Lee EN primero; si no, ES (backward-compat)
  factory EstudianteRutaDiaria.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});

    String _str(List<String> ks, [String def = '']) {
      for (final k in ks) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return def;
    }

    bool _bool(List<String> ks, [bool def = false]) {
      for (final k in ks) {
        final v = data[k];
        if (v is bool) return v;
      }
      return def;
    }

    int _int(List<String> ks, [int def = 0]) {
      for (final k in ks) {
        final v = data[k];
        if (v is int) return v;
      }
      return def;
    }

    Timestamp? _ts(List<String> ks) {
      for (final k in ks) {
        final v = data[k];
        if (v is Timestamp) return v;
      }
      return null;
    }

    return EstudianteRutaDiaria(
      id: doc.id,
      nombre: _str(['name', 'nombre']),
      direccion: _str(['address', 'direccion']),
      activo: _bool(['active', 'activo']),
      recogido: _bool(['picked', 'recogido']),
      horaRecogida: _ts(['pickupTime', 'horaRecogida']),
      avisoEnviado: _bool(['arrivalNotified', 'avisoEnviado']),
      anulado: _bool(['canceled', 'anulado']),
      orden: _int(['order', 'orden'], 0),
      avisosEnviados: _int(['arrivalNotices', 'avisosEnviados'], 0),
    );
  }

  // Escribe SOLO en inglés (DB unificada)
  Map<String, dynamic> toFirestore() {
    return {
      'name': nombre,
      'address': direccion,
      'active': activo,
      'picked': recogido,
      'pickupTime': horaRecogida,
      'arrivalNotified': avisoEnviado,
      'canceled': anulado,
      'order': orden,
      'arrivalNotices': avisosEnviados,
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
