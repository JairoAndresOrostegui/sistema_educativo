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

- Ruta: `files/{groupId}/{fileId}/{safeName}`.
- Cuota: 1 GiB por institución.
- Archivo individual: máximo 25 MiB.
- Tipos: PDF, Word y Excel aprobados.
- Retención: el superadministrador puede eliminar todo documento con más de 60 días.
- También puede seleccionar y eliminar manualmente sin importar fecha.
- La cuota reserva bytes antes de subir; confirmar mueve la reserva a bytes usados; cancelar o rechazar libera la reserva.

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

## Migraciones

No hay lectura dual del esquema anterior. `functions/scripts/migrate_academic_groups.js` ejecuta una migración única, seca por defecto y real con `--apply`. Antes de aplicar se debe validar el proyecto Firebase y conservar un respaldo administrado. Después se revisan conteos, referencias y objetos de Storage, y se eliminan los parámetros antiguos de grado.

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
```

QA se despliega con el alias Firebase `default` actual. Producción real debe usar otro proyecto y alias. Nunca reutilizar secretos, bucket o credenciales de QA en producción.
