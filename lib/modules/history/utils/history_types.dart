enum HistoryType {
  rutasDiarias,
  gestionRutas,
  gestionUsuarios,
  gestionHorarios,
  gestionDocumentos,
  userLogs,
}

extension HistoryTypeX on HistoryType {
  String get label {
    switch (this) {
      case HistoryType.rutasDiarias:
        return 'Rutas diarias';
      case HistoryType.gestionRutas:
        return 'Gestión de rutas';
      case HistoryType.gestionUsuarios:
        return 'Gestión de usuarios';
      case HistoryType.gestionHorarios:
        return 'Gestión de horarios';
      case HistoryType.gestionDocumentos:
        return 'Gestión de documentos';
      case HistoryType.userLogs:
        return 'Logs de usuario';
    }
  }
}