# Guía de arquitectura y desarrollo

Manual técnico operativo y guías por perfil: [manuales](manuales/README.md).
Rutas usa ubicación privada y ventanas por estudiante; ver TECNICO.md antes de
modificar GPS. Sus anuncios operativos permanecen en Rutas, no en un nuevo chat.

## Propósito

El sistema atiende preescolar, primaria y bachillerato en una o varias instituciones y sedes. Flutter sirve web y Android; Firebase aporta Authentication, Firestore, Cloud Functions, Cloud Storage, Hosting y notificaciones.

## Modelo multiinstitución

La frontera de datos es institución + sede. Los documentos usan `institutionId/campusId` en módulos nuevos y `institution/campus` donde el modelo principal ya lo define. No se autorizan coincidencias por nombre únicamente. El superadministrador es el único actor transversal; un administrador normal queda limitado a su sede incluso si manipula una petición o URL.

### Grupos

`academic_groups` contiene:

- `institutionId`, `campusId`: propietario del grupo.
- `level`: nivel base, por ejemplo `Cuarto`.
- `section`: sección, por ejemplo `A` o `B`.
- `name`: etiqueta derivada, por ejemplo `Cuarto A`.
- `order`, `active`: orden académico y disponibilidad.

Las relaciones guardan `groupId` y una copia derivada `groupName`. La identidad siempre es `groupId`. Dos sedes pueden tener `Cuarto A`; son grupos distintos. Una sede puede tener `Cuarto A` y `Cuarto B`.

## Seguridad

La UI orienta, pero las reglas y Functions deciden. Los documentos sensibles no admiten escrituras directas. Cada función debe:

1. autenticar y cargar el perfil activo;
2. comprobar rol, permiso y sede;
3. validar tipos, tamaños y relaciones;
4. derivar nombres o datos de referencias confiables;
5. escribir la entidad y su historial de forma atómica;
6. notificar sin revertir la operación principal si solo falla FCM.

Cuando una operación cruza Auth, Firestore y Storage, debe implementar compensación y dejar un estado reintentable. Nunca borrar metadatos antes de confirmar que el objeto físico se eliminó.

Las contraseñas de estudiantes no se recuperan por correo. Administración genera
una clave temporal mediante backend y el estudiante debe cambiarla antes de usar
los módulos. Nunca guardar contraseñas temporales o definitivas en Firestore,
logs, notificaciones ni respuestas posteriores a la generación inicial.

## Estados relevantes

- Usuario: `activo`, `inactivo`, `eliminado`, `eliminando`.
- Matrícula: unicidad por `institution + data.numeroIdentidad + anioMatricula`; estados del flujo configurado; las correcciones respetan rol, sede e hijo activo. La creación, consulta familiar y transiciones sensibles pasan por Cloud Functions. Cada transición vuelve a leer y actualizar la matrícula en una transacción para impedir decisiones concurrentes contradictorias y escribe `enrollment_history`. El payload acepta únicamente el esquema vigente, deriva `institution`, `campus`, `groupId` y `groupName` en backend, y rechaza `grade`, `grado`, `gradoAspirado` y campos arbitrarios. El administrador queda fijado a su sede; solo el superadministrador envía un alcance distinto.
- Horario: `subjects` usa `institutionId`, `campusId`, `groupId`, `groupName`, docente, día, minutos de inicio/fin y `revision`. Crear, consultar, editar y eliminar pasa por Cloud Functions. `consultarHorarios` deriva el alcance: administrador en su sede por grupo o docente, superadministrador en la sede elegida, docente en sus clases o en grupos donde dicta, estudiante en su grupo y familiar en el grupo del hijo activo. La consulta administrativa por docente vuelve a validar que sea un docente activo de la sede; el identificador enviado por el cliente no amplía el alcance. Las mutaciones validan grupo y docente activos, rechazan campos arbitrarios, bloquean cruces de grupo o docente y comparan `expectedRevision` dentro de la transacción para impedir sobrescrituras concurrentes. Cada cambio escribe `schedule_history` de forma atómica.
- Autorización: `pending`, `approved`, `rejected`, `finalized`. Finalizada es inmutable, salvo corrección expresa del superadministrador con historial.
- Archivo: `uploading`, `active`, `deleting`.
- Canal de mensajería: `active`, `archived`; tipos `academic_group`, `service`
  y `private`. Los mensajes son inmutables y usan una secuencia ascendente.

