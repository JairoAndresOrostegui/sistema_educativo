import 'package:cloud_firestore/cloud_firestore.dart';

class ArchivoModel {
  final String id;
  final String nombre;
  final String url;
  final String grado;
  final String subidoPor;
  final String nombreSubidor;
  final Timestamp fecha;

  ArchivoModel({
    required this.id,
    required this.nombre,
    required this.url,
    required this.grado,
    required this.subidoPor,
    required this.nombreSubidor,
    required this.fecha,
  });

  factory ArchivoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArchivoModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      url: data['url'] ?? '',
      grado: data['grado'] ?? '',
      subidoPor: data['subidoPor'] ?? '',
      nombreSubidor: data['nombreSubidor'] ?? '',
      fecha: data['fecha'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'url': url,
      'grado': grado,
      'subidoPor': subidoPor,
      'nombreSubidor': nombreSubidor,
      'fecha': fecha,
    };
  }
}
