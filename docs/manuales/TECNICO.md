# Manual técnico y de operación

## Fuentes y entorno

Contador de autorizaciones: `allCampuses` es explícito para superadmin; enumera
`academic_year_settings` y suma streams por institución/sede/año activo, sin
pasar scopes nulos ni quitar filtros. Firestore mantiene la autorización real.
`sumCountStreams` propaga errores y cancela todas sus suscripciones al salir.
El tablero captura errores del contador y libera también la suscripción de
mensajes al desmontarse. Pruebas: cero sedes, suma reactiva, errores y cancelación.

Leer AGENTS.md, [GUIA_DESARROLLO](../GUIA_DESARROLLO.md),
[REGISTRO_CARGA_DOCENTE](../REGISTRO_CARGA_DOCENTE.md) y el manual del perfil
antes de modificar módulos. Inventario funcional en [README](README.md).
Flutter sirve Android/web. Auth autentica; Firestore almacena; Functions valida
mutaciones; Storage conserva archivos; FCM transporta avisos. Firebase actual es
QA: sistema-educativo-rl. No usarlo como producción definitiva ni afirmar que el
APK local está publicado en Google Play.

Producción independiente: `sistema-educativo-rl-prod`. La configuración y el
estado de puesta en marcha se mantienen en
[SEPARACION_QA_PRODUCCION](../SEPARACION_QA_PRODUCCION.md). No confundir cuentas
importadas con un despliegue listo para uso. La migración inicial conserva UID y
contraseñas mediante SCRYPT en memoria, prepara perfiles inactivos y habilita el
conjunto solo después de verificar Auth y relaciones. Auditoría en
`migration_audit/production_core_v1`; no ejecutar borrados para reintentar.
`node functions/scripts/verify_production_core.js` verifica el estado inicial
limpio; después de iniciar operación real sus comprobaciones de colecciones
vacías dejarán de ser aplicables y no deben usarse para justificar limpiezas.

La recuperación estudiantil usa `restablecerClaveEstudiante` y
`cambiarClaveTemporalEstudiante`. La primera exige administrador con
`usuarios.editar`, sede coincidente y estudiante activo; marca primero el perfil,
actualiza Auth, revoca sesiones anteriores y registra auditoría sin almacenar la
clave. `getCaller` y las reglas bloquean los demás módulos mientras
`mustChangePassword` sea verdadero. La segunda solo admite al propio estudiante,
aplica la política de complejidad y elimina la marca junto con un log atómico.
Una falla de Auth revierte la marca; una falla posterior de auditoría conserva
la cuenta bloqueada para que administración repita la generación con seguridad.
Una clave temporal completada pero todavía no sustituida puede rotarse; el
marcador `passwordResetCompletedAt` diferencia esa rotación de una operación
concurrente aún en curso.

La migración de contenido visual usa `migrate_production_assets.js`: copia solo
objetos referenciados por el sitio y perfiles aprobados, valida generación y
CRC32C, registra el manifiesto antes de copiar y publica referencias al terminar.
No reutiliza URLs/tokens de QA ni borra el origen. Verificar con
`verify_production_assets.js`. Una foto cuyo objeto original falta queda vacía
y pendiente, nunca se sustituye silenciosamente por la de otra persona.

## Contrato transversal por módulo

| Área | Modelo / operación | Invariantes |
|---|---|---|
| Auth/Perfil | users, Firebase Auth, campos seguros | Estado activo; adulto verifica correo; estudiante no |
| Usuarios | Functions e historial, cascada controlada | Admin sede; superadmin definitiva; no huérfanos |
| Grupos | academic_groups, groupId | Institución/sede/año; no grade/grado libre |
| Años | academic_years, academic_year_settings | Un activo por sede, cerrado sin escrituras |
| Matrículas | enrollments, enrollment_history | Unicidad, transición transaccional e hijo validado |
| Autorizaciones | historial y estados | Familiar solo ver/solicitar, finalized inmutable salvo super |
| Horarios | subjects, schedule_history | Cruces, expectedRevision, docente y grupo activos |
| Archivos | files, cuota y Storage | Reserva, confirmación, borrar objeto antes de metadatos |
| Mensajería | message_channels, mensajes/lecturas | Miembros derivados, secuencia, privados restringidos |
| QR | qr_credentials, events, auditoría | Token opaco, revocación, sin autorización implícita |
| Web | website/config, website_pages | Esquema v5, filas/columnas, tema central, limpieza reintentable |
| Rutas | routes, daily_routes, route_history | Operador asignado; paradas bloqueadas al iniciar |
| Push | push_events/route_push_events, push_jobs | Lotes 500, reintento, tokens vigentes, sin garantía de entrega |

