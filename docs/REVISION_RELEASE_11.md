# Revisión y despliegue de 1.0.0 (11)

## Estado al 11 de septiembre de 2026

La versión 10 es la última confirmada por la API en la prueba cerrada Alpha.
QA ya tiene la versión 11: 108 Functions activas, reglas Firestore/Storage,
índices y web. Producción tiene índices, migraciones, reglas Firestore y las
108 Functions nuevas activas. Web de producción y Play aún pendientes.

La captura de Autorizaciones no identifica la versión instalada. Se comprobaron
accesos recientes de versiones 8, 9 y 10, pero no se puede atribuir esa captura
a una de ellas. La consulta antigua de hijos sí pasó su reproducción en emulador;
no se la considera causa demostrada del error del tester.

El historial sí muestra un diálogo antiguo que imprimía `error.toString()` en
la lista familiar. La versión 10 ya humanizaba ese punto, aunque su conversión
de errores todavía podía dejar pasar cadenas envueltas con `cloud_firestore`.
La versión 11 cubre ese formato y muestra el fallo de carga dentro de la pantalla
con Reintentar. Esto no identifica retrospectivamente la versión de la captura.

La ampliación de regresiones visuales detectó dos ajustes adicionales antes de
enviar el AAB: Asistencia/Eventos conservaban brevemente tarjetas del hijo
anterior al cambiar de selección; ahora las limpian, descartan respuestas
antiguas y restauran solo una selección válida ante un fallo. Las tarjetas de
Autorizaciones ocultaban la tinta Material bajo un fondo opaco, lo que el SDK
actual reportaba en modo de pruebas; se corrigió sin atribuirle el error de
permisos de la captura. Se reconstruyen los tres artefactos con estos cambios.

## Cambios revisados

| Área | Correcciones o controles de esta revisión |
|---|---|
| Acceso y perfil | Verificación de correo para adultos, clave temporal, estados de sesión y conservación de la foto nueva ante fallo de limpieza. |
| Usuarios y configuración | Alcance institucional, permisos reservados, consultas administrativas y continuidad docente. |
| Matrículas | Opciones públicas limitadas a la configuración vigente; errores recuperables sin inventar catálogos ni año. |
| Autorizaciones | Estados sin grupo, cambio de hijo, permisos y mensajes comprensibles; notificaciones a familiares activos. |
| Horarios | Cruces, alcance y edición concurrente con regresión automatizada. |
| Archivos | Eliminación reintentable, Storage antes de metadatos, cuota descontada una vez y descargas autenticadas. |
| Mensajería | Canal vigente, lecturas independientes, adjuntos privados, cancelación y retención sin huérfanos. |
| Rutas | Privacidad del GPS, ventana de consulta, alcance familiar, avisos y estados operativos. |
| QR | Credencial opaca, permisos, revocación y lector con alternativa manual. No ejecuta asistencia por sí solo. |
| Historial | Selector de grupos administrativo autorizado y carga/exportación con errores controlados. |
| Sitio web | Alcance explícito, publicación concurrente, formularios y apertura segura de enlaces. |
| Asistencia | Cierre y corrección concurrentes, consulta familiar, avisos y alcance docente vigente. |
| Eventos | Audiencias grandes, cancelación, recordatorios paginados, responsables y registro por bloques. |
| Push | Revalidación de destinatarios en reintentos; un error de payload no elimina tokens válidos. |

## Orden de despliegue

Comprobado: 84 índices requeridos READY en cada proyecto, 32 creados en cada
uno; se conservaron los 5 adicionales de cada entorno. Migración de alcance
aplicada a 7 documentos por entorno. Permisos de Asistencia/Eventos verificados
en 29 usuarios de QA y 34 de producción. Direcciones privadas retiradas de la
proyección pública de 4 usuarios QA y 5 de producción, sin alterar su perfil.

1. Crear únicamente los índices faltantes y comprobar que estén READY.
2. Migrar alcance del sitio, permisos nuevos y proyección pública del directorio.
   Conservar usuarios y datos temporales de las pruebas. Las migraciones son
   idempotentes y no borran direcciones del perfil privado de los usuarios.
3. Publicar backend, reglas y web en QA; comprobar servicios y cargas.
4. Publicar backend y web de producción y enviar el AAB 11 a Alpha.
5. Confirmar disponibilidad del AAB antes de activar las reglas finales de
   descarga privada de Storage en producción. Con esas reglas, clientes antiguos
   deberán actualizar para descargar documentos y adjuntos.

