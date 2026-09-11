String? notificationDestination(Map<String, dynamic> data, {String? role}) {
  final type = data['type'];
  if (type is! String) return null;
  final channelId = data['channelId'];
  if (type == 'messaging') {
    if (channelId is! String ||
        channelId.isEmpty ||
        channelId.length > 160 ||
        channelId.contains('/')) {
      return null;
    }
    return Uri(
      path: '/messages',
      queryParameters: {'channelId': channelId},
    ).toString();
  }
  final normalizedRole = (role ?? '').trim().toLowerCase();
  final administrator =
      normalizedRole == 'administrador' ||
      normalizedRole == 'superadministrador';
  return switch (type) {
    'route' => '/my_route',
    'enrollment' => '/enrollment',
    'schedule' =>
      administrator
          ? '/management_schedule'
          : normalizedRole == 'docente'
          ? '/teacher_schedule'
          : '/my_schedule',
    'authorization' =>
      administrator
          ? '/admin_authorization'
          : normalizedRole == 'docente'
          ? '/teacher_authorization'
          : normalizedRole == 'familiar'
          ? '/student_authorization'
          : null,
    'files' =>
      administrator
          ? '/management_document'
          : normalizedRole == 'docente'
          ? '/teacher_document'
          : '/student_document',
    'attendance' => '/attendance',
    'event' => '/events',
    _ => null,
  };
}