## Familias con varios hijos

### Identificadores QR

`qr_credentials/{sha256(targetType:targetId)}` mantiene una credencial por
entidad. El payload `LLQ1:` seguido de 32 bytes aleatorios codificados base64url
es opaco. `tokenHash` permite buscarlo sin consultar perfiles por documento.
El servidor distingue `user` y `event`; no permite rutas arbitrarias del cliente.
Las colecciones de credenciales, eventos y auditoría QR no admiten acceso
directo desde el cliente (denegación por defecto en reglas).

Los usuarios activos obtienen su propio QR desde Perfil; familiares pueden
obtener el del hijo activo vinculado. Solo administradores con permisos QR,
o superadministrador, gestionan otras entidades. Cambiar sede invalida la
credencial hasta que se reemita para el nuevo alcance. Desactivar un usuario
impide resolverla; la eliminación definitiva borra su credencial en el mismo
lote final del usuario y conserva la auditoría histórica.

Revocar elimina payload y hash. Reemplazar genera otro secreto y el anterior
deja de resolverse. Una credencial revocada no se reactiva por solicitarla.
El vínculo familiar se consulta al resolver, nunca se congela en el QR.
La credencial identifica la cuenta, no prueba la identidad del portador:
una fotografía del símbolo se puede copiar. No usar como login o firma digital.

`events` admite inicialmente solo título, sede, año y propósito
`identification_only`; todavía no contiene asistencia, agenda, responsables ni
permisos de recogida. El QR de evento solo se resuelve en año activo y sede
autorizada. El futuro módulo de Eventos debe definir su audiencia y acciones,
integrar responsabilidades docentes y eliminación de su credencial antes de
permitir borrar eventos. No implementar eliminación directa del documento.

Migración única QA: `node functions/scripts/migrate_qr_identity.js` (diagnóstico)
y `--apply` para retirar campos antiguos de perfiles y reemplazar credenciales
previamente habilitadas. No acepta el JSON antiguo ni deja lectura dual.
Las nuevas credenciales se generan al solicitarlas, sin exigir carga masiva.
Validación: `npm run test:qr`, `npm run test:rules`, pruebas Flutter.
El lector de cámara y las operaciones por escaneo quedan fuera de esta etapa;
la pantalla actual ofrece validación manual del identificador.

`studentIds` contiene vínculos y `activeStudentId` el contexto actual. Horario, matrícula, autorizaciones, archivos, mensajería y todo módulo futuro por estudiante deben mostrar selector, persistir el hijo activo y volver a validar el vínculo en backend/reglas.

## Mensajería institucional

### Cola push y apertura

`push_events` guarda el aviso de Mensajería en la misma transacción del mensaje;
un trigger con reintento materializa `push_jobs` por identificador de evento y
lote (máximo 500 tokens). Un evento repetido no reinicia lotes ya existentes.
Archivos, Horarios, Matrículas, Autorizaciones y el envío genérico también usan
la cola; en esos flujos la encolación todavía ocurre después de la escritura
principal, no constituye una transacción distribuida con el dato de negocio.
El evento de negocio no se revierte si falla su notificación.

Los lotes usan una reserva temporal de 10 minutos para evitar procesamiento
concurrente, cinco intentos con espera creciente y recuperación programada
cada cinco minutos (hasta 20 lotes por ejecución). Solo se reenvían los tokens
con errores temporales. Antes de enviar se revalidan usuario activo, sede y
token vigente; en chats también se comprueba la membresía actual.
Si FCM acepta y el proceso muere antes de guardar el resultado, la entrega
puede repetirse: no se promete exactamente una entrega.

Las colecciones push son privadas al backend (denegación por defecto en reglas).
Las Functions del panel exigen `isSuperadmin`; retornan contadores y códigos,
nunca tokens, cuerpos ni credenciales. El reintento manual deja
`push_retry_audit`. No se elimina historial operativo automáticamente.
El planificador y las escrituras agregan consumo: no prometer costo cero.

