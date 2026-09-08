# Separación QA / producción — 7 de septiembre de 2026

## Decisión del propietario

Conservar sistema-educativo-rl como QA, sin borrar usuarios ni operaciones.
Crear producción limpia e independiente: sistema-educativo-rl-prod.
Dominio público final: https://liceobilinguerodolfollinas.edu.co (Hostinger).
No cambiar DNS ni reemplazar el sitio público hasta validar el entorno nuevo.

## Estado comprobado

- Proyecto de producción creado, número 325430927285.
- Android registrado: com.desarrolloytecnologiasantander.serodolfollinas.
  App ID: 1:325430927285:android:2eecce415faf28dee103fc.
- Web registrada: 1:325430927285:web:4825f7f65a75fd6ee103fc.
- Registradas y verificadas ambas huellas SHA-256: carga y firma de Google Play.
- Alias qa/prod añadidos; default continúa en QA para preservar el flujo existente.
- firebase.production.json separado, ubicación prevista us-central1,
  salida web build/web-prod para no desplegar accidentalmente build/web de QA.
- Blaze habilitado y comprobado mediante Cloud Billing API.
- Firestore `(default)` creado en `us-central1`, modo nativo y protección contra
  eliminación activada; ubicación y protección verificadas mediante lectura posterior.
- Bucket independiente `sistema-educativo-rl-prod.firebasestorage.app` creado y
  enlazado a Firebase en `US-CENTRAL1`.
- APIs Firestore, Firebase Storage e Identity Toolkit habilitadas. Habilitar la
  API de Auth no equivale a configurar proveedores ni importar usuarios.
- Auth inicializado como FIREBASE_AUTH, correo/contraseña habilitado y dominios
  de producción autorizados; no se actualizó a Identity Platform.
- Migración principal completada y auditada: 18 cuentas Auth y perfiles, 18
  entradas de directorio, 30 grupos, dos años 2026 activos y sus selectores,
  una configuración institucional y 54 parámetros (125 documentos de negocio).
- Sitio/tema y seis páginas copiados a Firestore de producción; siete imágenes
  copiadas al bucket independiente. Hosting sigue sin publicar.
- Reglas Firestore/Storage e índices desplegados correctamente en producción,
  después de aprobar las 27 pruebas de reglas en emuladores.
- Separación de runtime implementada mediante `APP_ENV=qa|prod`, sabores Android
  y configuraciones SDK independientes. QA sigue siendo el valor predeterminado.
  No publicar aún: falta configurar servicios y migrar los datos.

## Usuarios aprobados

18 perfiles: 14 docentes incluyendo Karen, Nancy y Kamila administradoras,
Jairo superadmin y Sara Lucía estudiante. Otros 11 permanecen solo en QA.
La selección explícita por UID está en functions/scripts/production_readiness.js;
no usar una heurística por nombre en el momento de importar.

Preflight de solo lectura:

```powershell
node functions/scripts/production_readiness.js
```

Karen ya está como Docente de Séptimo A. Los grupos referenciados existen en QA;
esta comprobación no valida todavía su año, sedes y todas las relaciones cruzadas.
Nancy figura Administrador sin groupId; no simular doble rol mediante otra cuenta.
La capacidad docente de Nancy requiere diseño/revisión específica antes de asignar
horarios como docente. Jairo contiene una referencia vacía en studentIds; limpiar
en la proyección de producción sin modificar QA ni inventar vínculos.

## Importación: lista positiva

Copiar únicamente perfiles aprobados, Auth correspondiente y dependencias
institucionales revisadas: institución, sedes, grupos/año activo y parámetros
necesarios. Revisar sitio/tema e imágenes institucionales antes de copiarlos a
Storage de producción; nunca conservar URL de Storage QA como solución permanente.

Excluir explícitamente archivos académicos, matrículas de ensayo, autorizaciones,
horarios, rutas/recorridos, mensajes, formularios enviados, push/jobs/tokens/sesiones,
historiales de prueba, reservas de cuota y datos temporales. QR se emite en el nuevo
entorno; no importar secretos de credenciales QR ni sesiones del anterior.

No exportar hashes de contraseña a Git ni imprimir credenciales. Elegir un mecanismo
seguro de migración Auth (UID conservado con importación compatible o activación
controlada); no crear contraseñas conocidas ni afirmar que las antiguas funcionan
sin probar. Auditar la importación y bloquear ante referencias fuera de la lista.
Una importación fallida se reanuda de forma idempotente, no borrando producción.

## Puertas de avance

1. Completado: titular activó Blaze; facturación verificada.
2. Completado: APIs, DB us-central1 protegida y bucket propio. Pendiente: Auth
   con dominios autorizados y proveedores necesarios, y reglas de aplicación.
