import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/route/route_model.dart';

class RouteService {
  final _collection = FirebaseFirestore.instance.collection('rutas');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<RutaModel>> obtenerTodasLasRutas() async {
    final query = await _collection.get();
    return query.docs.map((doc) => RutaModel.fromFirestore(doc)).toList();
  }

  Future<void> eliminarRuta(String id) async {
    final ruta = await obtenerRutaPorId(id);
    await _collection.doc(id).delete();

    if (ruta != null) {
      await registrarHistorialRuta(ruta: ruta, accion: 'eliminado');
    }
  }

  Future<RutaModel?> obtenerRutaPorId(String id) async {
    final doc = await _collection.doc(id).get();
    return doc.exists ? RutaModel.fromFirestore(doc) : null;
  }

  Future<void> guardarRuta({String? id, required RutaModel ruta}) async {
    final data = ruta.toMap();

    if (id == null) {
      final docRef = await _collection.add(data);
      final nuevaRuta = ruta.copyWithId(docRef.id);
      await registrarHistorialRuta(ruta: nuevaRuta, accion: 'creado');
    } else {
      final anterior = await obtenerRutaPorId(id);
      await _collection.doc(id).update(data);
      final actualizada = ruta.copyWithId(id);

      final cambios = _compararRutas(anterior!, actualizada);
      if (cambios.isNotEmpty) {
        await registrarHistorialRuta(
          ruta: actualizada,
          accion: 'editado',
          cambios: cambios,
        );
      }
    }
  }

  Map<String, dynamic> _compararRutas(RutaModel antes, RutaModel despues) {
    final cambios = <String, dynamic>{};

    if (antes.nombre != despues.nombre) {
      cambios['nombre'] = '${antes.nombre} ➝ ${despues.nombre}';
    }
    if (antes.direccionInicio != despues.direccionInicio) {
      cambios['direccionInicio'] =
          '${antes.direccionInicio} ➝ ${despues.direccionInicio}';
    }
    if (antes.fechaInicio != despues.fechaInicio) {
      cambios['fechaInicio'] = '${antes.fechaInicio} ➝ ${despues.fechaInicio}';
    }
    if (antes.fechaFin != despues.fechaFin) {
      cambios['fechaFin'] = '${antes.fechaFin} ➝ ${despues.fechaFin}';
    }
    if (antes.horaInicio != despues.horaInicio) {
      cambios['horaInicio'] = '${antes.horaInicio} ➝ ${despues.horaInicio}';
    }
    if (antes.horaFin != despues.horaFin) {
      cambios['horaFin'] = '${antes.horaFin} ➝ ${despues.horaFin}';
    }
    if (antes.gestionador != despues.gestionador) {
      cambios['gestionador'] = '${antes.gestionador} ➝ ${despues.gestionador}';
    }

    if (antes.estudiantes.toString() != despues.estudiantes.toString()) {
      cambios['estudiantes'] = 'Modificados';
    }

    return cambios;
  }

  Future<List<DocumentSnapshot>> obtenerEstudiantesDisponibles() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', isEqualTo: 'estudiante')
            .where('estado', isEqualTo: 'activo')
            .get();

    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> obtenerGestionadoresDisponibles() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('usuarios')
            .where('rol', whereIn: ['docente', 'admin'])
            .where('estado', isEqualTo: 'activo')
            .get();

    return snapshot.docs;
  }

  Future<List<RutaModel>> getRutasAsignadas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Usuario no autenticado');
    }
    final query =
        await FirebaseFirestore.instance
            .collection('rutas')
            .where('gestionador', isEqualTo: uid)
            .get();
    return query.docs.map((doc) => RutaModel.fromFirestore(doc)).toList();
  }

  Future<void> registrarHistorialRuta({
    required RutaModel ruta,
    required String accion, // creado, editado, eliminado
    Map<String, dynamic>? cambios,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final usuarioDoc =
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final nombreCompleto =
        '${usuarioDoc['nombres']} ${usuarioDoc['apellidos']}';

    await FirebaseFirestore.instance.collection('historial_rutas_admin').add({
      'rutaId': ruta.id,
      'nombreRuta': ruta.nombre,
      'accion': accion,
      'realizadoPor': uid,
      'nombreAdmin': nombreCompleto,
      'fecha': FieldValue.serverTimestamp(),
      if (cambios != null) 'detalles': cambios,
    });
  }
}
