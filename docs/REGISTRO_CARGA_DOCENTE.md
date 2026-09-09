# Registro universal de carga y continuidad docente

Este documento es obligatorio antes de crear o ampliar cualquier módulo que
asigne responsabilidad, acceso o trabajo vigente a un docente.

## Principios

- Toda carga operativa pertenece a una institución, sede y año lectivo.
- Un reemplazo solo ocurre dentro de la misma institución, sede y año activo.
- El docente saliente se desactiva en Auth y Firestore al ejecutar el traslado.
- La autoría histórica nunca se modifica. `senderId`, `uploadedBy`, creador y
  registros de auditoría conservan al usuario original.
- El reemplazo puede ser un docente activo existente. Se recomienda que no
  tenga carga; combinar cargas requiere confirmación explícita y cero choques.
- Un traslado temporal es reversible. Al restaurar, solo se recuperan
  responsabilidades que todavía continúen en el reemplazo.

## Inventario de adaptadores

| Módulo | Responsabilidad vigente que se traslada | Historia que no se toca |
|---|---|---|
| Horarios | `subjects.teacherId`, nombre derivado y revisión | historial previo |
| Dirección de grupo | `users.tutorGroupId` | años cerrados |
| Mensajería | membresía de canales académicos por `subjects.teacherId` o `tutorGroupId`, publicación en canales de servicio y rol de personal en `supervised_student` | mensajes, autor, audiencia enviada, secuencia y lecturas históricas por cuenta |
| Archivos | acceso delegado a publicaciones vigentes | autor, fecha de carga y acuses de descarga |
| Rutas | gestionador y rutas diarias abiertas | recorridos finalizados |
| Autorizaciones | responsabilidad derivada del grupo | decisiones previas |
| Matrículas | responsabilidad derivada del grupo | formularios previos |
| Notificaciones | destinatarios futuros derivados | eventos ya enviados |

Los reintentos push comprueban que el docente siga activo y conserve membresía
en el canal. No se cambia la autoría ni se trasladan tokens del saliente al
reemplazo; este último recibe avisos futuros según su acceso vigente.
Los avisos operativos se publican y consultan dentro de Rutas, por decisión del
colegio. No se agrega una membresía de chat para el viaje. La ubicación privada
deriva acceso del gestionador actual del recorrido, por lo que el traslado docente
vigente aplica sin copiar coordenadas, ventanas ni autoría del historial.

Rutas usa ahora `route_history`, `route_push_events` y operaciones idempotentes
del recorrido. `performedBy` y eventos anteriores no se trasladan. El impacto y
aplicación del traslado excluyen expresamente `estado == finalizada`.
Las hojas de vida `route_drivers` no son usuarios ni cargas docentes.
Auxiliar es una cuenta operativa limitada a Perfil, QR y recorrido asignado;
no adquiere asignaturas ni permisos docentes por ese rol. El traslado académico
existente sigue siendo entre docentes; el relevo operativo de auxiliares durante
un viaje necesita un flujo específico y no debe simularse alterando la autoría.

## Contrato para módulos futuros

QR identifica al docente, no representa carga transferible: su credencial nunca
se entrega al reemplazo, quien usa la propia. La desactivación del saliente
bloquea su resolución. Los identificadores de eventos actuales no asignan
responsables; antes de añadirlos, integrar el evento al contrato de traslado.

Antes de considerar terminado un módulo nuevo se debe documentar:

1. Documentos que representan responsabilidad docente activa.
2. Campos de autoría histórica que son inmutables.
3. Cálculo de impacto previo sin modificar datos.
4. Conflictos que impiden combinar cargas.
5. Aplicación y reversión sin datos huérfanos.
6. Pruebas de emulador para traslado, bloqueo y reversión.

Si existe carga docente, se agrega una fila al inventario y se integra en
`teacherTransferContext`, `ejecutarTrasladoDocente` y
`revertirTrasladoDocenteTemporal`. No se acepta un proceso manual paralelo.

## Año lectivo universal

- `academic_years/{academicYearId}` define cada período por institución/sede.
- Estados: `draft`, `active` y `closed`.
- `academic_year_settings` apunta al único año activo de la sede.
- Grupos, matrículas, horarios, autorizaciones, archivos, conversaciones,
  rutas, notificaciones e historiales operativos llevan `academicYearId` y
  `academicYear`.
- Un año cerrado es de solo lectura. Usuarios, Perfil y Sitio web no se
  reinician.
- Cada `academic_groups/{groupId}` tiene un único canal general. La membresía
  docente se recalcula al cambiar una asignatura o dirección de grupo. El
  traslado reemplaza al responsable docente en conversaciones supervisadas vigentes y retira al saliente de los
  canales académicos sin reescribir mensajes.
- El cambio de año es asistido: preparar, revisar y activar. Nunca ocurre
  automáticamente el 1 de enero.
