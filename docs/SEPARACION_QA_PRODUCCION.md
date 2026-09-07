# Separación QA / producción — 7 de septiembre de 2026

## Decisión del propietario

Conservar sistema-educativo-rl como QA, sin borrar usuarios ni operaciones.
Crear producción limpia e independiente: sistema-educativo-rl-prod.
Dominio público final: https://liceobilinguerodolfollinas.edu.co (Hostinger).
No cambiar DNS ni reemplazar el sitio público hasta validar el entorno nuevo.

## Estado comprobado

- Proyecto de producción creado, número 325430927285.
- Android registrado: com.desarrolloytecnologiasantander.serodolfollinas.
  App ID: 1:325430927285:android:2eecce415faf28dee103fc.
- Web registrada: 1:325430927285:web:4825f7f65a75fd6ee103fc.
- Registradas y verificadas ambas huellas SHA-256: carga y firma de Google Play.
- Alias qa/prod añadidos; default continúa en QA para preservar el flujo existente.
- firebase.production.json separado, ubicación prevista us-central1,
  salida web build/web-prod para no desplegar accidentalmente build/web de QA.
- Facturación NO habilitada. Base Firestore NO creada: API aún deshabilitada.
- No se han importado cuentas, contraseñas, configuración, archivos ni historial.
- No se han desplegado Functions, Hosting o reglas en producción.
- Flutter, Android y worker web actuales aún apuntan a QA. La separación de runtime
  NO está completada. No generar/publicar un AAB de producción con esa configuración.

## Usuarios aprobados

18 perfiles: 14 docentes incluyendo Karen, Nancy y Kamila administradoras,
Jairo superadmin y Sara Lucía estudiante. Otros 11 permanecen solo en QA.
La selección explícita por UID está en functions/scripts/production_readiness.js;
no usar una heurística por nombre en el momento de importar.

Preflight de solo lectura:

```powershell
node functions/scripts/production_readiness.js
```

Karen ya está como Docente de Séptimo A. Los grupos referenciados existen en QA;
esta comprobación no valida todavía su año, sedes y todas las relaciones cruzadas.
Nancy figura Administrador sin groupId; no simular doble rol mediante otra cuenta.
La capacidad docente de Nancy requiere diseño/revisión específica antes de asignar
horarios como docente. Jairo contiene una referencia vacía en studentIds; limpiar
en la proyección de producción sin modificar QA ni inventar vínculos.

## Importación pendiente: lista positiva

Copiar únicamente perfiles aprobados, Auth correspondiente y dependencias
institucionales revisadas: institución, sedes, grupos/año activo y parámetros
necesarios. Revisar sitio/tema e imágenes institucionales antes de copiarlos a
Storage de producción; nunca conservar URL de Storage QA como solución permanente.

Excluir explícitamente archivos académicos, matrículas de ensayo, autorizaciones,
horarios, rutas/recorridos, mensajes, formularios enviados, push/jobs/tokens/sesiones,
historiales de prueba, reservas de cuota y datos temporales. QR se emite en el nuevo
entorno; no importar secretos de credenciales QR ni sesiones del anterior.

No exportar hashes de contraseña a Git ni imprimir credenciales. Elegir un mecanismo
seguro de migración Auth (UID conservado con importación compatible o activación
controlada); no crear contraseñas conocidas ni afirmar que las antiguas funcionan
sin probar. Auditar la importación y bloquear ante referencias fuera de la lista.
Una importación fallida se reanuda de forma idempotente, no borrando producción.

## Puertas de avance

1. Titular activa Blaze y elige cuenta de facturación del nuevo proyecto.
2. Activar API Firestore, crear DB estándar us-central1 con protección de eliminación,
   bucket propio y Auth con dominios autorizados y proveedores necesarios.
3. Configurar certificados Android de carga y distribución; comprobar SHA-1 para
   restricciones Maps y SHA-256 para servicios aplicables. No usar clave Maps de QA.
4. Separar runtime Flutter/Android/web y worker; también Functions AUTH_WEB_API_KEY,
   EMAIL_VERIFICATION_CONTINUE_URL y PUBLIC_APP_URL. No hay fallback de prod a QA.
5. Configurar secretos/VAPID/Maps por entorno; Maps requiere presupuesto independiente.
6. Validar proyección de datos, importar sin operaciones de prueba, verificar Auth
   y Firestore juntos. No activar cuentas huérfanas.
7. Ejecutar formato/analyze/Flutter/lint/emuladores y prueba física firmada.
8. Generar AAB con paquete registrado y clave de carga verificada. Elegir explícitamente
   QA para pruebas de Play o producción para aceptación, nunca mezclar configuraciones.
9. Desplegar web de producción en Hostinger cuando el conjunto esté validado.

Crear el proyecto no es publicarlo: pendiente del aviso de Play antes del 19,
la prueba interna y posteriormente 12 testers durante 14 días de prueba cerrada.
