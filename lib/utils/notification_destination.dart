String? notificationDestination(Map<String, dynamic> data) {
  final id = data['channelId'];
  if (data['type'] != 'messaging' ||
      id is! String ||
      id.isEmpty ||
      id.length > 160 ||
      id.contains('/')) {
    return null;
  }
  return Uri(path: '/messages', queryParameters: {'channelId': id}).toString();
}
