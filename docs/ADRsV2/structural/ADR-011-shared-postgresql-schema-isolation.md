# ADR-011: Base de Datos PostgreSQL Compartida con Aislamiento por Schemas

| Campo | Valor |
|---|---|
| **ID** | ADR-011 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Inventory Service, Security Service, Payment Service, Base de Datos |

---

## Contexto

En una arquitectura de microservicios, la estrategia de persistencia es crítica. El extremo de máximo aislamiento sería una base de datos por servicio. El extremo opuesto sería una base de datos completamente compartida con todas las tablas mezcladas. El proyecto necesita una solución intermedia que sea práctica para el equipo y el presupuesto de infraestructura.

---

## Problema

¿Cómo organizar la persistencia de datos en un sistema de microservicios cuando los servicios necesitan acceder a datos de otros dominios, el equipo es pequeño, y los recursos de infraestructura son limitados?

---

## Decisión

Se adoptó una **única instancia de PostgreSQL 16** con **aislamiento de dominios mediante schemas** de PostgreSQL. Cada dominio de negocio tiene su propio schema:

| Schema | Propietario lógico | Tablas |
|---|---|---|
| `security` | Security Service | `rol`, `empleado` |
| `clientes` | Security Service | `cliente` |
| `catalogo` | Inventory Service | `categoria`, `material`, `producto`, `imagen_producto` |
| `promociones` | Inventory Service | `promocion`, `promocion_producto` |
| `ventas` | Payment Service | `carrito`, `item_carrito`, `pedido`, `detalle_pedido` |
| `logistica` | Payment Service | `estado_pedido`, `historial_estado_pedido` |
| `inventario` | Inventory Service | `tipo_movimiento`, `inventario_movimiento` |

**Evidencia en código:**

```sql
-- accesorios-dm-database/01_ddl/01_schemas/001_create_schemas.sql
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS clientes;
CREATE SCHEMA IF NOT EXISTS catalogo;
-- ... 7 schemas en total
```

```java
// Inventory Service - entidades apuntan a schema específico
@Table(name = "producto", schema = "catalogo")
```

```python
# Security Service - modelos apuntan a schema específico
class Empleado(Base):
    __table_args__ = {"schema": "security"}
```

```prisma
// Payment Service - Prisma con multiSchema
datasource db {
  schemas = ["security", "clientes", "catalogo", "ventas", "logistica", "inventario", "public"]
}
model Carrito { @@schema("ventas") }
```

---

## Justificación Técnica

- **Costo de infraestructura**: Una sola instancia de PostgreSQL vs. 3-4 instancias separadas reduce significativamente los costos de hosting y operación.
- **Joins cross-schema**: PostgreSQL permite joins entre tablas de diferentes schemas en una misma consulta, habilitando vistas de reporte complejas sin replicación de datos.
- **Simplicidad operacional**: Un solo backup, un solo proceso de migración con Liquibase, una sola configuración de alta disponibilidad.
- **RLS nativa**: PostgreSQL Row Level Security se aplica por schema, proporcionando aislamiento de seguridad sin múltiples instancias.
- **Schemas como namespace**: Los schemas actúan como límites lógicos de dominio sin el overhead de múltiples instancias.

---

## Consecuencias

### Ventajas
- Joins eficientes entre dominios (ej: `ventas.pedido JOIN clientes.cliente`).
- Gestión centralizada de migraciones con Liquibase.
- Costo de infraestructura mínimo.
- Posibilidad de vistas de reporte cross-domain.
- Un solo punto de backup y recovery.

### Desventajas
- **Acoplamiento de datos**: Un schema change en `catalogo.producto` puede afectar tanto al Inventory Service como al Payment Service (que también lee de ese schema via Prisma).
- **Sin aislamiento de carga**: Una query pesada del Payment Service puede impactar el rendimiento del Inventory Service.
- **Conexión única es SPOF**: Si PostgreSQL cae, todos los servicios fallan simultáneamente.
- **Migración a BD separadas es costosa**: Si se decide separar en el futuro, se requiere data migration compleja.
- **Payment Service viola encapsulación de dominio**: Prisma del Payment Service declara modelos de `security.empleado`, `clientes.cliente`, `catalogo.producto` que pertenecen a otros servicios.

### Trade-offs
Pragmatismo operacional vs. pureza de arquitectura de microservicios. Para el contexto del proyecto (startup, equipo pequeño, presupuesto limitado), la BD compartida con schemas es el balance correcto.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| BD por microservicio (Database per Service) | 3-4 instancias PostgreSQL = 4x costo de infraestructura |
| BD compartida sin schemas (tablas mezcladas) | Sin límites de dominio, difícil de mantener |
| CQRS con BD de lectura separada | Complejidad excesiva para el volumen actual |
| NoSQL por dominio | El modelo de datos es inherentemente relacional |

---

## Impacto Arquitectónico

**Alto**. Todas las decisiones de ORM, migración, seguridad de datos y performance de queries dependen de esta decisión.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| SPOF de PostgreSQL | Media | Crítico | Configurar PostgreSQL con réplica de lectura |
| Contención de recursos entre servicios | Media | Alto | Configurar pool de conexiones por servicio (Hikari: max 10) |
| Payment Service viola encapsulación | Certero | Medio | Documentar como deuda técnica, planificar separación |

---

## Relación con Otros Componentes

- **ADR-012**: Liquibase gestiona las migraciones de todos los schemas.
- **ADR-015**: RLS implementado por schema.
- **ADR-023**: 35 índices distribuidos en todos los schemas.
- **ADR-017/019/020**: Cada ORM apunta a sus schemas correspondientes.

---

## Consideraciones Futuras

- Implementar réplica de lectura de PostgreSQL para queries de reporting.
- Revisar el Prisma schema del Payment Service para remover modelos de dominios ajenos.
- Evaluar separación gradual comenzando por el schema `security` hacia una BD independiente.
- Implementar connection pooling con PgBouncer para gestionar eficientemente las conexiones de múltiples servicios.

---

## Por qué es Structural

Es **Structural** porque define la estructura física y lógica de la persistencia del sistema: cuántas instancias de BD existen, cómo se organizan los datos, y cómo cada microservicio accede a su dominio de datos.
