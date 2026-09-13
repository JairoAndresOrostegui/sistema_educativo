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
| Herramientas de aislamiento y artefactos web | 11 aprobadas |
| Índices requeridos de QA | 86 READY, sin faltantes; 5 adicionales conservados |

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

No hay Android conectado al equipo de desarrollo (`adb devices` sin dispositivos).
Por tanto, las pruebas automatizadas de permisos, GPS, cámara y outbox no acreditan
lectura óptica real, movimiento del teléfono o recepción visible de push.

En QA, la ruta antigua de Sara conserva fechas de agosto de 2025 y recorridos
históricos abiertos. Se detectó mediante lectura; no se reasignó ni se cerró ese
historial ajeno como efecto secundario de Eventos. Para probar recogida/GPS con
Sara se necesita un recorrido vigente, iniciado por su responsable designado.
Ser superadministrador por sí solo no convierte a alguien en responsable del GPS.

## Estado de entrega

Despliegue de Functions, hosting, comprobación API real y aceptación visual en curso.
Actualizar esta sección con la evidencia final antes de entregar QA al usuario.
