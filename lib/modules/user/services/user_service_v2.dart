import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../models/user/user_model_v2.dart';

class UserDeletionImpactItem {
  final String key;
  final String label;
  final int count;
  final String action;

  const UserDeletionImpactItem({
    required this.key,
    required this.label,
    required this.count,
    required this.action,
  });

  factory UserDeletionImpactItem.fromMap(Map<String, dynamic> map) {
    return UserDeletionImpactItem(
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      count: (map['count'] as num?)?.toInt() ?? 0,
      action: (map['action'] ?? '').toString(),
    );
  }
}

class UserDeletionImpact {
  final int linkedRecords;
  final List<UserDeletionImpactItem> items;

  const UserDeletionImpact({required this.linkedRecords, required this.items});

  factory UserDeletionImpact.fromMap(Map<String, dynamic> map) {
    final rawItems = map['impact'] as List<dynamic>? ?? const [];
    return UserDeletionImpact(
      linkedRecords: (map['linkedRecords'] as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map>()
          .map(
            (item) =>
                UserDeletionImpactItem.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class TeacherTransferPreview {
  final Map<String, int> impact;
  final bool targetHasLoad;
  final List<String> conflicts;
  final int academicYear;

  const TeacherTransferPreview({
    required this.impact,
    required this.targetHasLoad,
    required this.conflicts,
    required this.academicYear,
  });

  factory TeacherTransferPreview.fromMap(Map<String, dynamic> data) {
    final rawImpact = Map<String, dynamic>.from(
      data['impact'] as Map? ?? const {},
    );
    return TeacherTransferPreview(
      impact: rawImpact.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      targetHasLoad: data['targetHasLoad'] == true,
      conflicts: (data['conflicts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => (item['message'] ?? '').toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      academicYear:
          ((data['academicYear'] as Map?)?['year'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveTeacherTransfer {
  final String id;
  final String sourceTeacherName;
  final String targetTeacherName;
  final bool temporary;
  final int academicYear;
  final DateTime? endsAt;

  const ActiveTeacherTransfer({
    required this.id,
    required this.sourceTeacherName,
    required this.targetTeacherName,
    required this.temporary,
    required this.academicYear,
    required this.endsAt,
  });

  factory ActiveTeacherTransfer.fromMap(Map<String, dynamic> data) =>
      ActiveTeacherTransfer(
        id: (data['id'] ?? '').toString(),
        sourceTeacherName: (data['sourceTeacherName'] ?? '').toString(),
        targetTeacherName: (data['targetTeacherName'] ?? '').toString(),
        temporary: data['mode'] == 'temporary',
        academicYear: (data['academicYear'] as num?)?.toInt() ?? 0,
        endsAt: data['endsAtMillis'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (data['endsAtMillis'] as num).toInt(),
              )
            : null,
      );
}

class UserServiceV2 {
  final _db = FirebaseFirestore.instance;

  /// Obtener todos los usuarios desde la coleccion 'users'
  Future<List<userModelv2>> obtenerTodos({
    required String institutionId,
    required String campusId,
    bool isSuperadmin = false,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('users');
    if (!isSuperadmin) {
      query = query
          .where('institution', isEqualTo: institutionId)
          .where('campus', isEqualTo: campusId)
          .where('status', whereIn: const ['activo', 'inactivo']);
    }
    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => userModelv2.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Obtener usuario por ID
  Future<userModelv2?> obtenerPorId({
    required String uid,
    required String institutionId,
    required String campusId,
  }) async {
    final doc = await _db
        .collection('users')
        .where(FieldPath.documentId, isEqualTo: uid)
        .where('institution', isEqualTo: institutionId)
        .where('campus', isEqualTo: campusId)
        .limit(1)
        .get();

    if (doc.docs.isEmpty) return null;
    return userModelv2.fromFirestore(doc.docs.first.data(), doc.docs.first.id);
  }

  /// Guardar o actualizar un usuario en Firestore
  Future<void> guardarUsuario(userModelv2 usuario) async {
    if (usuario.id.trim().isEmpty) {
      throw Exception('El ID del usuario no puede estar vacio');
    }
    final callable = FirebaseFunctions.instance.httpsCallable(
      'actualizarUsuarioDesdeAdmin',
    );
    final result = await callable.call({
      'uid': usuario.id,
      'profile': usuario.toMap(),
    });
    if (result.data['success'] != true) {
      throw Exception('No se pudo actualizar el usuario');
    }
  }

  /// Generar un nuevo UID local (no para Auth, solo ID de Firestore)
  Future<String> generarNuevoUid() async {
    final docRef = _db.collection('users').doc();
    return docRef.id;
  }

  /// Crear usuario en Firebase Auth via Cloud Function
  Future<String> crearUsuarioDesdeAdmin({
    required userModelv2 usuario,
    required String email,
    required String password,
    required String nombres,
    required String apellidos,
    required String rol,
    required String documento,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'crearUsuarioDesdeAdmin',
    );
    final result = await callable.call({
      'email': email,
      'password': password,
      'nombres': nombres,
      'apellidos': apellidos,
      'rol': rol,
      'documento': documento,
      'profile': usuario.toMap(),
    });

    if (result.data['exito'] != true) {
      throw Exception('No se pudo crear el usuario');
    }

    return result.data['uid'];
  }

  Future<UserDeletionImpact> obtenerImpactoEliminacion(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'obtenerImpactoEliminacionUsuario',
    );
    final result = await callable.call({'uid': uid});
    return UserDeletionImpact.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  /// Desactiva, retira del listado o elimina definitivamente al usuario.
  Future<void> eliminarUsuarioAuth(String uid, {required String mode}) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'eliminarUsuarioAuth',
    );
    final result = await callable.call({
      'uid': uid,
      'mode': mode,
      if (mode == 'permanent') 'confirmation': 'ELIMINAR $uid',
    });

    if (result.data['success'] != true) {
      throw Exception('No se pudo eliminar el usuario en Auth');
    }
  }

  Future<void> eliminar(userModelv2 usuario, {required String mode}) async {
    await eliminarUsuarioAuth(usuario.id, mode: mode);
  }

  Future<void> actualizarEstado({
    required String uid,
    required String status,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'actualizarEstadoUsuario',
    );
    final result = await callable.call({'uid': uid, 'status': status});
    if (result.data['success'] != true) {
      throw Exception('No se pudo actualizar el estado del usuario');
    }
  }

  Future<TeacherTransferPreview> previewTeacherTransfer({
    required String sourceTeacherId,
    required String targetTeacherId,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('previsualizarTrasladoDocente')
        .call({
          'sourceTeacherId': sourceTeacherId,
          'targetTeacherId': targetTeacherId,
        });
    return TeacherTransferPreview.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<List<ActiveTeacherTransfer>> listActiveTeacherTransfers({
    required String institutionId,
    required String campusId,
    bool allTenants = false,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('listarTrasladosDocentes')
        .call({
          'institutionId': institutionId,
          'campusId': campusId,
          'allTenants': allTenants,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['transfers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              ActiveTeacherTransfer.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> revertTemporaryTeacherTransfer(String id) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('revertirTrasladoDocenteTemporal')
        .call({'id': id});
    if (result.data['success'] != true) {
      throw Exception('No se pudo cerrar el reemplazo temporal.');
    }
  }

  Future<void> executeTeacherTransfer({
    required String sourceTeacherId,
    required String targetTeacherId,
    required bool temporary,
    required bool allowMerge,
    DateTime? endsAt,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('ejecutarTrasladoDocente')
        .call({
          'sourceTeacherId': sourceTeacherId,
          'targetTeacherId': targetTeacherId,
          'mode': temporary ? 'temporary' : 'permanent',
          'allowMerge': allowMerge,
          if (temporary && endsAt != null)
            'endsAtMillis': endsAt.millisecondsSinceEpoch,
        });
    if (result.data['success'] != true) {
      throw Exception('No se pudo trasladar la carga docente.');
    }
  }

  Future<void> actualizarQr({
    required String uid,
    required String payload,
  }) async {
    await _db.collection('users').doc(uid).set({
      'qrPayload': payload,
      'qrEnabled': true,
      'qrUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Registrar historial de acciones del usuario (agrega institution/campus)
  Future<void> registrarHistorial({
    required userModelv2 usuario,
    required String accion,
    required String realizadoPor,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'registrarAuditoria',
    );
    await callable.call({
      'type': 'user_history',
      'payload': {'userId': usuario.id, 'action': accion},
    });
  }

  // ================== VALIDACIONES DE UNICIDAD ==================

  Future<bool> existeCorreoPersonal(String email, {String? excluirId}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snap = await _db
        .collection('users')
        .where('personalEmail', isEqualTo: normalizedEmail)
        .limit(5)
        .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }

  Future<bool> existeCorreoInstitucional(
    String email, {
    String? excluirId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final snap = await _db
        .collection('users')
        .where('institutionalEmail', isEqualTo: normalizedEmail)
        .limit(5)
        .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }

  Future<bool> existeDocumento(String documento, {String? excluirId}) async {
    final snap = await _db
        .collection('users')
        .where('document', isEqualTo: documento.trim())
        .limit(5)
        .get();

    if (snap.docs.isEmpty) return false;
    if (excluirId == null) return true;
    return snap.docs.any((d) => d.id != excluirId);
  }
}
