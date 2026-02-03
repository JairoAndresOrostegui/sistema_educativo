import '../models/enrollment_rule.dart';

/// Reglas declarativas de visibilidad/edición/requerido por rol y estado.
/// - Rol "admin": implícitamente puede editar todo; usar reglas solo si se desea
///   ocultar o marcar obligatorio algún campo adicional.
/// - Rol "padre": restringimos a sus campos y readonly cuando ya está matriculado.
const List<EnrollmentRule> enrollmentRules = [
  // En estado matriculado, padres ven todo pero no editan (control en UI readonly).
  EnrollmentRule(
    fieldName: '*',
    roles: ['padre'],
    estados: ['matriculado'],
    editable: false,
  ),
  // Campos internos solo visibles para admin.
  EnrollmentRule(
    fieldName: 'anioInscripcion',
    roles: ['padre'],
    visible: false,
  ),
  EnrollmentRule(
    fieldName: 'fechaInscripcion',
    roles: ['padre'],
    visible: false,
  ),
  // Observaciones/referencias son opcionales para padre.
  EnrollmentRule(
    fieldName: 'observacionesPadres',
    roles: ['padre'],
    required: false,
  ),
  // Servicios opcionales para padre.
  EnrollmentRule(
    fieldName: 'servicioAlmuerzo',
    roles: ['padre'],
    required: false,
  ),
  EnrollmentRule(
    fieldName: 'servicioTransporte',
    roles: ['padre'],
    required: false,
  ),
];
