# Manual técnico y de operación

## Fuentes y entorno

Contador de autorizaciones: `allCampuses` es explícito para superadmin; enumera
`academic_year_settings` y suma streams por institución/sede/año activo, sin
pasar scopes nulos ni quitar filtros. Firestore mantiene la autorización real.
`sumCountStreams` propaga errores y cancela todas sus suscripciones al salir.
El tablero captura errores del contador y libera también la suscripción de
mensajes al desmontarse. Pruebas: cero sedes, suma reactiva, errores y cancelación.

Leer AGENTS.md, [GUIA_DESARROLLO](../GUIA_DESARROLLO.md),
[REGISTRO_CARGA_DOCENTE](../REGISTRO_CARGA_DOCENTE.md) y el manual del perfil
antes de modificar módulos. Inventario funcional en [README](README.md).
Flutter sirve Android/web. Auth autentica; Firestore almacena; Functions valida
mutaciones; Storage conserva archivos; FCM transporta avisos. Firebase actual es
QA: sistema-educativo-rl. No usarlo como producción definitiva ni afirmar que el
APK local está publicado en Google Play.

Producción independiente: `sistema-educativo-rl-prod`. La configuración y el
estado de puesta en marcha se mantienen en
[SEPARACION_QA_PRODUCCION](../SEPARACION_QA_PRODUCCION.md). No confundir cuentas
importadas con un despliegue listo para uso. La migración inicial conserva UID y
contraseñas mediante SCRYPT en memoria, prepara perfiles inactivos y habilita el
conjunto solo después de verificar Auth y relaciones. Auditoría en
`migration_audit/production_core_v1`; no ejecutar borrados para reintentar.
`node functions/scripts/verify_production_core.js` verifica el estado inicial
limpio; después de iniciar operación real sus comprobaciones de colecciones
vacías dejarán de ser aplicables y no deben usarse para justificar limpiezas.

La recuperación estudiantil usa `restablecerClaveEstudiante` y
`cambiarClaveTemporalEstudiante`. La primera exige administrador con
`usuarios.editar`, sede coincidente y estudiante activo; marca primero el perfil,
actualiza Auth, revoca sesiones anteriores y registra auditoría sin almacenar la
clave. `getCaller` y las reglas bloquean los demás módulos mientras
`mustChangePassword` sea verdadero. La segunda solo admite al propio estudiante,
aplica la política de complejidad y elimina la marca junto con un log atómico.
Como actualizar la contraseña mediante Admin SDK invalida la credencial vigente,
el cliente crea inmediatamente una sesión nueva con la contraseña elegida; no
intenta refrescar el token anterior ni presenta esa invalidación como un fallo
del cambio de contraseña.
Una falla de Auth revierte la marca; una falla posterior de auditoría conserva
la cuenta bloqueada para que administración repita la generación con seguridad.
Una clave temporal completada pero todavía no sustituida puede rotarse; el
marcador `passwordResetCompletedAt` diferencia esa rotación de una operación
concurrente aún en curso.

La migración de contenido visual usa `migrate_production_assets.js`: copia solo
objetos referenciados por el sitio y perfiles aprobados, valida generación y
CRC32C, registra el manifiesto antes de copiar y publica referencias al terminar.
No reutiliza URLs/tokens de QA ni borra el origen. Verificar con
`verify_production_assets.js`. Una foto cuyo objeto original falta queda vacía
y pendiente, nunca se sustituye silenciosamente por la de otra persona.

Los perfiles `users/{uid}` usan `revision` para edición optimista. La creación y
edición administrativa reservan documento, correo personal y correo institucional
en `user_unique_keys`; perfil, directorio, estado e historial se confirman como una
sola operación lógica. La foto se carga primero en `fotos_perfil/{uid}/...` y
`actualizarFotoPerfil` valida propietario, ruta, bucket, tipo, tamaño y revisión
antes de publicar la URL; si la confirmación falla, el cliente intenta retirar el
objeto recién cargado. La selección de hijo activo vuelve a validar vínculos y
estado dentro de una transacción y actualiza también el directorio.

## Contrato transversal por módulo

