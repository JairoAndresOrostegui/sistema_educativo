# Revisión de Rutas y notificaciones — 6 de septiembre de 2026

## Actualización: ventana GPS y avisos económicos

Implementado acceso a GPS privado por hijo pendiente con ventana estimada <=10
minutos. Al recoger/no recoger/finalizar se revoca en backend/reglas. Una ventana
abierta permanece ante demora. GPS no recalcula Maps: solo evalúa estimaciones
guardadas. Se retiraron recálculos de temporizador y recogida; responsable solicita
recálculo con confirmación. Avisos generales dentro de Rutas, también para quienes
ya fueron recogidos, con historial; se descarta conectar el viaje a un chat.
La posición no se guarda en el padre compartido; migrar campos antiguos antes de
entregar nuevo cliente. Manuales por perfil en [manuales](manuales/README.md).

Versión APK de esta revisión: 1.0.0+2; hashes y tamaños anteriores de este archivo
corresponden al entregable anterior. Maps real sigue pendiente de habilitación.
APK ARM64: 43.5 MB, SHA256
`e2a7d84faa5e91758f98d732b353efb6cccc7275018c86ed49e693502041d201`.
Validación de esta entrega: 48 pruebas Flutter, 24 Rutas/push, 27 reglas;
analyze y lint sin errores. Prueba física aún pendiente del propietario.
Agrupación por texto de dirección, no paradas con coordenadas ni cercanía automática.

Costos revisados (22 días, 16 espectadores 10 min, 80 min/trayecto, GPS30s,
cuotas gratuitas agotadas): subtotal Maps + reserva Firestore (8000 lecturas,
1000 escrituras/trayecto) Android USD0.29/mes ida con cálculo inicial, USD0.73
con dos recálculos solicitados; web16 espectadores USD2.76/3.20 respectivamente.
Ida/vuelta duplica esos subtotales. No incluye duración Functions, tráfico,
almacenamiento/logs/infraestructura compartida, ni Places al registrar direcciones.
No presentar estos valores como factura total. Mapas gratuitos: RoutesPro5000
cálculos/mes, web10000 cargas/mes; Firestore50000 lecturas/20000 escrituras al día,
compartidas con todos los módulos. Medir consumo real antes de prometer costos.

---

Estado: diagnóstico inicial conservado abajo como evidencia; implementación
de seguridad/manual probada y APK de QA generado. La propuesta fue aprobada con los
ajustes siguientes. Consultar este encabezado antes de interpretar hallazgos
históricos como pendientes actuales.

## Decisiones posteriores e implementación

- Paradas bloqueadas después de iniciar, también para admin: sustituye la
  propuesta anterior de cambios en viaje activo.
- Un aviso agrupado por parada/usuario para hermanos que comparten recorrido;
  asistencia individual y cierre cuando todos están resueltos.
- Conductor sin Auth; hoja de vida y selección en la plantilla. Cuenta Auxiliar
  para responsable designado, sin poderes académicos implícitos.
- Cobertura a criterio del admin; no se aplica radio máximo automático.
- Implementados backend transaccional y reglas de acceso, cola de avisos,
  historial, solicitudes para hoy antes de iniciar, botón de notificaciones y
  propiedad de sesión del último móvil/web. Diagnósticos se convirtieron en
  pruebas de regresión de rechazo.
- Cálculo automático implementado detrás de MAPS_ROUTING_ENABLED, desactivado
  hasta habilitar/verificar APIs y presupuesto. No afirmar prueba real de Maps.
- Pendientes explícitos: búsqueda visual Places/pin validado; planificación
  anticipada y dos sentidos diarios; canal de Mensajería por ruta; relevo de
  auxiliares durante viaje; sincronización offline con resolución de conflictos;
  migración del historial antiguo al historial unificado. No declarar terminado
  el rework completo ni publicado en Play.
