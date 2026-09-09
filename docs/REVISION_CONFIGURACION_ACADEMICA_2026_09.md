# Revisión de Configuración académica — septiembre de 2026

## Decisión vigente

La antigua pantalla de Parámetros mezclaba catálogos internos con grupos y años
lectivos. Además consultaba `parameters` con un orden compuesto que exigía un
índice no desplegado y mostraba al usuario el error técnico de Firestore.

La pantalla se reemplaza por **Configuración académica** y administra solamente:

- grupos académicos de la sede y del año activo;
- preparación, consulta y activación de años lectivos.

Los catálogos internos de roles, permisos, tipos de documento y EPS continúan
disponibles para las lecturas funcionales que los necesitan, pero ningún cliente
puede crearlos, modificarlos o eliminarlos. No existe CRUD administrativo para
ellos.

## Seguridad y alcance

- `parametros.ver`: consulta de configuración académica.
- `parametros.editar`: creación y modificación mediante Cloud Functions; también
  implica consulta.
- El administrador normal opera únicamente en su institución y sede, aunque
  manipule la solicitud.
- Solo el superadministrador selecciona otra institución o sede.
- `parametros.editar` no puede ser delegado por un administrador normal.
- Las reglas deniegan toda escritura directa en `parameters`.

## Ciclo de vida de grupos

La operación habitual para retirar un grupo es desactivarlo. La eliminación
definitiva está reservada al superadministrador y exige:

1. grupo perteneciente a un año activo y ya desactivado;
2. análisis previo de estudiantes, docente director, horarios/asignaturas,
   matrículas, autorizaciones, archivos y canales de servicio;
3. ausencia de mensajes en el canal académico;
4. confirmación visible;
5. eliminación atómica del grupo y de su canal académico vacío;
6. registro inmutable en `academic_group_history`.

Ante cualquier relación o fallo, no se elimina nada. Un canal con mensajes se
conserva archivado junto con el grupo inactivo.

## Despliegue

Estado del 9 de septiembre de 2026: migración aplicada y verificada en
producción para 5 administradores activos; reglas publicadas y 9 Functions
afectadas desplegadas sin errores. El cliente web quedó publicado en Hostinger
desde el commit `ba0554c`; el cliente móvil se incluirá en el siguiente AAB.

La entrega requiere, en este orden:

1. ejecutar la migración de permisos en seco;
2. aplicar y verificar la migración;
3. desplegar Functions y reglas;
4. compilar y publicar el cliente web/móvil;
5. verificar con administrador de sede, administrador solo lectura y
   superadministrador.

Comandos de migración:

```text
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto>
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto> --apply
node functions/scripts/migrate_parameter_permissions.js --project=<proyecto> --verify
```

## Criterios de aceptación

- La pantalla carga sin requerir el índice compuesto antiguo.
- Nunca presenta URL, traza, nombre de paquete ni código interno de Firebase.
- Un administrador sin permiso no ve ni abre la ruta.
- Un administrador con `parametros.ver` consulta pero no modifica.
- Un administrador con `parametros.editar` modifica solo su sede.
- Un grupo inactivo sigue visible y conserva su historia.
- La eliminación definitiva se bloquea frente a cualquier impacto.