| Área | Modelo / operación | Invariantes |
|---|---|---|
| Auth/Perfil | users, Firebase Auth, campos seguros | Estado activo; adulto verifica correo; estudiante no |
| Usuarios | Functions e historial, cascada controlada | Admin sede; superadmin definitiva; no huérfanos |
| Grupos | academic_groups, groupId | Institución/sede/año; no grade/grado libre |
| Años | academic_years, academic_year_settings | Un activo por sede, cerrado sin escrituras |
| Matrículas | enrollments, enrollment_history | Unicidad, transición transaccional e hijo validado |
| Autorizaciones | historial y estados | Familiar solo ver/solicitar, finalized inmutable salvo super |
| Horarios | subjects, schedule_history | Cruces, expectedRevision, docente y grupo activos |
| Archivos | files, cuota, Storage y file_download_receipts | Reserva, confirmación, acuse por cuenta, borrar objeto antes de metadatos |
| Mensajería | message_channels, mensajes/lecturas, message_attachments | Miembros derivados, `supervised_student`, secuencia, lectura y descarga por cuenta; adjuntos comparten cuota/retención; administrador normal solo accede a colectivos materializados o particulares propios |
| QR | qr_credentials, events, qr_audit | Token opaco `LLQ1`, cámara/manual, revisión optimista, revocación recuperable por reemplazo, año/sede vigentes y sin autorización implícita |
| Asistencia | attendance_sessions, attendance_records, attendance_history | Lista congelada, sesión única, revisión optimista, cierre completo, consulta propia e hijo activo; escritura solo por Functions |
| Eventos | school_events, event_responses, event_attendance, event_history | Audiencia y responsables revalidados al publicar, año activo, cupo transaccional y asistencia auditada |
| Web | website/config, website_pages | Esquema v5, filas/columnas, tema central, limpieza reintentable |
| Rutas | routes, daily_routes, route_history | Ruta vigente y versionada, estudiantes activos sin duplicar, baja lógica, operador asignado y paradas bloqueadas al iniciar |
| Push | push_events/route_push_events, push_jobs | Lotes 500, reintento, audiencia y tokens revalidados, invalidación terminal segura y sin garantía de entrega |
| Historial | user_history, user_logs, file_history, schedule_history, route_history, daily_routes | Solo lectura, alcance por sede, filtros paginados completos y exportación explícita de visibles |

Esquemas exactos y permisos se verifican en Functions/reglas; una fila no reemplaza
validación de payload. No agregar escritura directa del cliente por conveniencia.

Sitio web usa alcance institucional en configuración, páginas, imágenes y
formularios. `revision` serializa publicaciones concurrentes y el backend
resuelve `contactForm` exclusivamente en `rows/columns/components` de una página
activa. Migrar documentos existentes con `migrate_website_scope.js` antes de
publicar las reglas correspondientes.

Las autorizaciones usan `revision` y todas las transiciones se confirman en una
transacción junto con `authorization_history`. Una copia desactualizada nunca
puede aprobar, rechazar o finalizar sobre otra decisión. El familiar debe tener
al estudiante activo, vinculado y seleccionado tanto para crear como para
corregir; Firestore aplica el mismo hijo seleccionado a la lectura directa.

Configuración académica significa grupos y años lectivos bajo alcance
institucional. `parametros.ver` permite consultar y `parametros.editar` permite
modificar mediante Functions. El administrador normal siempre usa su propia sede;
solo el superadministrador puede seleccionarla. Las escrituras directas del
cliente en `parameters` están denegadas. `eps` y `documentType` se administran
exclusivamente mediante Functions: se conserva el valor interno, se usa baja
lógica y se audita en `parameter_history`. Solo el superadministrador modifica
estos catálogos globales. Roles, permisos y banderas técnicas no forman parte
del CRUD de la interfaz y se cambian mediante migraciones versionadas.
Cada entrada administrable incluye `revision`; una edición desactualizada se
rechaza sin perder el valor vigente y el historial se escribe en la misma
transacción. Los grupos reservan de forma determinista la combinación normalizada
institución/sede/año/nombre en `academic_group_unique_keys`, por lo que dos altas
simultáneas no pueden crear duplicados. Sus ediciones también requieren revisión.
`configuracion_colegios` es pública solo para lectura de marca; ninguna cuenta
cliente puede escribir allí mediante Firestore.
La normalización oficial se ejecuta con `sync_colombia_catalogs.js`: conserva
opciones antiguas como inactivas, normaliza códigos usados y deja respaldo.

Antes de publicar este cambio se ejecuta en seco y luego se aplica la migración
idempotente de permisos:

```text
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto>
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto> --apply
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto> --verify
```

