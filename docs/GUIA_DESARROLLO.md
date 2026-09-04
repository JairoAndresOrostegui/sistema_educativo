# Guía de arquitectura y desarrollo

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

## Estados relevantes

- Usuario: `activo`, `inactivo`, `eliminado`, `eliminando`.
- Matrícula: unicidad por `institution + data.numeroIdentidad + anioMatricula`; estados del flujo configurado; las correcciones respetan rol, sede e hijo activo. La creación, consulta familiar y transiciones sensibles pasan por Cloud Functions. Cada transición vuelve a leer y actualizar la matrícula en una transacción para impedir decisiones concurrentes contradictorias y escribe `enrollment_history`. El payload acepta únicamente el esquema vigente, deriva `institution`, `campus`, `groupId` y `groupName` en backend, y rechaza `grade`, `grado`, `gradoAspirado` y campos arbitrarios. El administrador queda fijado a su sede; solo el superadministrador envía un alcance distinto.
- Horario: `subjects` usa `institutionId`, `campusId`, `groupId`, `groupName`, docente, día, minutos de inicio/fin y `revision`. Crear, consultar, editar y eliminar pasa por Cloud Functions. `consultarHorarios` deriva el alcance: administrador en su sede por grupo o docente, superadministrador en la sede elegida, docente en sus clases o en grupos donde dicta, estudiante en su grupo y familiar en el grupo del hijo activo. La consulta administrativa por docente vuelve a validar que sea un docente activo de la sede; el identificador enviado por el cliente no amplía el alcance. Las mutaciones validan grupo y docente activos, rechazan campos arbitrarios, bloquean cruces de grupo o docente y comparan `expectedRevision` dentro de la transacción para impedir sobrescrituras concurrentes. Cada cambio escribe `schedule_history` de forma atómica.
- Autorización: `pending`, `approved`, `rejected`, `finalized`. Finalizada es inmutable, salvo corrección expresa del superadministrador con historial.
- Archivo: `uploading`, `active`, `deleting`.
- Canal de mensajería: `active`, `archived`; tipos `academic_group`, `service`
  y `private`. Los mensajes son inmutables y usan una secuencia ascendente.

## Familias con varios hijos

`studentIds` contiene vínculos y `activeStudentId` el contexto actual. Horario, matrícula, autorizaciones, archivos, mensajería y todo módulo futuro por estudiante deben mostrar selector, persistir el hijo activo y volver a validar el vínculo en backend/reglas.

## Mensajería institucional

`message_channels` es la única fuente de canales. El canal académico se
identifica como `academic_{groupId}` y materializa estudiantes, familiares y
docentes vigentes. Las Functions recalculan miembros desde usuarios,
matrículas, horarios y dirección de grupo; el cliente nunca decide la
audiencia ni escribe mensajes, lecturas o silencios directamente.

`messageSequence` aumenta en transacción y `readSequences/readAtByUser`
permiten obtener el número exacto de mensajes pendientes y los acuses de
lectura sin crear una escritura por destinatario al enviar. `mutedByAdmin`
convierte un canal colectivo en solo anuncios; no elimina contenido. Los
canales `service` son extensibles por categoría e icono y almacenan
comunicación, no el estado operativo del módulo que los origina.

Al ampliar Rutas, Restaurante, Lonchera u otro módulo, ese módulo conserva sus
entidades de negocio y publica o enlaza novedades con un canal de servicio.
No se crea una segunda colección de chats. Toda nueva carga docente debe
actualizar la sincronización de `REGISTRO_CARGA_DOCENTE.md`.

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