- APK ARM64 final: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
  (43.5 MB), adecuado para Z Flip7. SHA256:
  `796cba190b88c96a946f76c93f39586ee674c5b878d47f205c6a73283a7072f7`.
  Android API 36 emulado: instalación debug y apertura del login correctas;
  release no sustituye la app debug existente por diferencia de firma. No se
  desinstaló ni se borraron sus datos. Instalación release física pendiente.
- Validación: analyze y lint sin errores; 48 pruebas Flutter, 21 de
  Rutas/push, 27 de reglas, 4 de Auth y 17 de Usuarios aprobadas. FCM externo
  simulado: no equivale a recepción visible en un celular.
- Migración QA aplicada: cuatro perfiles normalizados, rol Auxiliar agregado;
  una ruta y dos recorridos existentes sin padre huérfano. Segunda ejecución
  de diagnóstico sin cambios pendientes. Hosting publicado en QA.

## Estimación de consumo: 16 paradas, 80 minutos, solo ida

Supuestos de diseño: 22 días/mes; posición cada ~30 segundos (160 cambios/día);
17 espectadores web como escenario de referencia; 32 cálculos con tráfico/día
(por avance más refrescos cada 5 minutos), una carga del mapa por espectador;
~10000 lecturas y ~1000 escrituras Firestore/día incluyendo margen de operación.
Los cálculos actuales no consumen Maps mientras el interruptor de servidor esté
deshabilitado. No se ha verificado la región/cuenta de facturación real.

Sin cuotas gratuitas (tarifas de lista USD, sin impuestos):

| Concepto | Diario | 22 días |
|---|---:|---:|
| Routes Pro: 32 x USD 0.01 | 0.32 | 7.04 |
| 17 cargas web Dynamic Maps x USD 0.007 | 0.119 | 2.618 |
| Firestore referencia us-central1: lecturas/escrituras | 0.0039 | 0.0858 |
| Subtotal medible de esos tres rubros | 0.4429 | 9.7438 |

Reservar aproximadamente USD 10–15/mes para esta ruta como estimación de
consumo marginal sin beneficios gratuitos, más gastos compartidos existentes:
Functions (duración/memoria), transferencia, logs, builds, Scheduler, secretos,
almacenamiento acumulado y Hostinger. No es un límite contractual ni incluye
vehículo, conductor, combustible, datos móviles o desarrollo. Places añade
consumo al registrar/cambiar direcciones, no por cada GPS.

Con cuotas disponibles, 704 cálculos/mes y 374 cargas web/mes están por debajo
de los topes gratis publicados de Routes Pro (5000) y Dynamic Maps (10000).
10000 lecturas y 1000 escrituras/día también están bajo los topes diarios de
Firestore (50000/20000), pero los comparte con el resto del colegio; no prometer
factura total cero. FCM no cobra por mensaje, su backend sí puede consumir.

Fuentes oficiales de precios consultadas el 6 de septiembre de 2026:
- https://developers.google.com/maps/billing-and-pricing/pricing
- https://cloud.google.com/firestore/pricing
- https://firebase.google.com/pricing

## Evidencia histórica del diagnóstico inicial (no estado actual)

Los párrafos siguientes describen el estado anterior a las correcciones.
Hoy los casos de Rutas verifican rechazo y las pruebas suman 21; sí hay un
emulador Android disponible. La recepción física y Maps siguen pendientes.

- `functions/test/routes_push.audit.test.js`: 8 casos de caracterización.
- `functions/test/push_queue.test.js`: 3 casos de cola, incluido 1201 tokens.
- `functions/test/notification_function.audit.test.js`: 6 casos que ejecutan
  las funciones exportadas mediante `.run`, con Firestore emulado y transporte
  FCM externo bloqueado; no prueban el protocolo HTTP/autenticación Firebase.
- `test/routes_push_audit_test.dart`: extracción de tokens y reproducción de
  desbordamiento de selector de ruta a 320 x 640.
- Los casos llamados HALLAZGO/AUDITORIA comprueban que el defecto existe:
  un resultado verde NO significa que esas reglas sean seguras. Al corregir,
  convertirlos en pruebas de rechazo o ausencia de excepciones.
