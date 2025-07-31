enum HistoryType {
  rutasDiarias,
  gestionRutas,
  gestionUsuarios,
  gestionHorarios,
  gestionDocumentos,
}

extension HistoryTypeExtension on HistoryType {
  String get label {
    switch (this) {
      case HistoryType.rutasDiarias:
        return 'Historial de rutas diarias';
      case HistoryType.gestionRutas:
        return 'Historial de gestión de rutas';
      case HistoryType.gestionUsuarios:
        return 'Historial de gestión de usuarios';
      case HistoryType.gestionHorarios:
        return 'Historial de gestión de horarios';
      case HistoryType.gestionDocumentos:
        return 'Historial de gestión de documentos';
    }
  }
}