La eliminación de grupos es excepcional: solo superadministrador, grupo inactivo,
impacto previo sin relaciones, confirmación y registro en
`academic_group_history`. La operación se detiene si cualquier validación falla.

## Rutas: ventana privada de ubicación

El documento daily_routes conserva estado general, no GPS. La ubicación actual está
en daily_routes/{id}/live/location. Cada students/{id} tiene estimatedArrivalAt,
mapEnabled y, al abrir por avance, approachNotifiedAt. No almacenar listas de
direcciones/estimaciones ajenas en el documento que comparten familias.

operarRecorrido valida usuario, sede, asignación, año, estado e idempotencia.
position escribe ubicación y evalúa todas las estimaciones <= ahora + 10 minutos.
Cada parada abre una sola vez y crea un evento agrupado; nuevos GPS no repiten el
aviso. eta/arrival manuales ya notifican, abren directamente si corresponde y no
generan un segundo push de aproximación en esa misma operación.
pickup/absent ponen mapEnabled=false; reglas además comprueban asistencia vigente.
finish elimina ubicación y revoca acceso por estado de recorrido.

Reglas de live: usuario activo, rutas.ver, misma sede, recorrido activo; admin o
responsable asignado, o estudiante/familiar del hijo activo vinculado con ventana
abierta y aún pendiente. No basta con ocultar el mapa. Un documento antiguo que
aún tenga teacherPosition en el padre no se expone a familias.
El cliente solo suscribe live mientras la ventana está abierta; ante error no usa
un marcador previamente guardado para otro hijo. Los datos ya vistos/capturados
no pueden borrarse del dispositivo de una persona, pero no recibe posiciones nuevas.

## Estimación económica y límites

calcularTiemposRuta usa un cálculo de ruta completo, no uno por espectador. El
cliente lo solicita al iniciar en automático; no existe timer de cinco minutos
ni recálculo al recoger. El responsable puede volver a solicitar con confirmación.
MAPS_ROUTING_ENABLED sigue desactivado hasta verificar API, facturación e identidad
de servidor. La cuota implementada es 100 cálculos/día/proyecto, no presupuesto total.

Se guarda hora estimada, no se consulta tráfico por cada GPS. La ventana se evalúa
con posiciones recibidas y al calcular/avisar. Sin GPS/red puede retrasarse; una
estimación sin recálculo puede perder precisión. No prometer aviso exactamente
10 minutos antes. Una ventana abierta permanece ante demora hasta resolver parada.
El responsable puede avisar manualmente si no hay Maps. Ubicación filtrada a no
más de una publicación cada 30 segundos; parado puede tardar más por filtro GPS.

Avisos generales: comando announcement, solo operador autorizado durante recorrido
activo. Texto máximo 500, evento y route_history atómicos; audiencia incluye niños
activos del recorrido ya recogidos. Se consulta en Rutas. No es otra colección de
chat ni canal de Mensajería. No traslada authored/performedBy a un sustituto.

## Migración y despliegue

1. git status; preservar cambios ajenos. Identificar proyecto QA explícitamente.
2. Ejecutar tests/lint/analyze, compilar antes de publicar.
3. node functions/scripts/migrate_route_security.js: diagnóstico. --apply retira
   campos antiguos de tokens y GPS del padre; no borra asistencia ni recorridos.
4. Publicar Functions operarRecorrido/calcularTiemposRuta y reglas. No eliminar
   índices remotos con --force sin revisar qué se retiraría.
5. Publicar frontend compilado y regenerar APK ARM64 para Z Flip7.
6. Verificar migración seca sin pendientes, versiones remotas y pruebas físicas.

No hay lectura dual de ubicación. Un cliente anterior puede dejar de mostrar mapa;
actualizar web/APK de QA. No revertir reglas a una versión que exponga GPS general.
Ante error de migración parar publicación y conservar evidencia; no reparar borrando
documentos institucionales. Credenciales temporales se limpian sin imprimirlas.

## Comandos de validación

```powershell
dart format lib test
flutter analyze
flutter test
npm --prefix functions run lint
npm --prefix functions run test:routes
npm --prefix functions run test:rules
flutter build apk --release --split-per-abi
flutter build web --release
```

Para cambios en otros módulos ejecutar además suites auth/users/enrollment/
authorization/schedule/files/messaging/qr/push relevantes. Pruebas de emuladores
no confirman GPS físico, notificación visible ni aceptación de Google Play.

## Matriz de aceptación Rutas

