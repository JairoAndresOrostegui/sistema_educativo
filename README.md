# sistema_educativo

Aplicación Flutter para gestión escolar multirol (Administrador, Docente, Estudiante/Familiar) sobre Firebase (Auth/Firestore/Storage/Functions/FCM).

## Arquitectura rápida
- `lib/main.dart`: inicializa Firebase (`DefaultFirebaseOptions`), solicita permisos FCM (`fRequestPermission`), carga tema dinámico (`ThemeProvider`), arranca `AppRouter` envuelto en `UserProviderV2` + `PushBootstrap`.
- `lib/app.dart`: `GoRouter` con redirecciones declarativas por rol y rutas a dashboards, perfil y módulos (archivos, rutas, horarios, autorizaciones, historial, usuarios, matrícula). Logout centralizado vía `AuthService`.
- Estado de usuario: `providers/user_provider_v2.dart` (`ChangeNotifier`) mantiene `UserModelV2`, permisos y `activeStudentId`.
- Configuración: `config/firebase_options.dart` (usar este), `config/theme_config.dart`.
- Utils núcleo: notificaciones (`notification_service.dart`, `push_notifications.dart`, `firebase_utils.dart`), parámetros (`parameters_service.dart`), validaciones/formato/snackbar/dialogs (`validators.dart`, `format_utils.dart`, `dialog_utils.dart`, etc.), logs de usuario (`user_log_service.dart`).

## Módulos

### Auth (`lib/modules/auth`)
- Login/reset y protección de rutas por rol. Guards/layouts separan dashboards para Admin/Docente/Estudiante/Familiar.
- Servicio `authServiceV2.dart`: valida credenciales en Auth + Firestore, exige email verificado y estado activo, normaliza errores; logout registra evento.
- FCM tokens: pide permiso, guarda/actualiza en `users.fcmToken/fcmTokens`, listener `onTokenRefresh`.
- Pantallas: `loginScreenV2.dart`, `access_denied_page.dart`; widgets reutilizables (`reset_password_dialog.dart`, logo/título).

### Authorization (`lib/modules/authorization`)
- Solicitudes de autorización de estudiantes con FCM a actores (admins/docentes/estudiantes/familiares).
- Servicio `authorization_service.dart`: consulta por grado/estudiante/admin; crea solicitud con metadata + notifica; actualiza estados (pendiente/aprobada/rechazada/finalizada) y notifica; helpers de hijos para familiares.
- Pantallas: admin (`admin_authorization_screen.dart`), docente (`teacher_authorization_screen.dart`), estudiante/familiar (`student_authorization_screen.dart` con selección de hijo).
- Diálogos: creación/acción/detalle (`student_authorization_dialog.dart`, `teacher_authorization_dialog.dart`, `admin_authorization_action_dialog.dart`).

### File (`lib/modules/file`)
- Compartir archivos por grado con trazabilidad de descargas y FCM.
- Servicio `file_service.dart`: subir a Storage + metadatos en Firestore + notificación a estudiantes/familiares del grado; listar por grado; listar subidos; eliminar en Firestore/Storage.
- Pantallas: `upload_file_screen.dart` (selector de grado, permisos `archivos.crear/eliminar`), `view_file_screen.dart` (agrupa por mes, marca descargados vía `UserLogService`, familiares eligen hijo).
- Descarga multiplataforma: `file_utils.dart` (imports condicionales `file_utils_mobile.dart` / `file_utils_web.dart`).

### History (`lib/modules/history`)
- Panel web de auditoría (rutas diarias, gestión de rutas/usuarios/horarios/documentos, logs).
- Servicios: `daily_route_history_service.dart`, `file_history_service.dart`, `route_history_service.dart`, `schedule_history_service.dart`, `user_history_service.dart`, `user_logs_service.dart` (normalizan datos legacy EN/ES, filtros por tenant/fecha/rol).
- Vistas y exportes: `view/*` con filtros + export a Excel/PDF; adaptadores web/mobile/stub en `export/`.
- Solo web; mobile muestra mensaje no disponible.

### Profile (`lib/modules/profile`)
- Ver/editar foto de perfil. `profile_page.dart` usa `UserProviderV2`; `profile_service.dart` sube a Storage y actualiza `photoUrl`.
- Picker multiplataforma (`profile_image_picker_web.dart`/`mobile`) valida JPG/PNG.
- Widgets: `profile_field.dart`; reutiliza `admin_photo_widget.dart` del módulo User.

### Route (`lib/modules/route`)
- Modelos: `route_model.dart`, `daily_route_model.dart`, `student_route_model.dart`.
- Servicios:
  - `admin_route_service.dart`: CRUD de rutas por tenant, asigna gestionadores, registra historial `routes_admin_history`.
  - `daily_route_service.dart`: crea ruta diaria (clona estudiantes), actualiza estados/horas, marca recogido/anulado y direcciones.
  - `student_route_service.dart`: obtiene ruta diaria del estudiante para web/mapa.
  - `location_service.dart`: publica `teacherPosition` en `daily_routes` con `Geolocator` (`locationSettings`), permisos vía `permission_handler`.
  - Helpers: `location_permission_service.dart`.