`notificationDestination` solo admite destinos de Mensajería; una notificación
no concede acceso al canal. Las aperturas Android (frente, fondo y arranque)
y los enlaces web pasan por la navegación autenticada. `runtime_environment.js`
deriva el origen y la clave Auth del proyecto Firebase; rechaza proyectos
desconocidos y un `PUBLIC_APP_URL` que no coincida con su entorno.
El worker web no vuelve a mostrar payloads `notification` que FCM ya presenta.

Pruebas: `npm run test:push`, `npm run test:messaging`, `flutter test`.
FCM se simula en pruebas de cola; la recepción real y la apertura con el equipo
bloqueado requieren comprobación en dispositivos, no se deducen del emulador.

`message_channels` es la única fuente de canales. El canal académico se
identifica como `academic_{groupId}` y materializa estudiantes, familiares y
docentes vigentes. Las Functions recalculan miembros desde usuarios,
matrículas, horarios y dirección de grupo; el cliente nunca decide la
audiencia ni escribe mensajes, lecturas o silencios directamente.

El contacto particular entre un docente o administrador y un estudiante usa
un único canal `supervised_student`. Sus miembros son el estudiante, el miembro
del personal y todos los familiares activos vinculados al estudiante. La
audiencia se vuelve a materializar al enviar y cuando cambia un vínculo o el
estado de un usuario. El docente elige al estudiante, no a un familiar aislado;
así ninguna comunicación sobre un menor queda en un chat lateral incompleto.

Los privados entre estudiantes están prohibidos, incluso en canales creados
antes de esta regla. Contactos y envíos aplican la misma política. Los privados
entre familiares se identifican por pareja, año y `familyGroupId`: el hijo
activo del remitente y algún hijo activo vinculado al destinatario deben
pertenecer a ese grupo vigente y a la misma institución/sede. Se revalida en
cada envío y cada familiar responde con su propio contexto de hijo. Reabrir
un privado conserva secuencias, lecturas e historial.

`messageSequence` aumenta en transacción y `readSequences/readAtByUser`
mantienen el pendiente independiente de cada cuenta: la lectura de un familiar
no modifica al estudiante ni a los demás familiares. Cada mensaje conserva la
audiencia de envío y `readAtByUser/readNames/readRoles`; al abrir el canal se
registra la primera lectura exacta por mensaje. `mutedByAdmin`
convierte un canal colectivo en solo anuncios; no elimina contenido. Los
canales `service` son extensibles por categoría e icono y almacenan
comunicación, no el estado operativo del módulo que los origina.

Al ampliar Restaurante, Lonchera u otro módulo con chat, ese módulo conserva sus
entidades de negocio y publica o enlaza novedades con un canal de servicio.
No se crea una segunda colección de chats. Toda nueva carga docente debe
actualizar la sincronización de `REGISTRO_CARGA_DOCENTE.md`.
Excepción operativa acordada: los avisos del recorrido se gestionan y consultan
en Rutas, con eventos e historial, no como un chat de servicio.

## Archivos y Storage

- Ruta: `files/{fileId}/{safeName}`. La autorización se resuelve contra el documento `files/{fileId}`, no contra un segmento de ruta manipulable.
- Cuota: 1 GiB por institución.
- Archivo individual: máximo 25 MiB.
- Tipos: PDF, Word y Excel aprobados.
- Retención: el superadministrador puede eliminar todo documento con más de 60 días.
- También puede seleccionar y eliminar manualmente sin importar fecha.
- La cuota reserva bytes antes de subir; confirmar mueve la reserva a bytes usados; cancelar o rechazar libera la reserva.
- Una publicación usa `audienceType` (`all`, `groups`, `students`), `targetGroupIds`, `targetStudentIds`, `recipientUserIds` y `recipientContextKeys`. La última lista enlaza familiar e hijo para que la consulta respete el hijo activo. Estas listas se derivan y validan en backend; nunca se aceptan nombres ni destinatarios confiando en el cliente.
- El cliente lista mediante `listarArchivos`; la Function valida rol, permiso, sede y, para Familiar, que el hijo solicitado sea el vínculo activo. Firestore no permite listar `files` directamente, aunque sí protege la lectura puntual que necesita Storage.
- El mensaje opcional admite hasta 2000 caracteres y puede ser texto o un enlace. `sentAt` registra el momento de confirmación del archivo.
- `file_download_receipts` registra por archivo y usuario la primera y última solicitud de descarga y su contador. Solo el remitente, administración y superadministración consultan el resumen; el cliente no escribe acuses directamente. Iniciar la descarga no garantiza que el sistema operativo haya guardado o abierto correctamente el archivo.
- El docente obtiene sus grupos desde `subjects.teacherId`; no se limita a un único `groupId` del perfil. Solo administradores eliminan, y nunca se ofrece borrado u ocultamiento a docentes.

