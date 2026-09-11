# Hoja de ruta y pendientes — septiembre de 2026

## Estado de las entregas

El estado comprobado de la revisión del 11 de septiembre y su despliegue está en
[REVISION_RELEASE_11.md](REVISION_RELEASE_11.md). El código local de esa revisión
no debe confundirse con la versión que tienen instalada los verificadores.

- Producción web: versión 11 publicada y comprobada en Chrome.
- Google Play, prueba cerrada Alpha: `1.0.0 (11)` enviada; la API confirma
  `completed`. Falta comprobar en Play Console la disponibilidad para testers.
- QA web: versión 11 publicada y comprobada en
  `https://sistema-educativo-rl.web.app` el 11 de septiembre de 2026.
- Backend QA y producción: 108 Functions ACTIVE por entorno; reglas, índices
  y migraciones verificados. Pruebas finales: 124 Flutter y 190 comprobaciones
  autenticadas/de acceso con las 16 cuentas temporales en producción.

La aprobación automatizada indica que el código soporta los casos cubiertos;
no sustituye la aceptación funcional en navegador y dispositivos reales.

## Prioridad 0 — cerrar Google Play sin perder la prueba

1. Mantener al menos 12 verificadores inscritos continuamente durante 14 días.
2. Confirmar que todos instalaron o actualizaron a la versión 11 cuando esté
   disponible; documentos y adjuntos nuevos la requieren. Conservar
   evidencia de las funciones que probaron y de sus comentarios.
3. Probar en teléfonos reales: permisos, notificaciones, archivos, cámara,
   pérdida de red, cierre y reapertura de la aplicación.
4. Revisar Android Vitals y el informe previo al lanzamiento antes de promover.
5. Cuando Play habilite el botón, solicitar acceso a producción y responder el
   cuestionario con los resultados reales de la prueba.
6. Dar seguimiento al caso del aviso de cuenta inactiva hasta que Play lo retire.
7. Después de terminar la prueba, eliminar mediante el procedimiento controlado
   los usuarios y datos marcados `cleanupRequired: true`.

Publicar una actualización en la misma pista no reinicia por sí sola el plazo:
el requisito se refiere a verificadores inscritos de forma continua, no a un
`versionCode` específico.

## Prioridad 1 — aceptación funcional de lo que ya existe

Cada módulo debe comprobarse con todos los roles que lo usan, en QA y luego en
producción cuando corresponda. La revisión mínima incluye: datos existentes,
estado vacío, permiso permitido, permiso denegado, sesión vencida, ausencia de
Internet, reintento, pantalla pequeña y cierre/reapertura.