3. Configurar certificados Android de carga y distribución; comprobar SHA-1 para
   restricciones Maps y SHA-256 para servicios aplicables. No usar clave Maps de QA.
4. Implementado: selección Flutter/Android/web, worker y configuración backend
   derivada del proyecto; sin fallback de producción a QA. Validación detallada abajo.
5. Configurar secretos/VAPID/Maps por entorno; Maps requiere presupuesto independiente.
6. Validar proyección de datos, importar sin operaciones de prueba, verificar Auth
   y Firestore juntos. No activar cuentas huérfanas.
7. Ejecutar formato/analyze/Flutter/lint/emuladores y prueba física firmada.
8. Generar AAB con paquete registrado y clave de carga verificada. Elegir explícitamente
   QA para pruebas de Play o producción para aceptación, nunca mezclar configuraciones.
9. Desplegar web de producción en Hostinger cuando el conjunto esté validado.

Crear el proyecto no es publicarlo: pendiente del aviso de Play antes del 19,
la prueba interna y posteriormente 12 testers durante 14 días de prueba cerrada.

## Aprovisionamiento reproducible

`functions/scripts/provision_production.js` comprueba Blaze, APIs, ubicación de
Firestore/Storage y protección de eliminación. Sin argumentos es de solo lectura.
Con `--apply` habilita las tres APIs y crea exclusivamente DB/bucket ausentes en
el proyecto de producción explícito. No modifica QA, DNS, usuarios ni datos.
Si una API tarda en propagarse, falla sin borrar recursos y permite reanudar.
Usa la sesión local de Firebase CLI en memoria, sin exportar credenciales.

```powershell
node functions/scripts/provision_production.js
# Solo para aprovisionar recursos ausentes:
node functions/scripts/provision_production.js --apply
```

Validación del 7 de septiembre: creación terminada, segunda ejecución de solo
lectura correcta y `npm --prefix functions run lint` aprobado. No se ha probado
todavía el inicio de sesión ni una compilación contra producción. Tampoco se han
configurado alertas de presupuesto; Blaze no constituye un límite de gasto.

## Runtime y acceso — continuación del 7 de septiembre

- Android usa `src/qa/google-services.json` y `src/prod/google-services.json`.
  Se conserva el paquete QA y producción usa el registrado en Play. MainActivity
  conserva su namespace real y se referencia con nombre completo en el manifiesto.
- `lib/config/firebase_options.dart` coincide con los SDK nativos de ambos entornos.
  Se corrigió el identificador Android QA que antes difería del JSON nativo.
- Gradle valida APP_ENV contra el sabor solicitado y deshabilita el otro sabor;
  Flutter comprueba que el proyecto nativo coincida antes de cargar datos.
- Functions obtiene clave pública Auth y URL de continuación/notificaciones según
  el proyecto de ejecución. Proyectos desconocidos fallan; emuladores usan localhost.
- El worker QA usa la configuración web correcta y rechaza dominios de producción.
  `tools/build_web.js` genera la configuración propia de producción dentro de su
  salida; `tools/verify_production_web.js` comprueba la salida antes de Firebase Hosting.
- Producción no hereda VAPID ni Maps QA. VAPID producción está pendiente; la
  compilación web de producción se bloquea si no se proporciona `WEB_VAPID_KEY`.
  Maps Android producción usa la propiedad Gradle `PROD_MAPS_API_KEY`, pendiente;
  el APK técnico no es apto todavía para validar mapas ni publicar.
- Se retiraron metadatos FlutterFire obsoletos de firebase.json; no regenerar una
  única configuración que sobrescriba ambos entornos.

```powershell
node tools/build_web.js qa
# Requiere WEB_VAPID_KEY de producción en el entorno del proceso:
node tools/build_web.js prod
flutter build apk --flavor qa --dart-define=APP_ENV=qa --release --target-platform android-arm64
flutter build apk --flavor prod --dart-define=APP_ENV=prod --release --target-platform android-arm64
node --test tools/environment.test.js
npm --prefix functions exec -- mocha functions/test/runtime_environment.test.js
flutter test test/environment_test.dart --dart-define=APP_ENV=prod
```

Auth: las 18 cuentas aprobadas tienen hash de contraseña y correo verificado en
QA. La lectura segura confirma que `signIn.hashConfig` está disponible: es viable
preparar importación SCRYPT sin cambiar contraseñas. Esto NO confirma todavía una
migración ni un inicio de sesión en producción. No se exportaron hashes a archivos.

Producción devuelve 404 en la configuración Auth: se solicitó al titular abrir
Authentication > Comenzar y activar Correo/contraseña. No se usó el endpoint de
inicialización de Identity Platform para evitar una actualización de producto no
necesaria. Después ejecutar `node functions/scripts/configure_production_auth.js
--apply` para añadir y verificar dominios de producción; el script exige Auth ya
inicializado, no cambia QA ni importa cuentas. Diagnóstico sin secretos:
`node functions/scripts/production_auth_preflight.js`.

