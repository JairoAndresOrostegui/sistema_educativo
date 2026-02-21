import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user/user_model_v2.dart';

class Parameter {
  final String etiqueta;
  final String valor;
  final int orden;

  Parameter({required this.etiqueta, required this.valor, required this.orden});
}

class ParametersService {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Parameter>> getDocumentTypes() async {
    final snapshot =
        await _firestore
            .collection('parameters')
            .where('clave', isEqualTo: 'documentType')
            .where('activo', isEqualTo: true)
            .get();

    final parameters =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Parameter(
            etiqueta: data['etiqueta'],
            valor: data['valor'],
            orden: data['orden'],
          );
        }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<List<Parameter>> getRoles() async {
    final snapshot =
        await _firestore
            .collection('parameters')
            .where('clave', isEqualTo: 'role')
            .where('activo', isEqualTo: true)
            .get();

    final parameters =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Parameter(
            etiqueta: data['valor'],
            valor: data['valor'],
            orden: data['orden'],
          );
        }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));
    return parameters;
  }

  Future<List<Parameter>> getGrades() async {
    final snapshot =
        await _firestore
            .collection('parameters')
            .where('clave', isEqualTo: 'grade')
            .where('activo', isEqualTo: true)
            .get();

    final parameters =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Parameter(
            etiqueta: data['etiqueta'],
            valor: data['valor'],
            orden: data['orden'],
          );
        }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<List<Parameter>> getEps() async {
    final snapshot =
        await _firestore
            .collection('parameters')
            .where('clave', isEqualTo: 'eps')
            .where('activo', isEqualTo: true)
            .get();

    final parameters =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Parameter(
            etiqueta: data['etiqueta'],
            valor: data['valor'],
            orden: data['orden'],
          );
        }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<List<Parameter>> getPermissions() async {
    final snapshot =
        await _firestore
            .collection('parameters')
            .where(
              'clave',
              whereIn: [
                'permission',
                'enrollment',
                'qr',
              ],
            )
            .where('activo', isEqualTo: true)
            .get();
    final parameters =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Parameter(
            etiqueta: data['etiqueta'],
            valor: data['valor'],
            orden: data['orden'],
          );
        }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<bool> getEnrollmentParentEnabled() async {
    try {
      final snapshot =
          await _firestore
              .collection('parameters')
              .where('clave', isEqualTo: 'enrollment_parent_enabled')
              .where('activo', isEqualTo: true)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return false;
      final valor = snapshot.docs.first.data()['valor'];
      if (valor is bool) return valor;
      if (valor is String) {
        final v = valor.toLowerCase();
        return v == 'true' || v == '1' || v == 'si';
      }
      if (valor is num) return valor != 0;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<int?> getEnrollmentYear() async {
    try {
      final snapshot =
          await _firestore
              .collection('parameters')
              .where('clave', isEqualTo: 'enrollment_year')
              .where('activo', isEqualTo: true)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return null;
      final valor = snapshot.docs.first.data()['valor'];
      if (valor is int) return valor;
      if (valor is num) return valor.toInt();
      if (valor is String) return int.tryParse(valor);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<userModelv2>> getUsersByFilters({
    required String institution,
    required String campus,
    required String role,
    String? grade,
  }) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('institution', isEqualTo: institution)
          .where('campus', isEqualTo: campus)
          .where('role', isEqualTo: role)
          .where('status', isEqualTo: 'activo');

      if (grade != null && grade.isNotEmpty) {
        query = query.where('grade', isEqualTo: grade);
      }

      final QuerySnapshot<Map<String, dynamic>> result = await query.get();

      return result.docs.map((doc) {
        return userModelv2.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