| Área actual | Estado técnico | Validación o ajuste pendiente |
|---|---|---|
| Acceso y Perfil | Auditado técnicamente | Backend, concurrencia, clave temporal, foto, sesión vencida y estados controlados cubiertos; falta aceptación física móvil/web. |
| Gestión de usuarios | Auditada técnicamente | Altas, edición versionada, bajas, vínculos, importación y continuidad docente cubiertos; falta aceptación física por rol. |
| Configuración académica | Auditada técnicamente | Grupos, años, EPS y documentos usan Functions, alcance por sede, historial y control de concurrencia; falta aceptación física admin/superadmin. |
| Matrículas | Auditada técnicamente | Flujo, transiciones, concurrencia, año/grupo, familiar e historial cubiertos; falta aceptación física completa. |
| Horarios | Auditados técnicamente | Cruces, edición concurrente, año activo, grupos, docente y familiar por hijo cubiertos; falta aceptación física. |
| Autorizaciones | Auditadas técnicamente | Hijo seleccionado, corrección, decisiones concurrentes, cierre y reapertura superadmin cubiertos; falta aceptación física. |
| Lista de asistencia | Auditada técnicamente y desplegada | Sesiones, cierre, corrección, reportes, consulta por hijo y recuperación de errores cubiertos; falta aceptación física y trabajo sin conexión. |
| Eventos | Auditado técnicamente y desplegado | Audiencias, estados, respuestas familiares, asistencia, recordatorios y cambio de hijo cubiertos; falta aceptación física y ampliaciones listadas abajo. |
| Documentos | Auditados técnicamente | Audiencias, cuota, tamaño, confirmación, descargas y eliminación segura cubiertos; falta aceptación física. |
| Mensajería | Auditada técnicamente | Canales supervisados, lecturas independientes, privacidad, cambios de vínculo, push y adjuntos con cuota/retención/descarga individual cubiertos; falta aceptación física por rol. |
| Administrar rutas | Auditada técnicamente | Creación versionada, vigencia, responsable designado, participantes activos y únicos, conductor por sede, baja lógica, solicitudes familiares y bloqueo al iniciar cubiertos; falta aceptación física administrativa. |
| Operar recorrido / Mi ruta escolar | Auditada técnicamente | Estados vacío/inactivo/finalizado, privacidad GPS, operación idempotente, avisos, cierre y errores controlados cubiertos; falta prueba física con GPS, Maps, segundo plano, red intermitente y reapertura. |
| Historial administrativo | Auditado técnicamente | Alcance por sede, permiso exclusivo, recorridos y participantes, filtros sobre todo el rango, conteos exactos, cursores, fechas dañadas y exportación de la página visible cubiertos; falta aceptación web con datos reales. |
| QR de identificación | Auditado técnicamente, incluida cámara | Token opaco, alcance, estado, año, familiar por hijo, baja en cascada, revocación/reemplazo y lectura por cámara o manual cubiertos. Falta aceptación física de permiso, linterna, cambio de cámara y dispositivo sin cámara. Las operaciones reales siguen separadas. |
| Sitio web | Auditado técnicamente | Esquema v5, formulario vigente, aislamiento, publicación, imágenes y bandeja cubiertos. Público/login QA y producción cargan en Chrome sin excepciones o fallos de red; falta aceptación autenticada del editor y revisión de fuentes en el resto de pantallas. |
| Notificaciones y panel Push | Auditado técnicamente | Cola de 500, reintentos, revalidación de audiencia, retiro seguro de tokens terminales, slots móvil/web, avisos web simultáneos, destinos por rol y panel superadmin cubiertos; falta aceptación física con la app en frente, fondo, cerrada y sin red. |

Los dos accesos de Rutas son intencionales para administración: **Administrar
rutas** configura plantillas, estudiantes y responsables; **Operar recorrido**
ejecuta el recorrido cuando ese administrador fue designado responsable. Para
docente o auxiliar también aparece **Operar recorrido**; para estudiante o
familiar, **Mi ruta escolar**. Esta diferencia ya está reflejada en el panel.

## Prioridad 2 — ampliaciones de módulos existentes

### Adjuntos en Mensajería — implementación técnica terminada

- PDF, Word y Excel, máximo 25 MiB, cuota institucional compartida de 1 GiB y
  retención de 60 días.
- Reserva y confirmación backend, enlace transaccional único al mensaje y
  compensación de cuota ante fallos.
- Descarga solo para miembros vigentes y acuse independiente por cuenta, sin
  modificar la lectura de otros destinatarios.
- Pendiente: aceptación física en web y Android con archivos reales.

### QR con cámara — implementación técnica terminada

- Escáner Android, iOS y web con permiso de cámara, linterna, cambio de cámara
  y alternativa manual.
- Solo acepta el formato opaco `LLQ1`; la resolución ocurre en backend
  autenticado y registra actor, fecha, origen y plataforma.
- La respuesta muestra identidad vigente y recuerda que no ejecuta ninguna
  operación. Los códigos inválidos permanecen en el lector sin navegar.
- Pruebas Flutter y de Functions cubren formato, resolución y auditoría.
- Pendiente: aceptación en equipos reales de permiso denegado, reintento,
  linterna, cámara frontal/trasera y navegador sin cámara.

### Rutas avanzadas

- Paradas como entidades con coordenadas confirmadas, Places y pin.
- Ida y regreso como recorridos distintos y planificación de fechas futuras.
- Relevo controlado de responsable/auxiliar durante una operación.
- Cola offline idempotente y resolución de conflictos al recuperar conexión.
- Unificar el historial heredado.
- Agrupar hermanos por parada real, no únicamente por texto de dirección.
- Completar pruebas de GPS apagado, segundo plano, teléfono bloqueado, cierre
  forzado, red intermitente y apertura de cada notificación.

