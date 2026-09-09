# Auditoría de estabilidad de la prueba cerrada

Fecha de cierre técnico: 9 de septiembre de 2026.

## Resultado

Esta auditoría cubrió endurecimiento técnico y regresiones automatizadas de los
módulos desplegados. No constituye cierre funcional del sistema, aceptación del
colegio ni prueba física completa de cada flujo. Se revisaron: acceso y recuperación de cuenta,
tableros por rol, usuarios, matrículas, parámetros académicos, horarios,
autorizaciones, archivos, mensajería, notificaciones, QR, rutas, historiales y sitio
web institucional.

El hallazgo transversal fue la presentación directa de errores internos de Firebase
en varias pantallas. Se centralizó su conversión a mensajes breves en español y se
eliminaron de la interfaz los códigos, excepciones y trazas técnicas. También se
protegieron las suscripciones en tiempo real y las cargas iniciales ante pérdida de
Internet, permisos vencidos, cierre de sesión y respuestas incompletas.

## Casos endurecidos

- Acceso: credenciales inválidas, sesión vencida, restablecimiento y cambio de clave
  temporal del estudiante.
- Tableros: fallos en contadores de matrículas, autorizaciones y mensajes ya no
  interrumpen la pantalla.
- Usuarios y matrículas: altas, edición, importación, traslado docente, aprobación y
  correcciones muestran errores funcionales sin detalles internos.
- Horarios, parámetros y autorizaciones: carga, guardado, estado vacío y reintento.
- Archivos: reserva, subida, confirmación, descarga, eliminación y progreso de Storage.
- Mensajería y Push: carga, envío, lectura, silencios, reintento y renovación de token.
- QR: carga, selección, rotación y resolución de respuestas inválidas.
- Rutas: sin ruta, antes de iniciar, activa, finalizada, Maps no disponible y consulta
  sin permisos. Se mantienen los mensajes de dominio definidos para cada estado.
- Historiales: usuarios, accesos, archivos, horarios, rutas y recorridos toleran fallos
  de consulta, paginación y campos heredados incompletos.
- Sitio web: carga y guardado del editor sin exponer errores de Firebase.

## Alcance que no se debe considerar terminado

- El lector de cámara y las operaciones de asistencia, entrega o eventos por QR
  todavía no están implementados; la pantalla QR actual identifica y valida manualmente.
- El hallazgo del CRUD genérico de Parámetros se corrigió para la próxima entrega:
  la pantalla administra solo grupos y años lectivos, con alcance por sede,
  permisos granulares, Functions, historial y eliminación protegida. Los catálogos
  internos quedaron sin escritura directa ni CRUD administrativo.
- Lonchera, Restaurante y Eventos completos no son módulos operativos terminados.
- Rutas conserva pendientes avanzados: Places/pin, planificación futura,
  ida/regreso separados, relevo en recorrido, cola offline e historial unificado.
- Los avisos de recorrido permanecen en Rutas. No se debe crear un canal paralelo
  en Mensajería ni interpretar propuestas históricas como alcance vigente.

## Validación automatizada

- `flutter analyze`: aprobado sin observaciones.
- Todas las pruebas Flutter: aprobadas.
- ESLint de Functions: aprobado.
- Reglas de Firebase: 28 casos aprobados.
- Auth: 4 casos aprobados.
- Usuarios: 18 casos aprobados.
- Matrículas: 17 casos aprobados.
- Autorizaciones: 7 casos aprobados.
- Horarios: 9 casos aprobados.
- Archivos: 4 casos aprobados.
- Mensajería: 5 casos aprobados.
- Rutas: 27 casos aprobados.
- QR: 4 casos aprobados.
- Push: 3 casos aprobados.
- Compilación web de producción: aprobada.
- Compilación APK y AAB de producción: aprobada con Maps restringido al paquete y
  a los certificados configurados.

## Comprobación de producción, solo lectura

- 18 usuarios reales y 16 usuarios temporales de la prueba controlada.
- Auth, `users` y `user_directory`: 34 identidades coincidentes.
- 32 grupos y 2 años lectivos coherentes.
- 74 Cloud Functions activas después de incorporar consulta administrativa e
  impacto seguro de grupos académicos.
- Los endpoints de horarios, archivos, QR, historial de rutas y años lectivos
  rechazaron correctamente solicitudes sin autenticar.
- Siete imágenes de producción accesibles y ninguna referencia al bucket de QA.
- El conjunto temporal conserva `cleanupRequired: true` para retirarlo al finalizar
  la prueba cerrada.

## Trabajo manual que sigue siendo obligatorio

Las pruebas automatizadas no sustituyen el uso en dispositivos reales. Durante la
prueba cerrada se debe registrar, por lo menos una vez por cada rol:

1. Inicio y cierre de sesión.
2. Apertura de cada opción visible en el tablero.
3. Estado con datos y estado vacío.
4. Una operación permitida y una que el rol no debe poder realizar.
5. Cierre y reapertura de la aplicación.
6. Uso temporal sin Internet y posterior reintento.
7. Recepción y apertura de una notificación.

Rutas requiere además una prueba física de recorrido con GPS y Maps. Antes de la
siguiente carga en Play se revisan Android Vitals y el informe previo al lanzamiento.

## Próxima entrega

La versión cerrada activa es `1.0.0 (9)`. El AAB generado en esta auditoría confirma
que el código compila, pero conserva el código 9 y no debe subirse. Cuando se agrupen
los comentarios de los verificadores se incrementa a `versionCode 10`, se repite esta
validación y se publica una sola actualización estable en la pista cerrada.