### Estados seguros de interfaz y backend

- Sin ruta asignada: mostrar estado vacío; no intentar leer GPS ni dibujar mapa.
- Pendiente: permitir consulta y cambios autorizados; indicar que aún no inicia.
- Activa fuera de ventana: ocultar GPS y explicar el límite de diez minutos.
- Activa dentro de ventana: mostrar la última ubicación válida; un documento aún
  sin coordenadas es un estado de espera, no un error.
- Recogido, ausente, finalizada o cancelada: revocar mapa inmediatamente y
  conservar el historial permitido.
- Estado o documento corrupto: responder con error de dominio controlado; nunca
  propagar `FirebaseException`, stack trace, cast ni pantalla roja al usuario.
- Fallo temporal de red/Maps: mantener la operación institucional guardada,
  informar disponibilidad temporal y ofrecer reintento cuando corresponda.

- Admin otra sede, docente ajeno, familiar con hijo ajeno: denegación.
- Antes de 10 minutos: GPS denegado incluso por SDK directo.
- Dos paradas a 8/9 minutos: ambas abiertas; misma dirección avisa agrupado.
- GPS repetido: no duplica aviso. ETA manual >10 no abre inmediatamente.
- Trancón después de abrir: no cierra ventana; recálculo solo solicitado.
- Recogido/ausente/finalizada: revoca GPS; historial sigue consultable.
- Otro hijo: no hereda ventana ni marcador del anterior.
- Anuncio después de recogida: sigue en audiencia e historial; no obliga a chat.
- Móvil/web/ambos/ninguno: estados válidos. Logout antiguo no borra token nuevo.
- Pantalla bloqueada, GPS apagado, sin red, app reiniciada: probar Z Flip7.
- Medir lecturas/escrituras/Functions y Maps por recorrido; estimaciones no son factura.

## Eventos y Asistencia: controles de entrega y volumen

`academic_push_access.js` revalida cada envío y reintento contra el outbox
identificado por `push_jobs.notificationEventId`. La sede, institución, año y
entidad deben coincidir. Sin origen verificable se omite el envío; nunca se
amplía la audiencia recurriendo a todo el grupo.

En Asistencia se intersectan los estudiantes de la novedad original con la
lista cerrada. En Eventos se conservan los destinatarios originales y se
comprueban responsables actuales, estudiantes activos y vínculos familiares.
El hijo seleccionado no limita avisos sobre otros hijos vinculados. Un cambio
de token, permisos, estado o vínculo puede omitir un destinatario pendiente.

Los recordatorios de Eventos paginan en bloques de 500 y dejan un outbox
determinista por evento; pasar por eventos ya recordados no oculta la página
siguiente. Se recalculan vínculos actuales sin reescribir la audiencia histórica.
Listados y reportes dejan de truncarse silenciosamente: Eventos admite hasta
2000 eventos por consulta y Asistencia hasta 5000 registros; sobrepasarlos
devuelve un límite explícito. Los reportes filtran fechas en la consulta y
Asistencia permite reducir por grupo. La asistencia de un evento se guarda en
solicitudes de hasta 400 marcas, cada una con su revisión y auditoría.

Pruebas específicas: `npm run test:events`, `npm run test:attendance` y
`node node_modules/mocha/bin/mocha.js test/academic_push_access.test.js` desde
Functions. Los emuladores no prueban recepción física de FCM.

## Descargas privadas de Archivos y Mensajería

Los documentos se descargan mediante `descargarArchivoProtegido?fileId=...`
y `descargarAdjuntoProtegido?attachmentId=...`, con el ID token de Firebase en
`Authorization: Bearer ...`. No se generan URL públicas, firmadas ni tokens
permanentes de Storage. GET no registra lecturas ni descargas: los acuses por
cuenta conservan sus operaciones independientes, después de recibir el archivo.
Las dos confirmaciones de carga revocan `firebaseStorageDownloadTokens` antes
de publicar o adjuntar, con precondiciones de generación y metageneración.
Se conservan las demás claves de metadata. Si Storage no confirma la revocación,
la reserva permanece pendiente, sin contabilizarla como archivo confirmado,
para reintentar o cancelar. El emulador Storage de Firebase CLI 15.9 mantiene
los tokens en una lista separada y no reproduce su eliminación vía metadata;
las pruebas verifican el rechazo seguro en ese caso. La migración QA verificó
la eliminación real en cuatro objetos conservando sus generaciones y contenido.