1 GiB permite atender la carga documental de ambas sedes y equivale a cerca del 20 % de una cuota sin costo de 5 GB. Todavía deja espacio para perfiles, contenido web y futuros recursos. La aplicación no promete costo cero: el proyecto debe estar en Blaze para Cloud Storage y el consumo real se vigila en Firebase/Google Cloud.

## Tema visual

`website/config` es la fuente de marca para `primaryColor` y `fontFamily`; el pie aporta su color oscuro. `configuracion_colegios` conserva nombre y logo institucional. `ThemeProvider.themeData` traduce esa información a Material 3.

Reglas:

- consumir `Theme.of(context).colorScheme`;
- usar `primary` para marca, `error` para errores y superficies del esquema para fondos;
- no declarar colores de marca en cada pantalla;
- si se necesita un token nuevo, agregarlo centralmente y documentarlo;
- mantener la página pública y los módulos autenticados visualmente coherentes.
- usar en todos los módulos revisados o nuevos la misma cabecera de Perfil: superficie sólida, título centrado, color primario y regreso visible al tablero;
- evitar degradados en módulos internos y preferir superficies sólidas del `ColorScheme`;
- diseñar formularios desde 320 px: los desplegables usan `isExpanded`, los textos largos envuelven o muestran elipsis y las acciones pasan a `Wrap` o menú contextual antes de desbordarse;
- todo diálogo largo debe tener alto acotado, desplazamiento vertical, margen para el teclado y controles táctiles de al menos 48 px;
- una tabla operativa debe transformarse en tarjetas o admitir desplazamiento horizontal explícito en móvil; nunca reducir texto hasta volverlo ilegible;
- añadir una prueba de widget con viewport móvil para cada maquetación nueva que combine formularios, tablas o acciones múltiples;

## Constructor del sitio público

El esquema canónico es la versión 5. `website/config` contiene identidad, tema, navegación, redes, `header.rows` y `footer.rows`; cada documento de `website_pages` contiene `rows`. La jerarquía es `WebsiteRow -> WebsiteColumn -> WebsiteComponent`. No volver a introducir `blocks`, `sections` ni lectura dual del esquema anterior.

Una fila admite máximo cuatro columnas. Las columnas usan `span` relativo y en móvil se apilan cuando `stackOnMobile` está activo. Cada componente separa `widthPercent` y `componentAlignment` —posición del bloque dentro de la columna— de `alignment`, que solo alinea su contenido. Los componentes disponibles se centralizan en el modelo y el editor; cualquier tipo nuevo debe implementar serialización, edición, render adaptable y prueba.

Los componentes deslizantes deben ofrecer controles manuales accesibles además de reproducción automática o gestos. El carrusel usa flechas anterior/siguiente, indicadores y conserva el gesto táctil. En vista móvil se limitan espacios interiores excesivos y el texto superpuesto se trunca de manera legible para no cubrir los controles.

Los videos aceptan exclusivamente URL HTTPS reconocida de YouTube o Vimeo. El render web transforma la URL a un `iframe` seguro y sin HTML suministrado por el administrador. No se suben videos a Storage. Las imágenes continúan bajo `website/`, con tamaño y MIME protegidos por reglas.