- No hay Android conectado. GPS, permiso denegado, conexión intermitente,
  pantalla bloqueada y notificación visible requieren pruebas físicas.
- Para push real se solicitó al propietario la cuenta destinataria y tener
  disponibles su móvil/navegador. No se enviaron avisos a usuarios al azar.

## Resultado de los cinco puntos

1. Sede: lectura de otra sede rechazada para admin normal, permitida para
   superadmin. Dentro de sede, las reglas omiten permisos granulares de Rutas.
   Docente puede crear una ejecución para una ruta que no se le ha asignado.
2. Familiar: existe selector local, pero no persiste/revalida el contexto
   universal mediante backend. Familiar/estudiante pueden leer paradas ajenas
   de su sede directamente, incluida su dirección. El selector no es seguridad.
3. Operación: creación diaria y paradas en escrituras separadas; eliminación de
   ruta deja ejecuciones relacionadas. Historial administrativo se llama después
   de la mutación. Paradas admiten cambios incluso con año cerrado/ruta finalizada.
   El identificador diario usa la fecha del dispositivo y no distingue ida/vuelta.
4. Mapa: tiempos introducidos manualmente, no calculados por Google. El servicio
   web da permiso por supuesto; GPS deshabilitado/errores se registran en consola.
   No se observó configuración de servicio de ubicación en primer plano en
   AndroidSettings. No se garantiza continuidad con pantalla bloqueada.
   El límite de 45 segundos solo se evalúa cuando llega una nueva posición:
   no constituye un latido periódico si el dispositivo está quieto.
5. Móvil: desbordamiento reproducido en selector docente con nombre largo.
   Hay estilos AppPalette/degradados antiguos. No se certifica la maqueta completa
   con mapa nativo, teclado, orientación o accesibilidad por este único test.

## Notificaciones

La función encola correctamente 1 token móvil, 1 web o ambos. Guardar un slot
con ruta de campo conserva el otro. La cola divide 1201 tokens en 500/500/201,
deduplica, limita reintentos y descarta tokens que ya no están vigentes.

Defectos reproducidos:

- Ningún token: `enviarNotificacion` lanza invalid-argument. Debe ser una
  omisión válida y no impedir cerrar/iniciar un recorrido.
- Logout desde móvil antiguo borra el token del móvil nuevo: no compara dueño.
- Refresh del móvil antiguo puede recuperar el slot sin un nuevo login.
- Docente sin asignación a ruta puede encolar avisos a estudiantes de su sede.

Hallazgos adicionales de lectura:

- Finalizar envía avisos ANTES de cambiar el estado; puede anunciar un cierre
  que no se guardó o bloquearse por falta de tokens. Inicio puede seguir tras
  un error que `_onUpdateRutaDia` captura sin propagar.
- La cola omite un token reemplazado después de encolar, pero no agrega el nuevo
  al lote existente. El nuevo recibe eventos futuros; decidir si se requiere
  reenrutamiento de avisos aún pendientes.
- El resolutor aún considera campos de tokens antiguos, aunque la revalidación
  de envío solo acepta slots actuales. Retirar mediante migración única.
- Los avisos de Rutas no incluyen destino de navegación específico; la apertura
  directa implementada actualmente corresponde a Mensajería.

Contrato propuesto: dos slots exactos, `mobile` y `web`. Cada nuevo login
registra propiedad de sesión del slot en backend. Refresh/logout solo modifica
el slot si sigue perteneciendo a esa sesión. Un equipo sustituido no lo recupera
salvo login posterior. Sin permiso/token no hay push disponible; el inicio de
sesión sigue siendo válido. Un móvil sin permiso no debe dejar notificado al
móvil anterior si es ahora el último login: debe desplazar su propiedad también.
El otro slot no se toca. Navegador móvil pertenece a web; app instalada a mobile.
Aviso aceptado por FCM, mostrado en equipo y leído son estados distintos.

## Propuesta de rework (no implementada)

