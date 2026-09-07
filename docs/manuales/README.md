# Manuales por perfil

Edición QA: septiembre de 2026. Estos documentos describen el alcance implementado,
no certifican que cada pantalla haya sido aceptada por el colegio en dispositivos.

- [Manual técnico](TECNICO.md): arquitectura, seguridad, operación y publicación.
- [Administración y superadministración](ADMINISTRACION.md).
- [Docentes y auxiliares responsables de ruta](DOCENTES.md).
- [Estudiantes](ESTUDIANTES.md).
- [Familiares](FAMILIARES.md).
- [Referencia transversal por módulo](../MANUAL_USUARIO.md).

Orden de lectura: manual del perfil, referencia transversal y, para desarrollo,
manual técnico más AGENTS.md y GUIA_DESARROLLO.md. Los permisos de la cuenta pueden
ocultar acciones descritas: el rol no concede automáticamente todos los módulos.
Un módulo futuro o una pantalla residual no representa una función disponible.

## Inventario y alcance

| Módulo | Responsable | Destinatarios / límites |
|---|---|---|
| Acceso, Inicio, Perfil | Cada usuario | Solo perfil propio; cuentas adultas verifican correo |
| Usuarios y continuidad | Administración | Sede propia; superadmin transversal |
| Parámetros, grupos y años | Administración | Grupos independientes por sede y año |
| Matrículas | Administración; familiar en su contexto | Solicitud, revisión y decisiones auditadas |
| Autorizaciones | Administración y familiares | Estudiante no accede; docente no adquiere funciones futuras |
| Horarios | Administración | Consulta por grupo/docente; familiar por hijo |
| Archivos | Administración/docente autorizado | Audiencia explícita; docente no elimina |
| Mensajería | Miembros vigentes | Grupo y privados con reglas de relación |
| Rutas | Admin configura; responsable opera | Familia/estudiante solo su parada y ventana GPS |
| QR | Usuario propio; admin gestiona | Identificación, no firma ni autorización |
| Sitio web y formularios públicos | Admin autorizado | Público consulta; constructor no es módulo académico |
| Historial y fallos push | Admin / superadmin según módulo | Sin edición libre ni exposición de tokens |
| Lonchera, restaurante, eventos completos | Pendiente | Canales/identificadores no equivalen a módulos operativos |

## Cómo reportar un fallo

Anotar módulo, fecha/hora, rol, sede, hijo seleccionado y pasos; adjuntar captura
sin documentos, contraseñas, QR ni datos de terceros. Indicar resultado esperado
y observado. En notificaciones: Android/web, permiso, pantalla abierta/bloqueada,
último inicio de sesión y hora del aviso. No repetir operaciones de recogida o
eliminación a ciegas: consultar primero su estado e historial.
