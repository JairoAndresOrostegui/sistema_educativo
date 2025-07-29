import 'package:cloud_firestore/cloud_firestore.dart';

class UserTokenService {
  final FirebaseFirestore _firestore;

  UserTokenService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<String>> getFcmTokensForUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('usuarios').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData.containsKey('fcmTokens')) {
          return List<String>.from(userData['fcmTokens'] ?? []);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, List<String>>> getFcmTokensForUsers(List<String> userIds) async {
    final Map<String, List<String>> allTokens = {};
    for (final userId in userIds) {
      final tokens = await getFcmTokensForUser(userId);
      if (tokens.isNotEmpty) {
        allTokens[userId] = tokens;
      }
    }
    return allTokens;
  }
}