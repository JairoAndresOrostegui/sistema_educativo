import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/daily_route_model.dart';
import '../models/student_route_model.dart';
import '../models/user_model.dart';

class RutaDiariaService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RutaDiariaService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String _generateRutaDiaId(String rutaId) {
    final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${rutaId}_$fechaHoy';
  }

  Future<RutaDiaria?> getRutaDia(String rutaId) async {
    final idRutaDia = _generateRutaDiaId(rutaId);
    final doc =
        await _firestore.collection('rutas_diarias').doc(idRutaDia).get();
    return doc.exists ? RutaDiaria.fromFirestore(doc) : null;
  }

  Future<List<EstudianteRutaDiaria>> getEstudiantesRutaDia(
    String rutaDiariaId,
  ) async {
    final query =
        await _firestore
            .collection('rutas_diarias')
            .doc(rutaDiariaId)
            .collection('estudiantes')
            .get();
    return query.docs
        .map((doc) => EstudianteRutaDiaria.fromFirestore(doc))
        .toList()
      ..sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));
  }

  Future<RutaDiaria> createRutaDia({
    required String rutaId,
    required String nombreRuta,
    required List<String> estudiantesIds,
  }) async {
    final idRutaDia = _generateRutaDiaId(rutaId);
    final ref = _firestore.collection('rutas_diarias').doc(idRutaDia);

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuario no autenticado.');
    }

    final userSnap =
        await _firestore.collection('usuarios').doc(currentUser.uid).get();
    if (!userSnap.exists) {
      throw Exception(
        'Datos de usuario no encontrados para ${currentUser.uid}',
      );
    }
    final userData = userSnap.data()!;
    final userId = userSnap.id;

    final UsuarioModel user = UsuarioModel.fromFirestore(userData, userId);
    final nombreDocente = '${user.nombres} ${user.apellidos}';

    final estudiantesRef = _firestore.collection('usuarios');
    final List<Map<String, dynamic>> estudiantesData = [];

    for (int i = 0; i < estudiantesIds.length; i++) {
      final id = estudiantesIds[i];
      final doc = await estudiantesRef.doc(id).get();
      if (doc.exists) {
        final dataEst = doc.data()!;
        estudiantesData.add({
          'id': id,
          'nombre': '${dataEst['nombres']} ${dataEst['apellidos']}',
          'direccion': dataEst['direccionRuta'] ?? '',
          'activo': true,
          'recogido': false,
          'horaRecogida': null,
          'avisoEnviado': false,
          'anulado': false,
          'orden': i,
        });
      }
    }

    await ref.set({
      'idRuta': rutaId,
      'nombreRuta': nombreRuta,
      'fecha': Timestamp.now(),
      'gestionador': currentUser.uid,
      'gestionadaPorNombre': nombreDocente,
      'estado': 'pendiente',
      'horaInicio': null,
      'horaFin': null,
    });

    for (final est in estudiantesData) {
      await ref.collection('estudiantes').doc(est['id']).set(est);
    }

    final nuevaRutaDiaDoc = await ref.get();
    return RutaDiaria.fromFirestore(nuevaRutaDiaDoc);
  }

  Future<void> updateEstudianteRutaDiaria(
    String rutaDiariaId,
    String estudianteId,
    Map<String, dynamic> data,
  ) async {
    final ref = _firestore
        .collection('rutas_diarias')
        .doc(rutaDiariaId)
        .collection('estudiantes')
        .doc(estudianteId);
    await ref.update(data);
  }

  Future<void> updateRutaDiaria(
    String rutaDiariaId,
    Map<String, dynamic> data,
  ) async {
    final ref = _firestore.collection('rutas_diarias').doc(rutaDiariaId);
    await ref.update(data);
  }

  Future<void> updateStudentAddress(String studentId, String newAddress) async {
    await _firestore.collection('usuarios').doc(studentId).update({
      'direccionRuta': newAddress,
    });
  }
}
