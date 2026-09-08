import 'package:cloud_functions/cloud_functions.dart';

String routeText(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String routeStatusLabel(Object? value) {
  switch (routeText(value).toLowerCase()) {
    case 'pendiente':
      return 'Preparado · aún no ha iniciado';
    case 'activa':
      return 'Recorrido en curso';
    case 'finalizada':
      return 'Recorrido finalizado';
    case 'cancelada':
      return 'Recorrido cancelado';
    default:
      return 'Estado del recorrido no disponible';
  }
}

String routeMapUnavailableMessage({
  required Object? routeStatus,
  required bool travelsToday,
  required bool pickedUp,
  required bool absent,
  required bool mapEnabled,
}) {
  final status = routeText(routeStatus).toLowerCase();
  if (status == 'finalizada') {
    return 'El recorrido terminó. El mapa ya no está disponible.';
  }
  if (status == 'cancelada') {
    return 'El recorrido fue cancelado. El mapa no está disponible.';
  }
  if (pickedUp) {
    return 'La recogida ya fue registrada. El mapa fue cerrado para este estudiante.';
  }
  if (absent || !travelsToday) {
    return 'El estudiante no viaja en este recorrido. El mapa no está disponible.';
  }
  if (status == 'pendiente') {
    return 'El recorrido está preparado, pero todavía no ha iniciado.';
  }
  if (status != 'activa') {
    return 'No fue posible determinar el estado del recorrido.';
  }
  if (!mapEnabled) {
    return 'El mapa se habilitará cuando la llegada estimada sea de 10 minutos o menos.';
  }
  return 'Esperando una ubicación reciente del responsable.';
}

String routeErrorMessage(
  Object error, {
  String fallback =
      'No fue posible completar la operación. Intenta nuevamente.',
}) {
  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim() ?? '';
    if (message.isNotEmpty &&
        message.length <= 300 &&
        !message.contains('firebase_') &&
        !message.contains('Exception') &&
        !message.contains('#0')) {
      return message;
    }
    switch (error.code) {
      case 'unauthenticated':
        return 'Tu sesión venció. Inicia sesión nuevamente.';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta operación.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'El servicio no está disponible temporalmente. Intenta nuevamente.';
      case 'resource-exhausted':
        return 'Se alcanzó el límite disponible. Usa el modo manual.';
      case 'already-exists':
        return 'La solicitud ya fue registrada.';
    }
  }
  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty && message.length <= 300) return message;
  }
  return fallback;
}
