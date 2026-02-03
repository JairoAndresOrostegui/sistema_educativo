import 'package:cloud_firestore/cloud_firestore.dart';

class Enrollment {
  final String id;
  final String estado; // prematriculado | pendiente_revision | rechazado | matriculado
  final String createdByRole; // admin | padre | publico
  final String? createdByUserId;
  final String? token; // para links públicos opcionales
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fuente; // admin/padre/qr/app
  final String? vinculaUsuarioId; // usuario ya existente si aplica
  final int? anioMatricula;
  final DateTime? fechaDiligenciamiento;
  final String? revisadoPor; // uid admin que aprobó/rechazó
  final String? rechazoMotivo;

  Enrollment({
    required this.id,
    required this.estado,
    required this.createdByRole,
    required this.createdByUserId,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.token,
    this.fuente,
    this.vinculaUsuarioId,
    this.anioMatricula,
    this.fechaDiligenciamiento,
    this.revisadoPor,
    this.rechazoMotivo,
  });

  factory Enrollment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Enrollment(
      id: doc.id,
      estado: (data['estado'] ?? 'prematriculado').toString(),
      createdByRole: (data['createdByRole'] ?? '').toString(),
      createdByUserId: data['createdByUserId'] as String?,
      token: data['token'] as String?,
      fuente: data['fuente'] as String?,
      vinculaUsuarioId: data['vinculaUsuarioId'] as String?,
      anioMatricula: data['anioMatricula'] is int ? data['anioMatricula'] as int : null,
      fechaDiligenciamiento: (data['fechaDiligenciamiento'] as Timestamp?)?.toDate(),
      revisadoPor: data['revisadoPor'] as String?,
      rechazoMotivo: data['rechazoMotivo'] as String?,
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
