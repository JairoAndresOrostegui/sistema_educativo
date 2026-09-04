# Reglas permanentes del proyecto

Estas reglas aplican a todo cambio futuro en este repositorio.

## Tenencia y acceso

- Toda entidad institucional debe incluir institución y sede.
- Un administrador normal solo consulta y opera en su propia institución y sede.
- Solo el superadministrador puede cambiar de institución o sede y operar entre sedes.
- Las validaciones de alcance se hacen en backend y reglas; ocultar controles en la UI no es seguridad.
- Los usuarios normales solo ven su perfil. La administración del directorio usa el módulo Usuarios.
- Las bajas administrativas son lógicas. Solo el superadministrador elimina definitivamente, con impacto previo, confirmación, cascada, auditoría y detención segura ante fallos.

## Grupos académicos

- La unidad académica es `academic_groups/{groupId}`, aislada por `institutionId` y `campusId`.
- Se usa `groupId` como relación y `groupName` como etiqueta derivada. No crear campos `grade`, `grado` ni `gradoAspirado`.
- Un nivel puede tener varias secciones en una sede: Cuarto A, Cuarto B, etc. Nunca mezclar estudiantes, horarios, archivos, mensajes o autorizaciones solo porque comparten nivel.
- Familiares deben poder seleccionar su hijo activo en todo módulo relacionado con estudiantes. El backend valida que el hijo esté activo y vinculado.

## Autorización y datos

- Las escrituras sensibles pasan por Cloud Functions y generan historial. El cliente no escribe directamente usuarios, matrículas, autorizaciones, horarios, archivos ni auditorías.
- Estudiantes nunca requieren verificación de correo. Administradores, docentes y familiares sí.
- En Autorizaciones, Familiar solo usa `autorizaciones.ver` para solicitar y consultar. Estudiante no tiene acceso. Una solicitud finalizada es inmutable salvo corrección del superadministrador con log.
- Ninguna eliminación debe dejar huérfanos. Comprobar relaciones antes de borrar y usar transacciones, lotes o compensación cuando intervengan Auth/Storage.

## Archivos y costos

- Archivos tiene cuota de 1 GiB por institución, máximo 25 MiB por documento y retención operativa de 60 días.
- La carga usa reserva de cuota, ruta autorizada, metadatos verificados y confirmación backend.
- Solo el superadministrador ejecuta la limpieza global por antigüedad; las eliminaciones manuales respetan permisos y siempre quedan auditadas.
- Solo administradores y superadministradores eliminan archivos. Un docente nunca puede borrar ni ocultar publicaciones, aunque reciba un permiso manipulado.
- Cada publicación puede incluir un mensaje o enlace y materializa su audiencia (`all`, `groups` o `students`), estudiantes destinatarios y usuarios notificados. El administrador puede usar las tres audiencias; el docente solo sus grupos dictados o estudiantes de esos grupos.
- Las notificaciones de Archivos incluyen estudiantes y familiares. Cuando publica un administrador, incluyen además los docentes que dictan en los grupos involucrados.
- Borrar primero el objeto de Storage y después sus metadatos/contador. Si Storage falla, conservar un estado reintentable.

## Mensajería institucional

- Cada grupo académico tiene un único chat general con estudiantes activos,
  familiares vinculados, docente líder y docentes que dictan en el grupo.
- Estudiantes solo conversan con otros estudiantes en el chat general del
  grupo; nunca por privado, aunque compartan grupo o exista un chat anterior.
- Familiares pueden conversar por privado con otros familiares si el hijo
  activo seleccionado comparte grupo vigente con algún hijo activo vinculado
  al destinatario, dentro de la misma institución y sede. Cada envío revalida
  estos vínculos. También contactan docentes del hijo activo y administración;
  nunca estudiantes ajenos.
- Matrícula, retiro, cambio de grupo, estado de usuario, horario y traslado
  docente sincronizan la membresía automáticamente sin reescribir la autoría.
- Administración puede silenciar un canal colectivo: queda en solo anuncios,
  sin borrar ni ocultar su historial.
- Mensajes, lecturas y silencios se escriben mediante Cloud Functions. Cada
  mensaje conserva secuencia, autor y fecha; docentes y administradores pueden
  consultar quién leyó sus mensajes y cuándo.
- Lonchera, Restaurante, Ruta y futuros servicios usan canales tipificados del
  mismo motor. El módulo de origen conserva su estado operativo y Mensajería
  conserva únicamente la comunicación; nunca duplicar colecciones de chat.

## Interfaz y calidad

- Los colores, tipografía, nombre y logo globales se obtienen de la configuración del sitio en Firestore y se aplican mediante `ThemeData`/`ColorScheme`.
- Todo módulo revisado o nuevo usa una cabecera uniforme como Perfil: fondo de superficie, título centrado, contraste primario y botón visible para volver al tablero.
- Los módulos internos usan superficies sólidas, sin degradados. El rojo de marca debe ser sobrio y provenir exclusivamente del tema central.
- No introducir colores de marca con `Colors.*` o `Color(0x...)` dentro de módulos. Usar `Theme.of(context).colorScheme` y tokens semánticos centralizados.
- No agregar compatibilidad permanente con esquemas antiguos. Los cambios de modelo incluyen migración única de datos, índices, reglas y pruebas.
- Mantener textos en UTF-8 y nombres visibles en español correcto.
- Antes de desplegar: formato, `flutter analyze`, pruebas Flutter, lint Functions y pruebas de emuladores relevantes.
- El proyecto Firebase actual es QA. Producción real tendrá proyecto, credenciales, bucket, hosting y variables separados.

Consulta [docs/GUIA_DESARROLLO.md](docs/GUIA_DESARROLLO.md) y [docs/MANUAL_USUARIO.md](docs/MANUAL_USUARIO.md) antes de ampliar un módulo.

Antes de crear o ampliar un módulo con responsabilidad docente, consulta y
actualiza [docs/REGISTRO_CARGA_DOCENTE.md](docs/REGISTRO_CARGA_DOCENTE.md). Debe
integrarse al impacto, traslado temporal/definitivo y reversión; no se permiten
listas manuales de pasos fuera del sistema.
