# ADR-012: Liquibase como Sistema de Migraciones de Base de Datos con Rollback

| Campo | Valor |
|---|---|
| **ID** | ADR-012 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Base de Datos, todos los servicios |

---

## Contexto

El esquema de base de datos del sistema incluye 8 schemas, 17 tablas, funciones, triggers, índices, vistas y políticas RLS. Este esquema evoluciona continuamente a medida que se agregan funcionalidades. Sin control de versiones de la BD, es imposible reproducir el estado exacto de la BD en diferentes ambientes, hacer rollbacks de cambios problemáticos, o garantizar que todos los miembros del equipo tengan el mismo estado de BD.

---

## Problema

¿Cómo gestionar la evolución del esquema de base de datos de forma versionada, reproducible y con capacidad de rollback, en múltiples ambientes (develop, qa, main)?

---

## Decisión

Se adoptó **Liquibase** como sistema de migraciones con una estructura jerárquica de changelogs organizados por tipo de operación SQL (DDL, DML, DCL, TCL) y con scripts de rollback explícitos para cada migración.

**Estructura del proyecto:**

```
accesorios-dm-database/
├── changelog-master.yaml          # Entry point que incluye todos los changelogs
├── 01_ddl/                        # DDL: extensiones, schemas, tablas, vistas, triggers, índices
│   ├── changelog.yaml
│   ├── 00_extensions/
│   ├── 01_schemas/
│   ├── 03_tables/
│   ├── 04_views/
│   ├── 06_functions/
│   ├── 08_triggers/
│   └── 09_indexes/
├── 02_dml/                        # DML: datos iniciales
├── 03_dcl/                        # DCL: roles, grants, políticas RLS
├── 04_tcl/                        # TCL: bloques transaccionales
└── 05_rollbacks/                  # Mirror de estructura para rollbacks
```

**Evidencia en configuración:**

```yaml
# accesorios-dm-database/docker-compose.prod.yml
liquibase:
  image: liquibase/liquibase:4.25-alpine
  depends_on:
    postgres:
      condition: service_healthy
  command: >
    liquibase update
    --url=jdbc:postgresql://postgres:5432/accesorios_dm_db
    --changelog-file=changelog-master.yaml
```

Cada archivo de migración tiene su rollback explícito en `05_rollbacks/`:

```
01_ddl/03_tables/001_create_security_tables.sql
05_rollbacks/01_ddl/03_tables/001_create_security_tables.rollback.sql
```

---

## Justificación Técnica

- **Reproducibilidad**: `docker-compose up` en cualquier ambiente ejecuta todas las migraciones desde cero, garantizando el mismo estado en todos.
- **Historial versionado**: Liquibase mantiene la tabla `DATABASECHANGELOG` que registra qué migraciones se han ejecutado y cuándo.
- **Idempotencia**: Liquibase no re-ejecuta migraciones ya aplicadas. El estado de la BD converge al estado esperado.
- **Separación por tipo SQL**: La estructura `01_ddl`, `02_dml`, `03_dcl` refleja las responsabilidades SQL y facilita la navegación del código.
- **Rollback explícito**: Scripts de rollback en `05_rollbacks/` documentan cómo revertir cada cambio.

---

## Consecuencias

### Ventajas
- Desarrollo reproducible: cualquier miembro del equipo puede levantar la BD desde cero.
- Historial completo de cambios de esquema en control de versiones (git).
- Rollbacks documentados y ejecutables.
- Compatible con CI/CD: la migración se ejecuta automáticamente al iniciar el contenedor.
- La dependencia `service_healthy` garantiza que Liquibase solo corre cuando PostgreSQL está listo.

### Desventajas
- **Estructura de carpetas compleja**: La jerarquía de directorios es extensa y puede ser confusa para miembros nuevos.
- **Incremento de tiempo de arranque**: Liquibase verifica y aplica migraciones en cada arranque, añadiendo latencia al startup.
- **Rollbacks manuales**: Los rollbacks requieren ejecutar `liquibase rollback` explícitamente; no son automáticos en caso de error.
- **`04_tcl` y `05_materialized_views` vacíos**: Directorios creados como estructura anticipada pero sin contenido, lo que sugiere organización prematura.
- **Sin uso en los microservicios propios**: Spring Boot tiene `ddl-auto: validate` (no manage), lo que requiere que Liquibase corra antes que el Inventory Service.

### Trade-offs
Control completo del esquema vs. complejidad de la estructura de archivos. La estructura es más compleja que Flyway (alternativa), pero proporciona más granularidad y capacidad de rollback.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Flyway | Más simple, pero sin soporte nativo de rollback explícito |
| Spring Boot `ddl-auto: update` | Sin versionado, peligroso en producción |
| Migraciones manuales | Sin reproducibilidad, propenso a errores humanos |
| Alembic (Python) | Solo gestiona el schema de un ORM específico, no del sistema completo |

---

## Impacto Arquitectónico

**Alto**. Determina cómo evoluciona el esquema de BD y cómo se garantiza la consistencia entre ambientes.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Liquibase falla y bloquea el startup | Baja | Alto | Healthcheck en contenedor; logs de Liquibase monitoreados |
| Conflicto de changelogs en merges | Media | Alto | Convención de numeración estricta de archivos |
| Rollback incompleto deja BD en estado inconsistente | Baja | Crítico | Probar rollbacks en ambiente de desarrollo |

---

## Relación con Otros Componentes

- **ADR-011**: Liquibase gestiona todos los schemas de la BD compartida.
- **ADR-021**: Spring Boot usa `ddl-auto: validate`, dependiendo de Liquibase para la creación del esquema.
- **ADR-004**: Cada ambiente (rama) tiene su configuración de BD con el mismo changelog.

---

## Consideraciones Futuras

- Limpiar los directorios vacíos (`04_tcl`, `05_materialized_views`) o documentar su propósito futuro.
- Implementar pruebas de rollback en CI/CD.
- Considerar Liquibase Hub para monitoreo central de migraciones.

---

## Por qué es Structural

Es **Structural** porque define la estructura de versionado y evolución de la capa de persistencia del sistema, determinando cómo se organiza, versiona y despliega el esquema de base de datos.