Esquemas exactos y permisos se verifican en Functions/reglas; una fila no reemplaza
validación de payload. No agregar escritura directa del cliente por conveniencia.

## Rutas: ventana privada de ubicación

El documento daily_routes conserva estado general, no GPS. La ubicación actual está
en daily_routes/{id}/live/location. Cada students/{id} tiene estimatedArrivalAt,
mapEnabled y, al abrir por avance, approachNotifiedAt. No almacenar listas de
direcciones/estimaciones ajenas en el documento que comparten familias.

operarRecorrido valida usuario, sede, asignación, año, estado e idempotencia.
position escribe ubicación y evalúa todas las estimaciones <= ahora + 10 minutos.
Cada parada abre una sola vez y crea un evento agrupado; nuevos GPS no repiten el
aviso. eta/arrival manuales ya notifican, abren directamente si corresponde y no
generan un segundo push de aproximación en esa misma operación.
pickup/absent ponen mapEnabled=false; reglas además comprueban asistencia vigente.
finish elimina ubicación y revoca acceso por estado de recorrido.

Reglas de live: usuario activo, rutas.ver, misma sede, recorrido activo; admin o
responsable asignado, o estudiante/familiar del hijo activo vinculado con ventana
abierta y aún pendiente. No basta con ocultar el mapa. Un documento antiguo que
aún tenga teacherPosition en el padre no se expone a familias.
El cliente solo suscribe live mientras la ventana está abierta; ante error no usa
un marcador previamente guardado para otro hijo. Los datos ya vistos/capturados
no pueden borrarse del dispositivo de una persona, pero no recibe posiciones nuevas.

## Estimación económica y límites

calcularTiemposRuta usa un cálculo de ruta completo, no uno por espectador. El
cliente lo solicita al iniciar en automático; no existe timer de cinco minutos
ni recálculo al recoger. El responsable puede volver a solicitar con confirmación.
MAPS_ROUTING_ENABLED sigue desactivado hasta verificar API, facturación e identidad
de servidor. La cuota implementada es 100 cálculos/día/proyecto, no presupuesto total.

Se guarda hora estimada, no se consulta tráfico por cada GPS. La ventana se evalúa
con posiciones recibidas y al calcular/avisar. Sin GPS/red puede retrasarse; una
estimación sin recálculo puede perder precisión. No prometer aviso exactamente
10 minutos antes. Una ventana abierta permanece ante demora hasta resolver parada.
El responsable puede avisar manualmente si no hay Maps. Ubicación filtrada a no
más de una publicación cada 30 segundos; parado puede tardar más por filtro GPS.

Avisos generales: comando announcement, solo operador autorizado durante recorrido
activo. Texto máximo 500, evento y route_history atómicos; audiencia incluye niños
activos del recorrido ya recogidos. Se consulta en Rutas. No es otra colección de
chat ni canal de Mensajería. No traslada authored/performedBy a un sustituto.

## Migración y despliegue

1. git status; preservar cambios ajenos. Identificar proyecto QA explícitamente.
2. Ejecutar tests/lint/analyze, compilar antes de publicar.
3. node functions/scripts/migrate_route_security.js: diagnóstico. --apply retira
   campos antiguos de tokens y GPS del padre; no borra asistencia ni recorridos.
4. Publicar Functions operarRecorrido/calcularTiemposRuta y reglas. No eliminar
   índices remotos con --force sin revisar qué se retiraría.
5. Publicar frontend compilado y regenerar APK ARM64 para Z Flip7.
6. Verificar migración seca sin pendientes, versiones remotas y pruebas físicas.

No hay lectura dual de ubicación. Un cliente anterior puede dejar de mostrar mapa;
actualizar web/APK de QA. No revertir reglas a una versión que exponga GPS general.
Ante error de migración parar publicación y conservar evidencia; no reparar borrando
documentos institucionales. Credenciales temporales se limpian sin imprimirlas.

