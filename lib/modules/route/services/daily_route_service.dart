import 'package:cloud_functions/cloud_functions.dart';

class RouteOperations {
  static int _sequence = 0;
  static Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> execute(
    String id,
    String command, [
    Map<String, dynamic> data = const {},
  ]) async {
    await call('operarRecorrido', {
      'id': id,
      'command': command,
      'requestId': '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      ...data,
    });
  }
}
