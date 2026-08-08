import 'package:cloud_firestore/cloud_firestore.dart';

class ParameterEntry {
  final String id;
  final String clave;
  final String etiqueta;
  final String valor;
  final int orden;
  final bool activo;

  const ParameterEntry({
    required this.id,
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.orden,
    required this.activo,
  });

  factory ParameterEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ParameterEntry(
      id: doc.id,
      clave: (data['clave'] ?? '').toString(),
      etiqueta: (data['etiqueta'] ?? '').toString(),
      valor: (data['valor'] ?? '').toString(),
      orden: data['orden'] is int
          ? data['orden'] as int
          : int.tryParse('${data['orden']}') ?? 0,
      activo: data['activo'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clave': clave,
      'etiqueta': etiqueta,
      'valor': valor,
      'orden': orden,
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