## Comandos de validación

```powershell
dart format lib test
flutter analyze
flutter test
npm --prefix functions run lint
npm --prefix functions run test:routes
npm --prefix functions run test:rules
flutter build apk --release --split-per-abi
flutter build web --release
```

Para cambios en otros módulos ejecutar además suites auth/users/enrollment/
authorization/schedule/files/messaging/qr/push relevantes. Pruebas de emuladores
no confirman GPS físico, notificación visible ni aceptación de Google Play.

## Matriz de aceptación Rutas

- Admin otra sede, docente ajeno, familiar con hijo ajeno: denegación.
- Antes de 10 minutos: GPS denegado incluso por SDK directo.
- Dos paradas a 8/9 minutos: ambas abiertas; misma dirección avisa agrupado.
- GPS repetido: no duplica aviso. ETA manual >10 no abre inmediatamente.
- Trancón después de abrir: no cierra ventana; recálculo solo solicitado.
- Recogido/ausente/finalizada: revoca GPS; historial sigue consultable.
- Otro hijo: no hereda ventana ni marcador del anterior.
- Anuncio después de recogida: sigue en audiencia e historial; no obliga a chat.
- Móvil/web/ambos/ninguno: estados válidos. Logout antiguo no borra token nuevo.
- Pantalla bloqueada, GPS apagado, sin red, app reiniciada: probar Z Flip7.
- Medir lecturas/escrituras/Functions y Maps por recorrido; estimaciones no son factura.

## Pendientes funcionales que no deben ocultarse

Paradas como entidades con coordenadas/Places, planificación futura, ida/regreso,
relevo de auxiliar, cola offline con conflictos e historial antiguo unificado.
La agrupación actual sigue siendo por texto de dirección normalizado, no distancia.
Automático real necesita habilitación y prueba de Google, no basta con compilar.
Eventos completos, entregas/asistencia por QR, lonchera/restaurante operativos no
están finalizados. Inventariar y ocultar entradas incompletas antes de release.

## Google Play

1. Abrir el aviso de inactividad en Play Console y comprobar fecha/tareas exactas;
   no confundirlo con registro de paquetes ya resuelto. Si sigue el plazo de la
   captura (19 de septiembre), no esperar a terminar funciones futuras.
2. Leer causa concreta del rechazo anterior. Verificar applicationId contra la
   ficha existente: el APK actual usa co.edu.liceobilinguerodolfollinas.sistemaeducativo,
   diferente del paquete mostrado en aquella captura. No cambiarlo ni crear otra
   ficha sin decidir estrategia con el propietario.
3. Confirmar firma de carga/Play App Signing, versionCode creciente, target API
   requerido en consola, compatibilidad de bibliotecas nativas/páginas de memoria,
   AAB firmado y reporte previo al lanzamiento. No enviar keystore/contraseñas por chat.
4. Validar login de revisor, rutas, mapa, notificaciones, permisos solo cuando se
   necesitan, consumo en segundo plano y cierre de sesión. No pedir GPS a familias
   para ver la posición del vehículo ni prometer seguimiento infalible.
5. Completar política de privacidad pública, seguridad de datos, audiencia/menores,
   eliminación de cuenta cuando aplique, clasificación, acceso restringido,
   declaraciones de permisos/servicios y ficha/capturas reales con datos de prueba.
6. Subir AAB a prueba interna, atender rechazo/pre-launch y luego prueba cerrada.
   Para cuenta personal de 2025: al menos 12 testers inscritos continuamente los
   14 días previos a solicitar producción, con pruebas reales y sus resultados.
7. La revisión y acceso a producción los decide Google. Un APK instalado fuera de
   Play no cumple por sí solo las tareas de la consola.

Fuentes oficiales consultadas septiembre de 2026:
- [Inactividad](https://support.google.com/googleplay/android-developer/answer/11605267).
- [Pruebas de cuentas personales](https://support.google.com/googleplay/android-developer/answer/14151465).
- [Configurar pruebas](https://support.google.com/googleplay/android-developer/answer/9845334).

Identidad, declaraciones legales, permisos de cuenta y publicación final requieren
participación del titular. No prometer fecha de aprobación ni publicar secretos.