Pruebas: 51 Flutter aprobadas; 3 adicionales con APP_ENV=prod; 4 pruebas unitarias
backend de aislamiento; 3 pruebas de configuración SDK/worker; 4 pruebas del
resolvedor de acceso en emuladores. Analyze y lint aprobados. Web QA compilada.
APK QA y técnico producción compilados, paquete Play y firma de carga verificados.
La validación adicional del dominio web se probó posteriormente en unitarias;
regenerar artefactos antes de distribuirlos. No entregar estos APK como versión final.
Hay avisos del toolchain Android sobre metadata Kotlin 2.3/2.2 y SDK XML: la
compilación terminó, pero no constituyen una prueba de estabilidad física.

Lo anterior describe la etapa de separación. Estado posterior de migración:

## Migración principal completada — 7 de septiembre de 2026

El titular inicializó Authentication. `configure_production_auth.js --apply`
habilitó/verificó correo con contraseña y añadió los dominios propios del colegio.
No hubo envíos de correo, restablecimientos ni contraseñas compartidas.

`migrate_production_core.js` se ejecutó primero sin argumentos (diagnóstico),
después con `--apply` y nuevamente sin argumentos para comprobar su reentrada.
`production_projection.js` selecciona únicamente los 18 UID aprobados y campos
permitidos. El borrador 2027 y sus 15 grupos copiados en QA quedaron excluidos.
No se copiaron sesiones, tokens, intentos de acceso, QR ni operaciones de prueba.

La cuenta Auth de Sara Lucía tenía un correo diferente del perfil Firestore.
Se conservó la cuenta Auth original y su contraseña; el correo interno del perfil
de producción se ajustó al de Auth para que el resolvedor por documento funcione.
La referencia vacía de hijos de Jairo se retiró en producción; no se inventaron
vínculos. Nancy sigue administradora y Karen docente de Séptimo A.

Seguridad de la importación:

1. Crea perfiles/directorio inactivos y dependencias en un único commit Firestore.
2. Importa las cuentas ausentes como deshabilitadas usando SCRYPT y los parámetros
   originales en memoria, sin exportarlos ni imprimirlos y sin sobrescribir cuentas.
3. Verifica UID/correo/estado, habilita Auth y finalmente activa todos los perfiles
   y el directorio en un commit atómico con precondiciones de versión.
4. Si falla a mitad, los perfiles siguen inactivos: se reanuda desde el estado
   preparado, no borrando datos. Una concesión temporal de diez minutos y las
   precondiciones impiden dos ejecutores concurrentes. Cambios en el origen o en
   los registros preparados detienen la reanudación para revisión.

Registro: `migration_audit/production_core_v1`, fase `complete`, resumen y UID
aprobados; nunca contiene contraseñas ni hashes de contraseña originales.

Verificación adicional de solo lectura:

```powershell
node functions/scripts/verify_production_core.js
npm --prefix functions exec -- mocha functions/test/production_projection.test.js
```

Resultado: 18 Auth/perfiles/directorio concordantes, 30 grupos y dos años activos;
15 colecciones operativas vacías; relaciones y ausencia de tokens/URL Storage QA
validadas. Seis pruebas unitarias de proyección y 27 pruebas de reglas aprobadas;
lint aprobado. Los errores PERMISSION_DENIED esperados en pruebas negativas no
son fallos de la migración. Login físico con contraseña todavía no probado.

Tres fotos de perfiles y el logo se dejaron temporalmente vacíos en producción:
se conservan en QA y requieren copia de objetos al bucket nuevo. No se borró nada
del origen. El sitio/tema y sus imágenes también están pendientes de esa fase.
No se cambió DNS ni se desplegó el frontend/backend de aplicación todavía.

## Sitio e imágenes — continuación del 7 de septiembre

`migrate_production_assets.js` copió siete imágenes (5.736.496 bytes), las seis
páginas, website/config, logo institucional y dos fotos de usuarios/directorio.
No copió todos los objetos de QA ni su cola de imágenes pendientes de eliminar.
Los objetos del sitio tienen nombres institucionales nuevos, con referencias
URL/ruta reescritas; se mantienen enlaces externos de redes sociales.

La tercera foto, de Sara Lucía, ya devolvía 404 en el bucket de QA. No se fabricó
ni reemplazó por otra imagen: su perfil en producción sigue sin foto hasta que
se vuelva a cargar. La ruta faltante quedó registrada en la auditoría.

Cada copia exige la generación original y un destino ausente, comprueba tamaño
y CRC32C y genera un token de descarga nuevo. El manifiesto se registra antes de
copiar en `migration_audit/production_assets_v1`; una interrupción deja copias
registradas para reanudar. El commit final publica todas las referencias junto
con fase `complete`, usando versiones de documentos para no pisar cambios.
No se borraron objetos de QA. Una reejecución comprobó los siete objetos.