### Entidades y alcance

- Plantilla de ruta por sede/año, responsable, vehículo/capacidad, días y orden.
- Viaje por fecha local del colegio y sentido: ida y regreso independientes.
- Parada puede agrupar hermanos/estudiantes en el mismo punto; la asistencia y
  entrega siguen siendo individuales. No agrupar solo por igualdad de texto.
- Dirección habitual separada de solicitud de excepción y de instantánea diaria.
- Historial inmutable y outbox de avisos en la misma transacción de negocio.
- Toda responsabilidad se integra a traslado docente y reversión existentes.
- No borrar rutas con viajes: archivar; eliminación excepcional con impacto,
  permisos y cascada confirmada. Año cerrado solo consulta administrativa.

### Configurar y preparar

Admin selecciona sede (solo superadmin cambia), año, responsable, estudiantes
activos, capacidad, horarios y sentido. Valida duplicados/choques y direcciones.
Antes de salir se genera una única ejecución, aplica excepciones aprobadas y
ausencias, muestra orden/estimaciones y pide confirmación al responsable.
Un doble clic no crea otro viaje. Ediciones concurrentes comparan revisión.

### Dirección y cálculo

Búsqueda con Places Autocomplete y elección de resultado/pin confirmado por
familia; instrucciones de acceso propias, nunca confiar solo en texto libre o
un enlace. El pin no demuestra que el bus pueda acceder: colegio valida el punto.
Guardar referencia Place ID y datos propios; retención de datos de Google según
condiciones del proveedor, no asumir almacenamiento ilimitado de respuestas.

Routes API estima duración por tramo. ETA acumula conducción + espera de cada
parada + retrasos. Mostrar rango aproximado y hora de actualización, no promesa
exacta. Calcular al preparar/iniciar, aprobar cambio y desviación importante;
no por cada familiar que abra la pantalla ni cada actualización GPS.
Primero respetar orden aprobado; optimización automática global es otra fase.

### Cambio solo por un día

Familiar selecciona hijo, fecha, ida/regreso, punto y motivo. Solicitud pendiente
no cambia la parada vigente. Admin de sede aprueba/rechaza con motivo, tras
consultar distancia, capacidad, cobertura e impacto de horario.

- Antes de salida: aplicar atómicamente al aprobar, recalcular y avisar.
- Viaje activo: aprobación administrativa + aceptación del responsable cuando
  esté detenido; no cambiar silenciosamente navegación ni parada.
- Ya recogido/parada pasada: no reabrir automáticamente; contacto con colegio.
- Otra ruta: transferencia atómica de asignación diaria entre rutas, con
  capacidad y aceptación de responsables. No duplicar ni dejar sin asignación.
- Fuera de cobertura/sede o cupo: rechazar, ofrecer coordinación administrativa.
- Dos familiares solicitan: una solicitud efectiva por hijo/fecha/sentido;
  conflictos visibles, control de revisión, notificar a ambos.
- Cancelación pendiente permitida; deshacer aprobación crea nueva decisión,
  no borra historia. Vencida se marca expirada.
- Cambio habitual: trámite separado, fecha efectiva; no convertir excepción
  de hoy en dirección permanente por accidente.

### Recorrido y excepciones

Estados propuestos de viaje: preparado, en curso, pausado, finalizado, cancelado.
Estados individuales: pendiente, ausente avisado, no presentado, a bordo,
entregado/llegó al colegio; corregir exige motivo y auditoría, no toggles libres.

- Ausencia hoy: familiar avisa; se ajusta parada sin borrar matrícula/asignación.
- No aparece: responsable registra espera e intento de contacto; después aplica
  protocolo del colegio. No asumir recogido por cercanía GPS.
- Hermanos: marcar individualmente aunque compartan parada.
- Regreso sin adulto autorizado: no marcar entregado; activar protocolo del
  colegio, registrar incidente y contactar administración/familia.