Las descargas nuevas pasan por dos endpoints autenticados que revalidan sesión,
permisos, alcance y destinatario. Responden con un buffer limitado a 25 MiB y sin
enlaces públicos reutilizables. Las reglas Storage permiten como máximo dos
lecturas de documentos Firestore, por lo que no se usa ese mecanismo para
resolver toda la cadena de permisos de una descarga.

Las URLs de descarga que hayan sido emitidas antes de esta revisión pueden
seguir funcionando por su token. Las reglas por sí solas no revocan esos enlaces.
En QA se inventariaron cuatro archivos privados: tres MIME corregidos por firma
y cuatro tokens revocados, sin cambiar bytes, generación ni audiencia. Quedó
auditoría y respaldo privado ignorado por Git. Producción no tenía archivos ni
adjuntos en este inventario. Las nuevas confirmaciones revocan tokens antes de
publicar; si falla la revocación conservan una reserva reintentable.

## Límites de la validación

Validación local final: `flutter analyze` sin observaciones, 100 pruebas Flutter,
lint completo de Functions y 11 pruebas de herramientas aprobados. Compilaciones
web QA y producción y AAB de producción 11 completadas. Firma del AAB verificada.
SHA-256 del AAB final recompilado: `836138f3e53235b9adbd27056731bb0692d9ef034015d32811d7b9e606654598`.

Las suites de backend incluyeron: Firestore 31, GPS 6, Usuarios 29, QR 4,
Horarios 9, Autorizaciones 9, Matrículas 21, Archivos/limpieza 11,
Mensajería 8, limpieza de adjuntos 7, Storage 9, Rutas operativas 18,
Push 5, dispositivos 3, funciones de notificación 7, Sitio web 3,
Asistencia 7, Eventos 10, acceso push académico 5 y descargas HTTP 20 más
3 pruebas de límite de bytes y tokens. Auth conserva 4 regresiones aprobadas.

Validación real QA: nueve endpoints deniegan anónimo; matrícula pública devuelve
30 grupos, 28 EPS y 14 tipos de documento. Las 16 cuentas de la guía pertenecen a
producción y no existen en QA, por lo que no se hicieron logins con ellas en QA.
Los endpoints HTTP privados deniegan anónimo y origen de producción, aceptan
preflight QA; lectura administrativa de un PDF existente comprobada, sin
confundirla con una descarga autenticada de usuario final.

Validación real inicial en producción: login de las 16 cuentas temporales de la
guía, sin cambiar contraseñas, datos, contextos familiares ni slots push. Los dos
administradores, dos docentes y ocho familiares consultaron Autorizaciones con
HTTP 200; los cuatro estudiantes recibieron el 403 esperado. También pasaron
perfil, hijos/directorio, grupos, horarios, archivos, eventos, asistencia y la
restricción del listado QR administrativo. De 190 verificaciones, la única
pendiente durante el despliegue fue matrícula pública (404); al publicarse su
servicio respondió 200 con 32 grupos, una institución, 28 EPS y 14 documentos.
Ronda final, con backend actualizado: las 190 comprobaciones pasaron con las
16 cuentas. El inventario confirmó 108 Functions ACTIVE, ningún índice faltante
o pendiente y ningún adulto activo sin verificación de correo.

Chrome headless comprobó página comercial y login de QA 11: ambas renderizan,
sin excepciones ni fallos de red/HTTP. El primer smoke detectó un artefacto QA
incompleto porque Flutter usa `build/web` como carpeta intermedia y mueve assets
al compilar otra salida. Se corrigió: publicar exclusivamente `build/web-qa` o
`build/web-prod`, verificar manifiestos, fuentes y workers antes de desplegar;
flujos CI actualizados. Nunca publicar la carpeta intermedia `build/web`.

No se inició sesión de navegador con los fixtures compartidos: el flujo real
reclama el slot push web antes de pedir permiso de notificaciones, de modo que
incluso un Chrome con permiso denegado desplazaría al último tester. La evidencia
de pantallas internas corresponde a Flutter y la de permisos desplegados a
peticiones autenticadas, no a una navegación visual de todos los roles.

Las pruebas automatizadas no garantizan ausencia absoluta de defectos. Queda
aceptación física por rol: cámara, GPS, segundo plano, notificaciones, descarga
en Android y navegador, red intermitente y reapertura. Las ampliaciones pendientes
siguen en la hoja de ruta; no se consideran terminadas por publicar esta versión.

Google Play no obliga automáticamente a instalar una actualización. La aplicación
no incorpora todavía una política de versión mínima ni un flujo de actualización
inmediata. Los verificadores actualizan desde Play o mediante actualización
automática si la tienen habilitada.