El backend comprueba sesión, perfil activo, permisos, institución, sede y
audiencia antes y después de leer el objeto. Para perfiles no administrativos
exige año vigente; los familiares deben seleccionar un hijo activo vinculado.
Los adjuntos revalidan el canal y sus relaciones actuales, aunque una membresía
materializada antigua todavía contenga al usuario. CORS permite solamente los
dominios del ambiente actual; Android usa el mismo token sin necesitar Origin.

La lectura usa una generación fija y verifica ruta, MIME y tamaño confirmado.
Se acumula como máximo 25 MiB, con contador incremental y rechazo del exceso,
antes de responder una sola vez. Functions de segunda generación admite 32 MiB
en respuesta no streaming, pero solo 10 MiB en streaming; por eso no se conecta
el stream de Storage directamente a HTTP. Cada instancia usa 512 MiB y admite
cuatro descargas simultáneas. La respuesta es privada, sin caché y con nombre
de descarga saneado. No se duplican lecturas del contenido: se consultan los
metadatos una vez y se descarga una vez; sí se repiten las comprobaciones de
acceso. Este control añade invocaciones, lecturas de Firestore, CPU/memoria y
tráfico saliente de Functions; no debe presupuestarse como descarga gratuita.

Pruebas: `test/protected_downloads.test.js` (límites y metadatos) y
`test/protected_downloads.function.test.js` (Auth, Firestore, Storage y HTTP).
Referencia del límite: [cuotas de Cloud Functions](https://firebase.google.com/docs/functions/quotas).

## Pendientes funcionales que no deben ocultarse

Paradas como entidades con coordenadas/Places, planificación futura, ida/regreso,
relevo de auxiliar, cola offline con conflictos e historial antiguo unificado.
La agrupación actual sigue siendo por texto de dirección normalizado, no distancia.
Automático real necesita habilitación y prueba de Google, no basta con compilar.
Cola sin conexión y ayuda de asistencia por QR siguen pendientes. Eventos ya es
operativo mediante Functions, reglas cerradas, historial, audiencia materializada,
confirmación familiar, cupo, asistencia y reporte; su QR continúa siendo solo un
identificador. Entregas por QR y lonchera/restaurante operativos no están
finalizados. Inventariar y ocultar entradas incompletas antes de release.

## Google Play

1. Abrir el aviso de inactividad en Play Console y comprobar fecha/tareas exactas;
   no confundirlo con registro de paquetes ya resuelto. Si sigue el plazo de la
   captura (19 de septiembre), no esperar a terminar funciones futuras.
2. Leer causa concreta del rechazo anterior. Verificar applicationId contra la
   ficha existente: el APK actual usa co.edu.liceobilinguerodolfollinas.sistemaeducativo,
   diferente del paquete mostrado en aquella captura. No cambiarlo ni crear otra
   ficha sin decidir estrategia con el propietario.
3. Confirmar firma de carga/Play App Signing, versionCode creciente, target API
   requerido en consola, compatibilidad de bibliotecas nativas/páginas de memoria,
   AAB firmado y reporte previo al lanzamiento. No enviar keystore/contraseñas por chat.
4. Validar login de revisor, rutas, mapa, notificaciones, permisos solo cuando se
   necesitan, consumo en segundo plano y cierre de sesión. No pedir GPS a familias
   para ver la posición del vehículo ni prometer seguimiento infalible.
5. Completar política de privacidad pública, seguridad de datos, audiencia/menores,
   eliminación de cuenta cuando aplique, clasificación, acceso restringido,
   declaraciones de permisos/servicios y ficha/capturas reales con datos de prueba.
6. Subir AAB a prueba interna, atender rechazo/pre-launch y luego prueba cerrada.
   Para cuenta personal de 2025: al menos 12 testers inscritos continuamente los
   14 días previos a solicitar producción, con pruebas reales y sus resultados.
7. La revisión y acceso a producción los decide Google. Un APK instalado fuera de
   Play no cumple por sí solo las tareas de la consola.

Fuentes oficiales consultadas septiembre de 2026:
- [Inactividad](https://support.google.com/googleplay/android-developer/answer/11605267).
- [Pruebas de cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465).
- [Configurar pruebas](https://support.google.com/googleplay/android-developer/answer/9845334).

Identidad, declaraciones legales, permisos de cuenta y publicación final requieren
participación del titular. No prometer fecha de aprobación ni publicar secretos.