- Persona distinta: autorización explícita vigente; QR solo identifica.
- Trancón/desvío: recalcular tramos restantes y avisar únicamente cambios útiles.
- Accidente/avería: pausar y avisar; relevo de vehículo/responsable confirmado.
- Sin red: última posición con antigüedad visible, nada de ETA «en vivo» falsa;
  acciones locales marcadas pendientes, idempotencia y validación al sincronizar.
- GPS apagado/permiso negado: operación manual explícita, mapa no disponible;
  no obligar al familiar a conceder ubicación para consultar el vehículo.
- Cierre: revisar todos los estudiantes, justificar pendientes; guardar cierre
  antes de avisar, detener GPS y conservar historial, no perderlo si falla FCM.
- Retiro/cambio de sede/grupo, baja de responsable o cambio de año: revalidar
  asignaciones futuras sin reescribir viajes cerrados. Viaje activo requiere
  decisión operativa del colegio, no desaparecer un pasajero a bordo.

### Privacidad y avisos

Familia ve solo estado/parada de su hijo, ETA y posición del vehículo durante
su viaje autorizado; no lista de domicilios/pasajeros. Ubicación del responsable
fuera del recorrido nunca se comparte. Avisos generales al canal de la ruta;
dirección, ausencia, recogida e incidentes individuales solo a familia vinculada
y personal autorizado. Publicación automática en Mensajería pendiente de go.

Avisos: inicio, proximidad (una vez por umbral/parada), llegada, recogida,
entrega, retraso relevante, cancelación y decisión de cambio. Deduplicación por
evento/destinatario; fallar push no deshace la operación. Sin dispositivos sigue
visible en la bandeja. Push de pantalla bloqueada sin datos sensibles.

### Costos y decisiones antes de implementar

Google Maps se factura aparte del almacenamiento Firebase. Routes con tráfico
usa tarifa Pro; más paradas/optimización puede cambiar consumo. Compute Routes
admite hasta 25 puntos intermedios: para más, dividir cuidadosamente o evaluar
optimización de flota, no asumir un límite de estudiantes equivalente a paradas.
Places usa sesiones y campos mínimos. Configurar cuotas, alertas y alternativa
manual; no prometer gratuidad ni tratar alerta de presupuesto como corte duro.

Faltan decisiones: quién conduce/acompaña (¿docente o nuevo rol?), rutas y
vehículos por sede, paradas promedio, horarios/sentidos, hora límite para cambios,
cobertura, espera máxima, adulto autorizado en regreso y necesidad de seguimiento
con pantalla bloqueada. No dar presupuesto sin estas cantidades.

Fuentes oficiales consultadas:
- https://developers.google.com/maps/documentation/routes/intermed_waypoints
- https://developers.google.com/maps/documentation/routes/usage-and-billing
- https://developers.google.com/maps/documentation/places/web-service/session-pricing

## Cierre de estabilidad del ciclo de Rutas (8 de septiembre de 2026)

Se validaron los estados sin asignación, pendiente, activo, finalizado, cancelado
y desconocido. Ninguno debe mostrar excepciones, códigos de Firebase ni trazas al
usuario. La pantalla presenta una explicación breve y, ante errores recuperables,
permite reintentar. Un recorrido pendiente o terminado sigue siendo consultable,
pero no abre el mapa; un estudiante recogido o ausente pierde acceso al GPS.

Los modelos toleran documentos incompletos sin cerrar la aplicación. El backend
rechaza estados, direcciones, coordenadas y respuestas de Maps inválidas mediante
errores controlados. Al finalizar, elimina la ubicación en vivo y conserva el
historial. La ruta física activa con mapa, movimiento y zoom fue comprobada en un
Galaxy Z Flip7; la prueba temporal de producción se eliminó después de usarla.

Pruebas automatizadas del cierre: 58 Flutter y 27 de Functions/seguridad de Rutas
y Push. Continúan siendo pruebas manuales obligatorias antes de Play: pérdida de
red durante un recorrido, GPS desactivado, aplicación en segundo plano y cierre
forzado/reapertura en el dispositivo.