Verificaciones:

```powershell
node functions/scripts/migrate_production_assets.js
node functions/scripts/verify_production_assets.js
npm --prefix functions exec -- mocha functions/test/production_assets.test.js
```

Resultado: 44 documentos revisados sin referencias a Storage QA; siete imágenes
accesibles mediante sus URLs de producción; cuatro pruebas de alcance y lint
aprobados. El encabezado de respuesta HTTP se comprobó sin imprimir tokens.

Las 70 funciones quedaron ACTIVE en el proyecto nuevo. El primer intento requirió
confirmar los reintentos de siete triggers; se verificó previamente que no había
funciones existentes que pudieran borrarse. El despliegue encontró propagación
de permisos Eventarc y cuota temporal de mutaciones. El rol oficial del agente
Eventarc ya existe: no se añadieron privilegios amplios para sortear la espera.
Estado de solo lectura: `node functions/scripts/production_functions_status.js`.
La lista se compara contra las 70 funciones actuales de QA sin modificar QA.
Se reintentaron únicamente las cinco creaciones pendientes y el despliegue
terminó correctamente. Artifact Registry conserva las imágenes de despliegue
durante un día; esta política no elimina archivos del Storage del colegio.
Cinco comprobaciones HTTP reales de funciones ya activas rechazaron peticiones
sin sesión con UNAUTHENTICATED; esto no demuestra el login ni entrega push.

El titular proporcionó la clave pública VAPID de producción; se comprobó que
representa un punto válido P-256 sin comprimir. Esto no demuestra todavía la
entrega de notificaciones ni su asociación al proyecto en Firebase Console.
Para compilar localmente o configurar la variable de GitHub Actions:

```powershell
$env:WEB_VAPID_KEY = 'BBmFIxb-Q9Gb54Gm55MgAyPxjcntd5semyUmZ_KEemDUFgy3kebxOxhUAKtDEYEVmgJy4uqJqsp_Q0a4Xab8I9c'
node tools/build_web.js prod
node tools/verify_production_web.js
```

Es una clave pública destinada al navegador; nunca agregar la clave privada.
La rama remota `production-web` contiene exclusivamente artefactos compilados
en su raíz para el directorio público de Hostinger. El titular autorizó publicar.
`tools/publish_production_web.js` verifica el entorno y publica sin force push,
conservando historial y un `release.json` que identifica el commit fuente.
La configuración Apache incluye inicio `index.html`, fallback SPA y revalidación
de archivos de arranque para no retener configuración Firebase antigua.
Incidencia comprobada en Hostinger: la URL sin parámetros de `main.dart.js`
seguía sirviendo 5.467.079 caracteres antiguos con caché de siete días, mientras
la URL con parámetro servía los 12.620.901 actuales. Incógnito no evita caché CDN.
Producción ahora referencia nombres con hash de contenido para el bootstrap y
el código principal; el verificador impide publicar entradas sin versionar.

El workflow `.github/workflows/production-web.yml` compila y publica ante cambios
de frontend/herramientas en `agent/portal-web-cms`, después de formato, análisis
y pruebas. Hostinger debe tener despliegue automático desde `production-web`.
QA sigue usando su workflow existente en `main`; nunca mezclar ambas ramas.
Cambiar la rama fuente requiere actualizar explícitamente el workflow.
Para revertir, reconstruir la revisión fuente aprobada y publicar un nuevo commit
de artefactos; no reescribir el historial ni borrar datos Firebase.

CORS de producción aplicado al bucket propio con precondición de metageneración:
`infrastructure/storage-cors.production.json`. Antes no tenía configuración CORS.
Se verificó GET del logo con Origin del dominio raíz y www: HTTP 200 y
Access-Control-Allow-Origin correcto; un origen ajeno no recibe esa cabecera.
No se cambiaron reglas Storage, objetos ni configuración QA.

Diagnóstico corregido de consola: la traza del JavaScript 9bc55052, línea
168021, corresponde al contador de autorizaciones. El tablero superadmin pasa
institución/sede null a watchPendingCountForAdmin, que exige ambas. Ahora usa
alcance global explícito, suma por sede/año y captura errores del contador. No atribuir
ese error ni las fuentes Noto a una pérdida de push sin evidencia del receptor.
El titular confirmó recepción visible en móvil y Chrome normal con la segunda
prueba. Web en segundo plano y apertura de conversación siguen pendientes.

Pendientes: Maps restringido,
sincronizar canales académicos iniciales sin mensajes de prueba, prueba física
de acceso/notificaciones, compilación definitiva y publicación de frontend/AAB.
