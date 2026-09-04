import 'package:cloud_functions/cloud_functions.dart';

Future<void> enviarNotificacion({
  required String notificationType,
  required String titulo,
  required String cuerpo,
  List<String> tokens = const [],
  List<String> userIds = const [],
  List<String> studentIds = const [],
  List<String> roles = const [],
  bool includeFamilies = false,
  bool includeFamiliesForGroup = false,
  String? groupId,
}) async {
  final cleanTokens = tokens
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toSet()
      .toList();
  final cleanUserIds = userIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  final cleanStudentIds = studentIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  if (cleanTokens.isEmpty &&
      cleanUserIds.isEmpty &&
      cleanStudentIds.isEmpty &&
      roles.isEmpty &&
      !includeFamiliesForGroup) {
    return;
  }

  final callable = FirebaseFunctions.instance.httpsCallable(
    'enviarNotificacion',
  );
  await callable
      .call({
        'notificationType': notificationType,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'groupId': groupId,
        'tokens': cleanTokens,
        'audience': {
          'userIds': cleanUserIds,
          'studentIds': cleanStudentIds,
          'roles': roles,
          'groupId': groupId,
          'includeFamilies': includeFamilies,
          'includeFamiliesForGroup': includeFamiliesForGroup,
        },
      })
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('Tiempo agotado al enviar notificacion'),
      );
}