### Pulido transversal

- Implementado fallback local Noto Sans para caracteres que no cubra la fuente
  institucional; falta confirmar en el navegador publicado que desaparezca la
  advertencia.
- El favicon fuente y `web/favicon.png` son idénticos; falta confirmar después
  de limpiar caché y en una instalación PWA.
- Revisar accesibilidad: textos grandes, contraste, teclado, lector de pantalla
  y pantallas angostas.
- Mantener revisión de costos y cuotas por institución, sede y módulo.

## Prioridad 3 — módulos nuevos

### Lista de asistencia

El núcleo manual confiable quedó implementado. La cámara QR será una ayuda futura,
no un requisito ni una prueba automática de presencia.

- Jornada o sesión ligada a `institutionId`, `campusId`, `academicYearId` y
  `groupId`; opcionalmente horario/asignatura/docente.
- Lista congelada de estudiantes activos al abrir la sesión.
- Estados presente, ausente, tarde y excusado, con observación y corrección
  auditada; una sola marca efectiva por estudiante y sesión.
- Docente solo para grupos/asignaturas de su carga; administrador dentro de su
  sede; superadministrador con selector de alcance.
- Familias y estudiante consultan solo el registro propio, con hijo activo.
- Notificación de ausencia/tardanza sin exponer otros estudiantes.
- Implementado: sesiones únicas por fecha/grupo/asignatura, lista congelada,
  cuatro estados, observación, revisión optimista, cierre completo, historial,
  corrección administrativa y aviso de ausencia, tardanza o corrección.
- Implementado: lectura propia del estudiante y por hijo activo para familiares;
  solo se muestran sesiones cerradas.
- Implementado: reporte de hasta un año, filtro por grupo y exportación Excel web.
- Pendiente: cola de trabajo sin conexión, aceptación física y ayuda opcional por QR.
- Integración obligatoria con traslado docente, reemplazo temporal y reversión
  en `REGISTRO_CARGA_DOCENTE.md`.
- Backend, reglas, pruebas de duplicados/concurrencia y funcionamiento sin red.

### Eventos

El núcleo quedó implementado, migrado y desplegado en QA y producción. La
versión Android 11 fue enviada a Alpha; queda aceptación física:

- Creación, borrador, publicación, cierre, cancelación y archivo por sede.
- Audiencia institucional, por grupos o por estudiantes específicos,
  materializada de nuevo al publicar y validada en backend.
- Fecha, lugar, descripción, responsables y enlaces HTTPS.
- Confirmación/cupo y autorización familiar; solo el familiar responde por el menor.
- Asistencia independiente, selección explícita, revisión optimista e historial.
- Consulta familiar por hijo, notificaciones y cambios/cancelaciones.
- Reporte por rango y exportación Excel web, sin mezclar eventos con la
  asistencia académica diaria.
- Implementado: recordatorio automático único durante las 24 horas previas,
  con audiencia congelada al publicar e idempotencia ante reintentos.
- Pendiente: adjuntos propios con cuota/retención, apoyo opcional por QR y
  trabajo sin conexión.

### Lonchera y Restaurante

Hoy existen datos de matrícula y tipos de canal, pero no módulos operativos
completos. Falta definir y construir planes/menús, inscripción, novedades,
entregas o consumo, responsables, permisos, reportes, notificaciones e historial.
No deben presentarse como terminados por aparecer como opción de Mensajería.

## Orden recomendado de ejecución

1. Confirmar disponibilidad de la versión 11 y mantener/documentar la prueba cerrada.
2. Ejecutar la matriz de aceptación de los módulos actuales y corregir hallazgos.
3. Validar físicamente el lector QR con cámara ya implementado.
4. Validar físicamente y completar reportes/exportación de Lista de asistencia.
5. Validar Eventos en dispositivos reales; completar sus ampliaciones no críticas.
6. Completar Rutas avanzadas.
7. Definir con el colegio el alcance real de Lonchera y Restaurante antes de
   programarlos.
