import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FormatUtils {
  static String formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No seleccionada';
    return DateFormat('yyyy-MM-dd').format(fecha);
  }

  static String formatearHora(TimeOfDay? hora) {
    if (hora == null) return 'No seleccionada';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, hora.hour, hora.minute);
    return DateFormat('HH:mm').format(dt);
  }

  static Timestamp? timestampDesdeHora(TimeOfDay? hora) {
    if (hora == null) return null;
    return Timestamp.fromDate(DateTime(2000, 1, 1, hora.hour, hora.minute));
  }

  static TimeOfDay? timeOfDayDesdeTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return null;
    final dt = timestamp.toDate();
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  static DateTime? dateTimeDesdeTimestamp(Timestamp? timestamp) {
    return timestamp?.toDate();
  }

  static Timestamp? timestampDesdeDateTime(DateTime? date) {
    return date != null ? Timestamp.fromDate(date) : null;
  }

  static String formatHourRange(Timestamp inicio, Timestamp fin) {
    final i = DateFormat('HH:mm').format(inicio.toDate());
    final f = DateFormat('HH:mm').format(fin.toDate());
    return '$i - $f';
  }

  static String formatearHoraDesdeTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No disponible';
    return DateFormat('HH:mm').format(timestamp.toDate());
  }

  static String formatoFechaHora(DateTime fecha) {
    return DateFormat('yyyy-MM-dd HH:mm').format(fecha);
  }

  static String formatoHora(DateTime fecha) {
    return DateFormat('HH:mm').format(fecha);
  }
}
