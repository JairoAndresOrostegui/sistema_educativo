# Eventos y QR: contrato de ampliación QA

Estado: implementación terminada; aceptación y despliegue QA en curso. Este
contrato no reemplaza el informe de verificación ni acredita producción.
Alcance aprobado: solo QA (`sistema-educativo-rl`). No publicar producción ni Play.

## Identidad y permisos

`school_events` es la única entidad operativa de Eventos. Un QR de tipo `event`
apunta a esa entidad; los antiguos identificadores aislados necesitan migración
única y revocación si no tienen un evento operativo. No mantener dos agendas.
El QR de usuario sigue siendo opaco y permanente hasta reemplazo o revocación.
Todos los roles pueden presentar su QR y abrir cámara. La resolución de una
identidad ajena exige contexto operativo autorizado. Escanear nunca confirma
asistencia, pagos, entrega ni recogida por sí solo.

Institución, sede, año activo, permisos, responsables, audiencia y vínculos se
revalidan en backend. Familiares usan el hijo activo seleccionado. Estudiantes
consultan; no reservan alimentos, registran pagos ni reciben permisos administrativos.

## Datos del evento

`schemaVersion: 2`, `eventType: student_presentation | parent_meeting`, `subtitle`
y `foodEnabled`. Alimentación solo en presentaciones. Datos opcionales:
`publicity: {text, url}` (anuncio/enlace HTTPS del colegio, no una red publicitaria)
y `requirements: [{id, label, instructions, targetType, completionType, required,
amountCop}]`. `targetType` es `student | family`; `completionType` es
`manual | attendance | payment`; `amountCop` es entero COP opcional.
La creación conserva lugar, fechas, audiencia, responsables y ciclo de vida actual.
Tipos y requisitos se editan en borrador; se congelan al publicar para no cambiar
el significado de cumplimientos ya registrados. Publicidad se configura junto
con el borrador. Los responsables actuales derivan siempre del evento padre.

`event_food_items`: evento y alcance, nombre, descripción opcional, precio entero
COP, activo y revisión. Admin administra; desactivar conserva pedidos históricos.
Sin inventario limitado en esta versión: son reservas anticipadas, no ventas con
existencias garantizadas. La interfaz debe decirlo claramente.

`event_food_orders`: un pedido por evento, estudiante y familiar. Líneas con id,
nombre y precio copiados por backend; cantidades enteras, total calculado en
backend. Familia crea/actualiza/cancela el propio antes del inicio del evento;
no puede cambiar precios ni marcar pagado/entregado. Un pedido pagado o entregado
no puede reescribirse desde un carrito. Personal autorizado registra pago y
entrega manual, con confirmación, revisión e historial. No hay pasarela ni cobros.

`event_materials`: material o traje, nombre, instrucciones, importe COP opcional,
dirección y enlace HTTPS opcionales, groupIds dentro de audiencia/carga docente,
activo y revisión. Admin y responsables docentes administran según alcance.
CreatedBy se conserva; acceso operativo se deriva de responsables actuales.

`event_requirement_completions`: evento, requisito, tipo e identidad de destinatario,
studentContextIds, completed, importe COP si corresponde, revisión, actor y fecha.
La asistencia de un familiar no marca al otro familiar ni al estudiante.
Admin/docente responsable registra y corrige explícitamente con motivo auditado;
familia solo consulta sus propios cumplimientos y los del hijo seleccionado.
Las nuevas colecciones incluyen institución y sede y están cerradas al cliente.

## APIs compartidas

Ampliar `guardarEvento`, `listarEventos` y respuestas de asistencia con los campos
básicos nuevos. Nuevas operaciones (todos los importes, fechas y permisos salen
validados del backend):

| API | Entrada | Salida |
|---|---|---|
| obtenerDetalleEvento | eventId, studentId? | event, foodItems, orders, materials, completions, participants, capabilities |
| guardarAlimentoEvento | eventId, itemId?, expectedRevision?, name, description?, priceCop, active | itemId, revision |
| reservarAlimentosEvento | eventId, studentId, expectedRevision (0 nuevo), requestId, lines [{itemId,quantity}], cancel?, expectedTotalCop? | orderId, revision, totalCop |
| gestionarPedidoEvento | eventId, orderId, expectedRevision, requestId, paymentState (pending/paid)?, deliveryState (pending/delivered)?, reason? | revision |
| guardarMaterialEvento | eventId, materialId?, expectedRevision?, kind (material/costume), name, instructions?, amountCop?, address?, url?, groupIds, active | materialId, revision |
| guardarCumplimientoEvento | eventId, requirementId, targetType, targetId, studentId, completed, expectedRevision (0 nuevo), requestId, reason?, qrPayload? | completionId, revision |

En detalle: `capabilities` incluye canConfigure, canManageMaterials,
canManageFulfillment, canOrder; `participants` solo para operadores autorizados,
con studentId, studentName, groupId y families [{id,name}]. El resto recibe lista
vacía. Pedidos usan familyId, studentId, paymentState, deliveryState, state
(reserved/cancelled), líneas y totalCop. Los timestamps serializados usan sufijo
Millis. Las definiciones de requisitos viajan en event.requirements.

Para operaciones nuevas, expectedRevision previene cambios perdidos y requestId
evita duplicar cumplimiento/pedido y avisos. Cancelados, archivados y años cerrados
no admiten escrituras. Un fallo de push no revierte una operación guardada.

## Integración QR

La ficha de Eventos se abre mediante EventsScreen(initialEventId: id). El lector
genérico puede abrir un evento vigente permitido. Desde Seguimiento se escanea
un usuario con contexto de evento, se elige el requisito y el hijo si procede,
y se confirma. El backend vuelve a validar QR y destinatario al guardar.
El puente de Rutas prepara la recogida del estudiante y requiere confirmación;
reutiliza operarRecorrido/pickup y su transacción, historial e idempotencia.
La vía manual permanece y no cambia las reglas de GPS ni de avisos por parada.

## Avisos, continuidad y QA

Reutilizar event_notification_events y cola push persistente. Novedades públicas
van a audiencia del evento; un pedido/cumplimiento solo a cuentas involucradas y
responsables/administración autorizados, nunca a familias ajenas. Revalidar cada
envío/reintento y no mostrar aceptación FCM como lectura o entrega.
Materiales, pedidos y checklist no crean responsables propios ni reasignan
autoría. El traslado docente cambia responsables del evento y así todo acceso
operativo; actualizar registro de carga y probar traslado/reversión.

QA tendrá ejemplos identificables para admin y Sara, conservando sus roles.
Los ejemplos y permisos se aplican con script QA-only, respaldo/revisión y log.
Pruebas automatizadas cubrirán permisos, estados, QR revocado, concurrencia,
precios manipulados, vínculos, cambio de hijo, traslados, GPS y outbox. Cámara,
GPS físico y recepción visible push requieren verificación en dispositivo real.
