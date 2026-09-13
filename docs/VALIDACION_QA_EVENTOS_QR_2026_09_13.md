# Eventos y QR: aceptación en QA

Alcance: `sistema-educativo-rl`, web QA y APK QA 1.0.0+12.
Rama: `agent/qa-eventos-qr`. No publicar esta rama mediante el flujo automático
de producción. No se ha autorizado producción ni Google Play para esta ampliación.

## Implementación

Todos los perfiles presentan su QR y abren el lector. El QR identifica, no
autoriza una acción. Eventos y Rutas preparan la operación y solicitan una
confirmación; el servidor vuelve a comprobar identidad, alcance y estado.

Eventos conserva una sola agenda, `school_events`, con presentaciones de
estudiantes y encuentros de padres. Incluye subtítulo, anuncio/enlace opcional,
materiales o trajes con indicaciones, valor y dirección opcionales. Alimentación
solo en presentaciones: catálogo administrativo, reserva por familiar e hijo,
total calculado por el servidor, pago manual y entrega desde el inicio del evento.
No hay pasarela de pagos ni garantía de inventario; en QA no se paga dinero real.

Los requisitos se configuran en borrador, por estudiante o familiar, para
confirmación manual, asistencia o pago. Las marcas de adultos distintos son
independientes. La asistencia individual del adulto es un requisito del evento;
no debe confundirse con la respuesta de participación que representa al estudiante.

Docentes responsables administran materiales y seguimiento; no configuran el
catálogo de alimentos ni los requisitos administrativos. La delegación y su
reversión se heredan del evento, sin crear listas independientes de responsables.

Rutas permite confirmar una recogida mediante QR y conserva el botón manual.
Una solicitud repetida no duplica recogida, historial ni aviso. GPS continúa
privado y se revoca al recoger, marcar ausencia o finalizar. El aviso manual
de tiempo no requiere cálculo automático de Maps.

Pedidos, cumplimientos y novedades utilizan el outbox y la cola push existentes.
Sus destinatarios se revalidan antes de cada envío/reintento. Los avisos privados
no se envían a otra familia y las lecturas no se comparten entre usuarios.
Aceptar un envío FCM no demuestra que se mostró una notificación en el teléfono.

También se corrigió el proyector del directorio: una ejecución atrasada consulta
el perfil actual dentro de una transacción y no reactiva una baja. El impacto
de eliminación incluye Eventos; una referencia bloquea la eliminación definitiva,
pero no la baja lógica, incluso cuando el conteo de impacto es un mínimo acotado.

## Verificación automatizada

| Comprobación | Resultado observado |
| --- | --- |
| Flutter, suite completa con navegación entre notificaciones | 158 aprobadas |
| Flutter analyze completo | Sin incidencias |
| Backend Eventos | 21 aprobadas |
| Backend QR y Rutas | 30 aprobadas |
| Backend Usuarios, incluida proyección fuera de orden | 34 aprobadas |
| Unitarias Functions: acceso push, descargas, integridad y guardas QA | 31 aprobadas |
| Reglas Firestore y Storage | 40 aprobadas |
| Herramientas de aislamiento, nombre QA y artefactos web | 12 aprobadas |
| Índices requeridos de QA | 86 READY, sin faltantes; 5 adicionales conservados |
| APIs desplegadas, prueba integrada exclusiva QA | 19 aprobadas |
| Navegación autenticada QA: administrador, docente y familiar | 3 roles, 12 fichas entre 1366 y 320 px, sin errores JS/consola/HTTP/red |
| Web pública y login QA, navegador headless | Ambas montan, sin errores JS/HTTP ni solicitudes fallidas |

Los logs se conservan en `.buildlog`, fuera del control de versiones. Contienen
salida técnica de pruebas y despliegues, no son material para distribuir a familias.

## Datos de prueba

Jairo conserva su administrador real de QA y Sara su perfil estudiante. Ambos ya
tenían permiso de Eventos; no se cambian sus contraseñas ni se eleva a Sara a
administradora. Se crean cuatro identidades sintéticas identificadas por
`qa_events_qr_2026_09`: administrador normal, docente y dos familiares vinculados
a Sara solamente en QA. Sus credenciales y la guía para probar están fuera de Git.

El script `functions/scripts/qa_events_fixture.js` rechaza producción, valida las
identidades reales antes de operar y usa las Functions para crear los ejemplos.
El manifiesto `migration_audit/qa_events_qr_2026_09` identifica los eventos de demo.
Las pruebas API crean eventos separados, marcados, que se cancelan y archivan
con auditoría; no eliminan datos ajenos ni alteran los dos ejemplos para el usuario.

## Comprobación física pendiente

El APK final `build/app/outputs/flutter-apk/app-qa-release.apk` fue inspeccionado
después de recompilar. Su nombre visible es **SE Rodolfo Llinás QA**, código de
versión 12 y versión 1.0.0. Usa el paquete
`co.edu.liceobilinguerodolfollinas.sistemaeducativo`, distinto de producción, y
el proyecto Firebase `sistema-educativo-rl`. La firma APK v2 es válida, con un
firmante; no se declara depuración. Tamaño: 132 760 487 bytes. SHA-256 del archivo:
`95d491ae3b2b9ee05aadce35cf6955ef448e3d3f76fdfd6e72cecfb9bb4d0d0e`.

