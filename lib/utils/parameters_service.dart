import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user/user_model_v2.dart';

class Parameter {
  final String etiqueta;
  final String valor;
  final int orden;

  Parameter({required this.etiqueta, required this.valor, required this.orden});
}

class InstitutionOption {
  final String id;
  final String label;
  final List<String> campuses;

  const InstitutionOption({
    required this.id,
    required this.label,
    required this.campuses,
  });
}

class ParametersService {
  final _firestore = FirebaseFirestore.instance;

  Parameter _mapParameter(Map<String, dynamic> data) {
    final valor = (data['valor'] ?? '').toString().trim();
    final etiquetaRaw = data['etiqueta'];
    final etiqueta = (etiquetaRaw == null ? valor : etiquetaRaw.toString())
        .trim();
    final ordenRaw = data['orden'];
    final orden = ordenRaw is int
        ? ordenRaw
        : ordenRaw is num
        ? ordenRaw.toInt()
        : int.tryParse(ordenRaw?.toString() ?? '') ?? 0;

    return Parameter(etiqueta: etiqueta, valor: valor, orden: orden);
  }

  Future<List<InstitutionOption>> getInstitutions() async {
    final snapshot = await _firestore
        .collection('configuracion_colegios')
        .get();
    final institutions = <InstitutionOption>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      final id = (data['institutionId'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final rawCampuses = data['sedes'];
      final campuses = <String>{};
      if (rawCampuses is List) {
        for (final item in rawCampuses) {
          final value = item is Map
              ? (item['id'] ?? item['nombre'] ?? '').toString().trim()
              : item.toString().trim();
          if (value.isNotEmpty) campuses.add(value);
        }
      }
      institutions.add(
        InstitutionOption(
          id: id,
          label: (data['nombre'] ?? id).toString().trim(),
          campuses: campuses.toList()..sort(),
        ),
      );
    }
    institutions.sort((a, b) => a.label.compareTo(b.label));
    return institutions;
  }

  Future<List<Parameter>> getDocumentTypes() async {
    final snapshot = await _firestore
        .collection('parameters')
        .where('clave', isEqualTo: 'documentType')
        .where('activo', isEqualTo: true)
        .get();

    final parameters = snapshot.docs
        .map((doc) => _mapParameter(doc.data()))
        .toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<List<Parameter>> getRoles() async {
    final snapshot = await _firestore
        .collection('parameters')
        .where('clave', isEqualTo: 'role')
        .where('activo', isEqualTo: true)
        .get();

    final parameters = snapshot.docs.map((doc) {
      final mapped = _mapParameter(doc.data());
      return Parameter(
        etiqueta: mapped.valor,
        valor: mapped.valor,
        orden: mapped.orden,
      );
    }).toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));
    return parameters;
  }

  Future<List<Parameter>> getEps() async {
    final snapshot = await _firestore
        .collection('parameters')
        .where('clave', isEqualTo: 'eps')
        .where('activo', isEqualTo: true)
        .get();

    final parameters = snapshot.docs
        .map((doc) => _mapParameter(doc.data()))
        .toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<List<Parameter>> getPermissions() async {
    final snapshot = await _firestore
        .collection('parameters')
        .where('clave', isEqualTo: 'permission')
        .where('activo', isEqualTo: true)
        .get();
    final parameters = snapshot.docs
        .map((doc) => _mapParameter(doc.data()))
        .toList();

    parameters.sort((a, b) => a.orden.compareTo(b.orden));

    return parameters;
  }

  Future<bool> getEnrollmentParentEnabled() async {
    try {
      final snapshot = await _firestore
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
      final snapshot = await _firestore
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
  }) async {
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('institution', isEqualTo: institution)
          .where('campus', isEqualTo: campus)
          .where('role', isEqualTo: role)
          .where('status', isEqualTo: 'activo');

      final QuerySnapshot<Map<String, dynamic>> result = await query.get();

      return result.docs.map((doc) {
        return userModelv2.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
