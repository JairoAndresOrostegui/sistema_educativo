import '../models/enrollment_section.dart';

/// Secciones declarativas del formulario de matrícula.
const List<EnrollmentSection> enrollmentSections = [
  EnrollmentSection(
    title: 'Datos del estudiante',
    fieldNames: [
      'anioInscripcion',
      'fechaInscripcion',
      'nombresApellidosAlumno',
      'lugarNacimiento',
      'fechaNacimiento',
      'edad',
      'tipoIdentidad',
      'numeroIdentidad',
      'tipoSangre',
      'rh',
      'direccionAlumno',
      'telefonoAlumno',
      'epsEstudiante',
      'gradoAspirado',
      'sedeAspirada',
    ],
  ),
  EnrollmentSection(
    title: 'Información del padre',
    fieldNames: [
      'nombrePadre',
      'cedulaPadre',
      'emailPadre',
      'celularPadre',
      'lugarTrabajoPadre',
      'ocupacionPadre',
      'cargoPadre',
    ],
  ),
  EnrollmentSection(
    title: 'Información de la madre',
    fieldNames: [
      'nombreMadre',
      'cedulaMadre',
      'emailMadre',
      'celularMadre',
      'lugarTrabajoMadre',
      'ocupacionMadre',
      'cargoMadre',
    ],
  ),
  EnrollmentSection(
    title: 'Servicios y referencias',
    fieldNames: [
      'nivelesCursadosInstitucion',
      'servicioAlmuerzo',
      'servicioTransporte',
      'observacionesPadres',
      'nombrePadresReferentes',
      'telefonoReferentes',
      'celularReferentes',
      'nombreReferido',
    ],
  ),
];