El manifiesto compilado incluye cámara opcional, ubicación precisa/aproximada,
notificaciones y servicio en primer plano de ubicación. No incluye acceso amplio
a fotos, vídeos o almacenamiento ni `ACCESS_BACKGROUND_LOCATION`. La clave Maps
empaquetada coincide con QA; esto acredita configuración, no funcionamiento en
un teléfono real. La variante y el nombre de producción no se modificaron.

No hay Android conectado al equipo de desarrollo (`adb devices` sin dispositivos).
Por tanto, las pruebas automatizadas de permisos, GPS, cámara y outbox no acreditan
lectura óptica real, movimiento del teléfono o recepción visible de push.

La consulta de configuración Cloud de QA, sin escrituras, confirmó las APIs Maps
SDK para Android y Routes habilitadas. Sin embargo, `MAPS_ROUTING_ENABLED` está
desactivado tanto en `operarRecorrido` como en `calcularTiemposRuta`: los tiempos
automáticos no están disponibles. El modo manual conserva avisos de tiempo y GPS
privado; compartir posición requiere permisos, ubicación activa y un responsable
designado. Ver el mapa, compartir GPS y calcular tiempos son comprobaciones
distintas, y ninguna se da por aprobada físicamente con esta inspección.

Pendiente técnico: endurecer la clave Maps de QA. Actualmente tiene una lista de
APIs permitidas, pero no restricciones Android por paquete y certificado; revisar
su separación de la clave Firebase y las restricciones correspondientes antes de
ampliar la distribución. No se modificaron claves, IAM, APIs ni facturación.

En QA, la ruta antigua de Sara conserva fechas de agosto de 2025 y recorridos
históricos abiertos. Se detectó mediante lectura; no se reasignó ni se cerró ese
historial ajeno como efecto secundario de Eventos. Para probar recogida/GPS con
Sara se necesita un recorrido vigente, iniciado por su responsable designado.
Ser superadministrador por sí solo no convierte a alguien en responsable del GPS.

## Estado de entrega

Entregado exclusivamente a QA el 13 de septiembre de 2026:

- 41 Functions publicadas/actualizadas en lotes explícitos. Verificación posterior:
  116 funciones locales y 116 remotas ACTIVE; ninguna faltante.
- Reglas Firestore publicadas y dos índices añadidos sin eliminar los cinco
  adicionales existentes. Los 86 requeridos están READY.
- Hosting: https://sistema-educativo-rl.web.app . Hash SHA-256 de `main.dart.js`:
  `cd5565cfefa6dab25ad5cd3aa8925133fcfc8d5bfe450ebc89e174e9448d5259`.
  Se comprobó que coincide con el artefacto local antes de las pruebas autenticadas.
- APK QA firmado, versión 12, disponible localmente en la ruta indicada arriba.
  No se subió un APK/AAB a Google Play ni se desplegó el sitio de producción.
- Presentación publicada: `1WZq6sB0ryNVgJI8uTjp`, con jugo COP 3.000,
  sándwich COP 6.000, material de ensayo y requisitos individuales.
- Encuentro de padres publicado: `PoUp1jkC8U01fNijN9kg`, sin alimentos, con
  entrega de boletín y asistencia separadas por familiar.
- El ensayo API `AnjIwG8iuxYtCC2NNI4R` quedó cancelado y archivado mediante
  Functions, con historial preservado. Los dos ejemplos no se alteraron.
- Los dos avisos de publicación generaron sendos trabajos aceptados por FCM:
  un destinatario registrado por trabajo, cero rechazos, un intento. Esto no
  certifica recepción visible ni lectura. Sara no tenía token QA registrado.

Evidencia local: `.buildlog/qa-events-functions-final.json`,
`.buildlog/qa_events_smoke_20260913152335669_1229987d.json`,
`.buildlog/qa-events-ui-1789313146388/admin.json`,
`.buildlog/qa-events-ui-1789313206860/` y
`.buildlog/web-smoke-qa-1789313022957/`.
La comprobación autenticada es funcional y semántica, no una certificación
visual por píxel. Las sesiones y perfiles temporales de navegador se cerraron
y eliminaron; no se inició sesión ni se desplazó el token de Jairo o Sara.

Guía con cuentas temporales, contraseñas y pasos por rol (privada, fuera de Git):
`C:/Users/Jairo/.config/sistema_educativo/GUIA_PRUEBAS_QA_EVENTOS.md`.
Para regenerar únicamente esa guía, sin crear eventos ni cambiar identidades:
`node functions/scripts/qa_events_fixture.js --project=sistema-educativo-rl --write-guide`.

La aceptación física de cámara, GPS y notificaciones, el escenario vigente de
Rutas para Sara y el endurecimiento Maps descritos arriba siguen pendientes.
No se garantiza ausencia absoluta de defectos a partir de estas pruebas.
