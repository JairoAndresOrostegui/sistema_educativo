# Hoja de ruta y pendientes — septiembre de 2026

## Estado de las entregas

- Producción web: versión vigente del código publicada.
- Google Play, prueba cerrada Alpha: `1.0.0 (10)` activa.
- QA web: versión vigente publicada en
  `https://sistema-educativo-rl.web.app` el 9 de septiembre de 2026.
- QA backend: reglas, Functions afectadas y migraciones de catálogos y
  mensajería supervisada publicadas y verificadas.

La aprobación automatizada indica que el código soporta los casos cubiertos;
no sustituye la aceptación funcional en navegador y dispositivos reales.

## Prioridad 0 — cerrar Google Play sin perder la prueba

1. Mantener al menos 12 verificadores inscritos continuamente durante 14 días.
2. Confirmar que todos instalaron o actualizaron a la versión 10 y conservar
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
| Acceso y Perfil | Operativo | Recuperación, clave temporal de estudiante, sesión vencida, foto y cierre de sesión en móvil/web. |
| Gestión de usuarios | Operativo | Altas, bajas lógicas, vínculos familiares, importación, traslados y reversión con cada alcance de administrador. |
| Configuración académica | Operativo | Probar grupos, años, EPS y documentos con administrador de sede, solo lectura y superadministrador. |
| Matrículas | Operativo | Recorrer solicitud, corrección, aprobación, rechazo, retiro, cambio de grupo y selección de hijo. |
| Horarios | Operativo | Probar cruces, edición concurrente, grupos/secciones, consulta docente y consulta familiar por hijo. |
| Autorizaciones | Operativo | Probar solicitud familiar, decisión, corrección, finalización inmutable y ausencia total para estudiante. |
| Documentos | Operativo | Probar audiencias, cuota, límite, enlaces, descarga, acuse individual y eliminación/limpieza reintentable. |
| Mensajería | Actualizada | Validar el canal supervisado estudiante–personal–familiares, pendientes independientes, `Leído por`, descarga de adjuntos, silencios y cambios de grupo/vínculo. |
| Gestión de rutas | Operativo básico | Validar creación y asignación administrativa, capacidad, solicitud familiar y bloqueo de paradas al iniciar. |
| Mis recorridos / Ruta escolar | Operativo básico | Prueba física completa con responsable, GPS, Maps, segundo plano, red intermitente, reanudación y cierre. |
| Historial administrativo | Operativo | Verificar filtros, paginación, alcances y exportaciones de usuarios, accesos, documentos, horarios, rutas y recorridos. |
| QR de identificación | Parcial | Emisión, consulta, revocación y reemplazo funcionan; falta lectura por cámara y operaciones reales asociadas. |
| Sitio web | Operativo web | Editor, publicación, formulario, imágenes, móvil/escritorio, favicon y caracteres que disparan la advertencia de fuentes Noto. |
| Notificaciones y panel Push | Operativo | Recepción visible, apertura hacia el destino correcto, slots móvil/web, reemplazo de sesión, fallos y reintento superadmin. |

Los dos accesos de Rutas son intencionales para administración: **Gestión de
rutas** configura plantillas, estudiantes y responsables; **Mis recorridos**
ejecuta el recorrido cuando ese administrador fue designado responsable. Para
docente o auxiliar solo aparece **Ruta escolar**; para estudiante o familiar,
**Mis rutas**. Queda pendiente hacer más clara esta diferencia en la interfaz.

## Prioridad 2 — ampliaciones de módulos existentes

### QR con cámara

- Escáner móvil con permiso de cámara, reintento y alternativa manual.
- Resolver únicamente identificadores opacos mediante backend autenticado.
- Mostrar identidad/estado/alcance antes de confirmar cualquier acción.
- Evitar duplicados y registrar actor, fecha, dispositivo y resultado.
- El QR identifica; nunca autoriza por sí solo asistencia, entrega o acceso.

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

- Corregir o descartar con evidencia la advertencia web de glifos Noto.
- Verificar favicon e icono del sitio después de limpiar caché y en instalación PWA.
- Revisar accesibilidad: textos grandes, contraste, teclado, lector de pantalla
  y pantallas angostas.
- Mantener revisión de costos y cuotas por institución, sede y módulo.

## Prioridad 3 — módulos nuevos

### Lista de asistencia

Primera entrega recomendada: registro manual confiable; la cámara QR se agrega
como mecanismo rápido, no como requisito ni prueba automática de presencia.

- Jornada o sesión ligada a `institutionId`, `campusId`, `academicYearId` y
  `groupId`; opcionalmente horario/asignatura/docente.
- Lista congelada de estudiantes activos al abrir la sesión.
- Estados presente, ausente, tarde y excusado, con observación y corrección
  auditada; una sola marca efectiva por estudiante y sesión.
- Docente solo para grupos/asignaturas de su carga; administrador dentro de su
  sede; superadministrador con selector de alcance.
- Familias y estudiante consultan solo el registro propio, con hijo activo.
- Notificación de ausencia/tardanza sin exponer otros estudiantes.
- Reportes por fecha, grupo y estudiante, exportación e historial inmutable.
- Integración obligatoria con traslado docente, reemplazo temporal y reversión
  en `REGISTRO_CARGA_DOCENTE.md`.
- Backend, reglas, pruebas de duplicados/concurrencia y funcionamiento sin red.

### Eventos

- Creación, borrador, publicación, cierre, cancelación y archivo por sede.
- Audiencia institucional, por grupos o estudiantes, siempre materializada y
  validada en backend.
- Fecha, lugar, descripción, responsables, adjuntos y recordatorios.
- Inscripción/cupo cuando aplique y autorización familiar separada cuando el
  evento involucre menores, salidas o recogida especial.
- Asistencia del evento como entidad propia, manual o apoyada por QR, con
  protección contra duplicados y auditoría.
- Consulta familiar por hijo, notificaciones y cambios/cancelaciones.
- Historial y reportes sin mezclar eventos con la asistencia académica diaria.

### Lonchera y Restaurante

Hoy existen datos de matrícula y tipos de canal, pero no módulos operativos
completos. Falta definir y construir planes/menús, inscripción, novedades,
entregas o consumo, responsables, permisos, reportes, notificaciones e historial.
No deben presentarse como terminados por aparecer como opción de Mensajería.

## Orden recomendado de ejecución

1. Mantener y documentar la prueba cerrada de la versión 10.
2. Ejecutar la matriz de aceptación de los módulos actuales y corregir hallazgos.
3. Terminar lector QR con cámara.
4. Construir Lista de asistencia sobre el modelo académico y QR ya definidos.
5. Construir Eventos y su asistencia independiente.
6. Completar Rutas avanzadas.
7. Definir con el colegio el alcance real de Lonchera y Restaurante antes de
   programarlos.

