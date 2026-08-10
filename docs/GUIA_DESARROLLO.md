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
- Matrícula: estados del flujo configurado; las correcciones respetan rol y sede.
- Autorización: `pending`, `approved`, `rejected`, `finalized`. Finalizada es inmutable, salvo corrección expresa del superadministrador con historial.
- Archivo: `uploading`, `active`, `deleting`.

## Familias con varios hijos

`studentIds` contiene vínculos y `activeStudentId` el contexto actual. Horario, matrícula, autorizaciones, archivos, mensajería y todo módulo futuro por estudiante deben mostrar selector, persistir el hijo activo y volver a validar el vínculo en backend/reglas.

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

## Constructor del sitio público

El esquema canónico es la versión 5. `website/config` contiene identidad, tema, navegación, redes, `header.rows` y `footer.rows`; cada documento de `website_pages` contiene `rows`. La jerarquía es `WebsiteRow -> WebsiteColumn -> WebsiteComponent`. No volver a introducir `blocks`, `sections` ni lectura dual del esquema anterior.

Una fila admite máximo cuatro columnas. Las columnas usan `span` relativo y en móvil se apilan cuando `stackOnMobile` está activo. Cada componente separa `widthPercent` y `componentAlignment` —posición del bloque dentro de la columna— de `alignment`, que solo alinea su contenido. Los componentes disponibles se centralizan en el modelo y el editor; cualquier tipo nuevo debe implementar serialización, edición, render adaptable y prueba.

Los videos aceptan exclusivamente URL HTTPS reconocida de YouTube o Vimeo. El render web transforma la URL a un `iframe` seguro y sin HTML suministrado por el administrador. No se suben videos a Storage. Las imágenes continúan bajo `website/`, con tamaño y MIME protegidos por reglas.

Al publicar, las rutas de imágenes obsoletas y los reintentos anteriores se guardan primero en `website/config.pendingAssetCleanup` dentro del mismo lote que actualiza las páginas. Storage se limpia después; solo las rutas fallidas permanecen en la cola. Si falla la actualización final, la cola completa se conserva y el siguiente intento tolera `object-not-found`. Las cargas nuevas descartadas en el editor se eliminan de inmediato o vuelven a intentarse al cerrar.

`primaryColor` y `fontFamily` son globales y pueden afectar los módulos internos. Los colores de filas, columnas y componentes pertenecen solo al sitio público. El administrador elige colores mediante una paleta visual; el hexadecimal es una opción avanzada, no el control principal.

## Migraciones

No hay lectura dual del esquema anterior. `functions/scripts/migrate_academic_groups.js` migra grupos, `functions/scripts/migrate_file_audiences.js` migra las audiencias de Archivos y `functions/scripts/migrate_website_builder_v5.js` convierte el sitio de bloques a filas, columnas y componentes. Son secas por defecto, reales con `--apply` y verificables con `--verify`. La migración web guarda `website/config` y cada página anterior en `migration_backups` antes de reemplazarlos mediante un lote atómico.

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

QA se despliega con el alias Firebase `default` actual. Producción real debe usar otro proyecto y alias. Nunca reutilizar secretos, bucket o credenciales de QA en producción.
