List<String> extractNotificationTokens(Map<String, dynamic> data) {
  final tokens = <String>{};
  final raw = data['notificationTokens'];
  if (raw is Map) {
    final web = raw['web'];
    final mobile = raw['mobile'];

    if (web is String && web.trim().isNotEmpty) {
      tokens.add(web.trim());
    }
    if (mobile is String && mobile.trim().isNotEmpty) {
      tokens.add(mobile.trim());
    }
  }
  return tokens.toList();
}