Al publicar, las rutas de imágenes obsoletas y los reintentos anteriores se guardan primero en `website/config.pendingAssetCleanup` dentro del mismo lote que actualiza las páginas. Storage se limpia después; solo las rutas fallidas permanecen en la cola. Si falla la actualización final, la cola completa se conserva y el siguiente intento tolera `object-not-found`. Las cargas nuevas descartadas en el editor se eliminan de inmediato o vuelven a intentarse al cerrar.

`primaryColor` y `fontFamily` son globales y pueden afectar los módulos internos. Los colores de filas, columnas y componentes pertenecen solo al sitio público. El administrador elige colores mediante una paleta visual; el hexadecimal es una opción avanzada, no el control principal.

## Migraciones

### Revisión de Rutas y dispositivos (septiembre de 2026)

`functions/routes.js` centraliza plantillas, preparación, operación, historial,
conductores y cambios de parada. Las escrituras directas de Rutas se deniegan.
`route_push_events` es outbox transaccional; los avisos genéricos de tipo route
se rechazan. `route_history` no expone otros hijos al familiar.
Las estimaciones por parada se guardan en el documento de cada estudiante,
nunca en el padre del recorrido que leen todas las familias.

`push_device_sessions/{uid}` guarda hashes de sesión por slot, no accesibles
al cliente. `gestionarDispositivoPush` compara sesión y auth_time verificado por
Firebase. Un empate de segundo entre logins diferentes exige repetir login;
no se resuelve dejando que una sesión antigua reclame el dispositivo nuevo.
El botón de Inicio puede solicitar permiso o guiar a Ajustes, no revocar ni
conceder permisos del sistema operativo por su cuenta.

Migración QA: `node functions/scripts/migrate_route_security.js` (diagnóstico),
`--apply` (retira campos antiguos de tokens/dirección y registra rol Auxiliar).
Los registros QR y vínculos de hijos no cambian. No se eliminan rutas históricas.
`MAPS_ROUTING_ENABLED` permanece desactivado mientras no se habiliten API,
facturación y permisos restringidos del servidor. El límite actual de cálculos
es 100/día/proyecto; no equivale a un presupuesto de todas las APIs de Google.
Ver [REVISION_RUTAS_Y_PUSH.md](REVISION_RUTAS_Y_PUSH.md) para límites pendientes.

No hay lectura dual del esquema anterior. `functions/scripts/migrate_academic_groups.js` migra grupos y normaliza horarios, `functions/scripts/migrate_file_audiences.js` migra las audiencias de Archivos, `functions/scripts/migrate_messaging_channels.js` convierte conversaciones y crea canales académicos, y `functions/scripts/migrate_website_builder_v5.js` convierte el sitio a filas, columnas y componentes. Son secas por defecto, reales con `--apply` y verificables con `--verify`.

## Validación y despliegue

Comandos mínimos:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
Set-Location functions
npm ci
npm run lint
npm run test:rules
npm run test:auth
npm run test:users
npm run test:enrollment
npm run test:authorization
npm run test:schedule
npm run test:files
```

## Contexto universal de año lectivo

Toda colección operativa incluye `academicYearId` y `academicYear`, además de
institución y sede. Las escrituras solo se permiten sobre el año `active`; los
administradores pueden consultar períodos cerrados en modo lectura. Nunca se
usa el año del reloj como sustituto silencioso de la configuración.

Todo módulo con responsabilidad docente debe cumplir y actualizar el contrato
de [REGISTRO_CARGA_DOCENTE.md](REGISTRO_CARGA_DOCENTE.md).

QA se despliega con el alias Firebase `default` actual. Producción real debe usar otro proyecto y alias. Nunca reutilizar secretos, bucket o credenciales de QA en producción.

La separación usa `APP_ENV=qa|prod` y sabores Android `qa|prod` que deben coincidir.
Web se construye con `node tools/build_web.js qa|prod`, incluyendo el worker del
mismo proyecto. No publicar una compilación web cruda de Flutter como producción.
Consultar [SEPARACION_QA_PRODUCCION.md](SEPARACION_QA_PRODUCCION.md) antes de generar
artefactos o desplegar. VAPID y Maps de producción nunca heredan valores de QA.
