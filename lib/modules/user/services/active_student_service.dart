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
    var revision = user.revision;
    if (user.activeStudentId != id) {
      final result = await _functions
          .httpsCallable('seleccionarHijoActivo')
          .call({'studentId': id});
      final data = Map<String, dynamic>.from(result.data as Map);
      revision = (data['revision'] as num?)?.toInt() ?? (revision + 1);
    }
    userProvider.setUser(
      user.copyWith(activeStudentId: id, revision: revision),
    );
  }
}
