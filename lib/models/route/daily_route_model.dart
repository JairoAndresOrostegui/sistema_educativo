import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoRuta { pendiente, activa, finalizada }

extension EstadoRutaExtension on String {
  EstadoRuta toEstadoRuta() {
    switch (this) {
      case 'activa':
        return EstadoRuta.activa;
      case 'finalizada':
        return EstadoRuta.finalizada;
      case 'pendiente':
      default:
        return EstadoRuta.pendiente;
    }
  }
}

class RutaDiaria {
  final String id;
  final String idRuta;
  final String nombreRuta;
  final Timestamp fecha;
  final String gestionador;
  final String gestionadaPorNombre;
  final EstadoRuta estado;
  final Timestamp? horaInicio;
  final Timestamp? horaFin;
  final Map<String, dynamic>? posicionDocente;

  RutaDiaria({
    required this.id,
    required this.idRuta,
    required this.nombreRuta,
    required this.fecha,
    required this.gestionador,
    required this.gestionadaPorNombre,
    required this.estado,
    this.horaInicio,
    this.horaFin,
    this.posicionDocente,
  });

  factory RutaDiaria.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RutaDiaria(
      id: doc.id,
      idRuta: data['idRuta'] ?? '',
      nombreRuta: data['nombreRuta'] ?? '',
      fecha: data['fecha'] ?? Timestamp.now(),
      gestionador: data['gestionador'] ?? '',
      gestionadaPorNombre: data['gestionadaPorNombre'] ?? '',
      estado: (data['estado'] as String? ?? 'pendiente').toEstadoRuta(),
      horaInicio: data['horaInicio'] as Timestamp?,
      horaFin: data['horaFin'] as Timestamp?,
      posicionDocente: data['posicionDocente'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'idRuta': idRuta,
      'nombreRuta': nombreRuta,
      'fecha': fecha,
      'gestionador': gestionador,
      'gestionadaPorNombre': gestionadaPorNombre,
      'estado': estado.name,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'posicionDocente': posicionDocente,
    };
  }

  RutaDiaria copyWith({
    String? id,
    String? idRuta,
    String? nombreRuta,
    Timestamp? fecha,
    String? gestionador,
    String? gestionadaPorNombre,
    EstadoRuta? estado,
    Timestamp? horaInicio,
    Timestamp? horaFin,
    Map<String, dynamic>? posicionDocente,
  }) {
    return RutaDiaria(
      id: id ?? this.id,
      idRuta: idRuta ?? this.idRuta,
      nombreRuta: nombreRuta ?? this.nombreRuta,
      fecha: fecha ?? this.fecha,
      gestionador: gestionador ?? this.gestionador,
      gestionadaPorNombre: gestionadaPorNombre ?? this.gestionadaPorNombre,
      estado: estado ?? this.estado,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      posicionDocente: posicionDocente ?? this.posicionDocente,
    );
  }
}
