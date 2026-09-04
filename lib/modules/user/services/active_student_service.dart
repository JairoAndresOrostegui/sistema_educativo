import 'package:cloud_functions/cloud_functions.dart';

import '../../../providers/user_provider_v2.dart';

class ActiveStudentService {
  final FirebaseFunctions _functions;

  ActiveStudentService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<void> select({
    required UserProviderV2 userProvider,
    required String studentId,
  }) async {
    final id = studentId.trim();
    if (id.isEmpty) return;
    final user = userProvider.user;
    if (user == null || user.role != 'Familiar') return;
    if (user.activeStudentId != id) {
      await _functions.httpsCallable('seleccionarHijoActivo').call({
        'studentId': id,
      });
    }
    userProvider.setActiveStudentId(id);
  }
}
