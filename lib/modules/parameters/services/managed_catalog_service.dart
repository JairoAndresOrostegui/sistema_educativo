import 'package:cloud_functions/cloud_functions.dart';

import '../models/managed_catalog_entry.dart';

class ManagedCatalogService {
  final FirebaseFunctions _functions;

  ManagedCatalogService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<List<ManagedCatalogEntry>> list() async {
    final response = await _functions
        .httpsCallable('listarCatalogosAdministrables')
        .call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              ManagedCatalogEntry.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> save({
    String? id,
    required String key,
    required String label,
    required String value,
    required int order,
    required bool active,
  }) async {
    await _functions.httpsCallable('guardarCatalogoAdministrable').call({
      'id': ?id,
      'key': key,
      'label': label,
      'value': value,
      'order': order,
      'active': active,
    });
  }
}
