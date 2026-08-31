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
| Mensajería | acceso delegado a conversaciones vigentes | mensajes y remitente |
| Archivos | acceso delegado a publicaciones vigentes | autor y fecha de carga |
| Rutas | gestionador y rutas diarias abiertas | recorridos finalizados |
| Autorizaciones | responsabilidad derivada del grupo | decisiones previas |
| Matrículas | responsabilidad derivada del grupo | formularios previos |
| Notificaciones | destinatarios futuros derivados | eventos ya enviados |

## Contrato para módulos futuros

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
- El cambio de año es asistido: preparar, revisar y activar. Nunca ocurre
  automáticamente el 1 de enero.