- Docente (`screens/teacher_route_screen.dart`): rutas asignadas, crea ruta del día, marca recogido/anulado, avisa llegada y ETA (FCM), inicia/finaliza ruta, comparte ubicación. UI modular (`teacher_route_header.dart`, `teacher_route_student_list.dart`, `teacher_route_student_card.dart`, `teacher_route_controls.dart`); helpers en `utils/teacher_route_helpers.dart` (agrupación de direcciones, tokens FCM).
- Estudiante/Familiar (`screens/student_route_screen.dart`): selección de estudiante (familiares), estado de ruta diaria y mapa (vista en `widgets/student/route_live_view.dart`).
- Admin (`screens/admin_route_screen.dart`): lista rutas tenant; CRUD via `admin_route_form_dialog.dart` / `admin_route_form_body.dart`; permisos `rutas.crear/editar/eliminar`.

### Schedule (`lib/modules/schedule`)
- Servicio `schedule_service.dart`: CRUD de materias en `subjects`, logging en `schedule_history`, notifica FCM a grado; helpers para docentes (`ParametersService`) y horarios por grado/docente.
- Admin (`screens/admin_schedule_screen.dart`): selector de grado, vista semanal web / diaria mobile, `SubjectFormDialog`; widgets extraídos (`admin_grade_dropdown.dart`, `admin_day_column.dart`, `admin_subject_item.dart`).
- Docente (`screens/teacher_schedule_screen.dart`): similar a admin, centrado en materias asignadas al docente.
- Estudiante/Familiar (`screens/student_schedule_screen.dart`): horario de grado del estudiante; familiares cambian estudiante activo; vista semanal/diaria.

### User (`lib/modules/user`)
- Servicio `user_service_v2.dart`: CRUD `users` por tenant; crea/elimina en Firebase Auth via Functions; historial `user_history`; validaciones de unicidad.
- Pantalla `admin_users_screen.dart`: listado + formulario (crear/editar/ver) respetando permisos y bloqueos (no borrarse a sí mismo).
- Formularios modularizados: `admin_user_form_widget.dart` (state en `admin_user_form_widget_state.dart`), `admin_user_form_body.dart` + secciones, `admin_user_form_controller.dart` para validaciones/subida de foto.

### Enrollment / Matrícula (`lib/modules/enrollment`)
- Configuración: `config/enrollment_fields.dart` define campos (roles con permiso de edición, defaults, fórmulas como edad) y `config/enrollment_sections.dart` agrupa los pasos/secciones visibles en el formulario.
- Modelos: `EnrollmentField`, `Enrollment` (estados `prematriculado`/`pendiente_revision`/`rechazado`/`matriculado`; fuente admin/padre/QR; token opcional para links públicos; metadata de revisión) y `SubmitResult` para encapsular resultado de guardado.
- Servicios/controlador: `enrollment_service.dart` (CRUD en `enrollments`, búsqueda por id/token/documento, conteo por estado); `controllers/enrollment_form_controller.dart` concentra estado/valores/prefill/opciones/submit; `services/enrollment_submit_handler.dart` maneja diálogos y PDF tras guardar.
- Formulario (`enrollment_form_screen.dart`): usa Provider + Stepper por secciones, paso inicial de documento con prellenado desde `users` o matrículas previas, cálculo de edad, control de edición por rol, selección de hijos vinculados (rol Familiar), bloqueo en lectura si ya está matriculado; chip de pendientes para admin.
- Panel admin (`admin_enrollment_screen.dart`): tabs por estado, aprobar/rechazar/editar, crear nueva; al aprobar genera PDF con datos principales.
- Rutas: `/enrollment_public` (QR/padre sin login) y `/enrollment` (admin abre panel; roles Familiar/Estudiante con permiso `matriculas.ver` abren el formulario). En el menú admin se muestra badge con pendientes `prematriculado/pendiente_revision` en vivo.

### Utils / Core
- `parameters_service.dart`: lee `parameters` (roles/grados/permisos/tipos de documento activos) y `getUsersByFilters`.
- `notification_service.dart`: wrapper Cloud Function `enviarNotificacion` (dedupe tokens, timeout).
- `push_notifications.dart`: inicializa FCM + `flutter_local_notifications`; handler `firebaseMessagingBackgroundHandler`.
- `firebase_utils.dart`: pide permiso FCM y guarda tokens (`arrayUnion`).
- `user_log_service.dart`: registra eventos (incluye entorno) y obtiene llaves de descargas.
- `dialog_utils.dart`: modales de info/exito/error reutilizables.
- `format_utils.dart`, `validators.dart`, `snackbar_utils.dart`, `color_utils.dart`.

### Config / Navegación / Estado
- `lib/app.dart`: rutas `go_router` y redirecciones por rol (`homeForRole`, `allowedForRole`).
- `widgets/push_bootstrap.dart`: inicialización de push en web con `webVapidKey`.
- `config/theme_config.dart`: carga remota de tema.
- `config/firebase_options.dart`: opciones actuales generadas por FlutterFire (usar este).

## Cómo correr
1. `flutter pub get`
2. Asegurar `lib/config/firebase_options.dart` apunta al proyecto Firebase deseado.
3. Plataformas activas: Android/iOS/Web (carpetas desktop eliminadas). Ejecutar `flutter run -d <device>`.

## Notas operativas
- Permisos FCM: `main.dart` llama `fRequestPermission` y registra background handler.
- Geolocalización docente: `LocationService` usa `Geolocator.getCurrentPosition(locationSettings: ...)` y `getPositionStream` con `AndroidSettings/LocationSettings`.
- Tokens FCM: deduplicación en `notification_service.dart`; `UserLogService` guarda claves descargadas para marcar vistos en vista de archivos.
- Patrón de diálogos: usar `DialogUtils` + `withValues` en colores (evitar `withOpacity` deprecado) para consistencia.
