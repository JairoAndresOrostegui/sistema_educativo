import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/route_model.dart';

class RouteService {
  final _collection = FirebaseFirestore.instance.collection('rutas');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<RutaModel>> obtenerTodasLasRutas() async {
    final query = await _collection.get();
    return query.docs.map((doc) => RutaModel.fromFirestore(doc)).toList();
  }

  Future<void> eliminarRuta(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> guardarRuta({String? id, required RutaModel ruta}) async {
    final data = ruta.toMap();

    if (id == null) {
      await _collection.add(data);
    } else {
      await _collection.doc(id).update(data);
    }
  }

  Future<RutaModel?> obtenerRutaPorId(String id) async {
    final doc = await _collection.doc(id).get();
    return doc.exists ? RutaModel.fromFirestore(doc) : null;
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
}
