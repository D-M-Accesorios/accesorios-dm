# Architecture Decision Records — Accesorios DM

> Documentación ADR (MADR) del sistema de e-commerce Accesorios DM.  
> Generado el: 2026-05-18 | Versión del sistema analizado: v1.0.x

---

## 1. Diagnóstico Arquitectónico Inicial

### 1.1 Estado General del Proyecto

El sistema Accesorios DM es una plataforma de e-commerce en fase **MVP activo**, en proceso de transición de un modelo de ventas 100% manual (Instagram/WhatsApp) hacia un sistema distribuido digitalizado. La base arquitectónica es sólida en su estructura, pero con brechas de seguridad y consistencia de datos que requieren atención antes de un deploy de producción real.

**Stack general:**

| Capa          | Tecnología                | Madurez                           |
| ------------- | ------------------------- | --------------------------------- |
| API Gateway   | Node.js / Express         | Producción-ready                  |
| Inventory     | Java 17 / Spring Boot 3.5 | Producción-ready                  |
| Security      | Python 3.11 / FastAPI     | Beta (bugs críticos de seguridad) |
| Payment       | Node.js / Prisma 5.22     | Beta (sin transacciones)          |
| Base de Datos | PostgreSQL 16 / Liquibase | Producción-ready                  |
| Frontend      | Angular                   | En desarrollo inicial             |

### 1.2 Fortalezas

1. **Arquitectura de microservicios bien definida**: Separación de responsabilidades clara entre servicios.
2. **API Gateway centralizado**: Políticas transversales en un único punto.
3. **Gestión de BD con Liquibase**: Migraciones versionadas, reproducibles y con rollback.
4. **Modelo de datos rico y normalizado**: 17 tablas, 8 schemas, FK bien definidas.
5. **35 índices de rendimiento**: Anticipación de patrones de acceso frecuentes.
6. **10 vistas analíticas**: Capa de reporting sin código de aplicación.
7. **Estrategia multiambiente coherente**: Develop/QA/Main con puertos diferenciados.
8. **Dockerización completa**: Todos los servicios containerizados con red compartida.
9. **Triggers de BD para auditoría de inventario**: Consistencia garantizada por la BD.
10. **Health checks en todos los servicios**: Base para observabilidad y orquestación.

### 1.3 Riesgos Críticos

| Riesgo                                                      | Severidad   | ADR Relacionado |
| ----------------------------------------------------------- | ----------- | --------------- |
| SHA-256 con salt estático para contraseñas                  | **CRÍTICO** | ADR-022         |
| `SECRET_KEY` JWT con valor hardcodeado como fallback        | **CRÍTICO** | ADR-002         |
| Doble descuento de stock por triggers + código de app       | **CRÍTICO** | ADR-006         |
| Creación de pedidos sin transacción ACID                    | **ALTO**    | ADR-019         |
| RLS de PostgreSQL definido pero no activo                   | **ALTO**    | ADR-015         |
| `authRateLimit` definido pero no aplicado en rutas          | **ALTO**    | ADR-003         |
| Debug prints en código de producción (tokens JWT expuestos) | **MEDIO**   | ADR-002/020     |
| `allow_origins=["*"]` en Security Service CORS              | **MEDIO**   | ADR-002         |
| Número de WhatsApp hardcodeado en código                    | **BAJO**    | ADR-007         |

### 1.4 Deuda Técnica Identificada

1. **Sin transacciones ACID en Payment Service**: `crearPedidoDesdeCarrito` tiene 10 operaciones de BD sin transacción.
2. **Doble actualización de stock**: `UPDATE producto` directo + INSERT en `inventario_movimiento` (que dispara trigger de UPDATE).
3. **`require_role` en FastAPI abre segunda sesión de BD**: Una conexión extra por cada request autenticado.
4. **`show-sql: true` en producción**: Expone SQL en logs; debe ser solo en perfil dev.
5. **MapStruct no implementado**: Mapeo manual Entity→DTO en Inventory Service propenso a errores y difícil de mantener.
6. **Sin contratos OpenAPI versionados**: No hay documentación formal de contratos entre servicios.
7. **Payment Service accede a schemas de otros dominios**: Viola la encapsulación de microservicios.
8. **Sin correlation ID**: Imposible trazar requests entre múltiples servicios.

### 1.5 Patrones Detectados

- **API Gateway Pattern** ✅
- **Layered Architecture** (Inventory Service) ✅
- **Database-per-Schema** (variante de Database-per-Service) ✅
- **Health Check Pattern** ✅
- **Row Level Security** (definido, no activo) ⚠️
- **Audit Log via Triggers** ✅
- **Soft Delete** (campo `estado`) ✅
- **DTO Pattern** ✅
- **Dependency Injection** (FastAPI Depends) ✅
- **Circuit Breaker** ❌ No implementado
- **Saga Pattern** ❌ No implementado
- **CQRS** ❌ No implementado

---

## 2. Inventario de los 25 ADRs

### Behavioral ADRs (Comportamiento en Tiempo de Ejecución)

| ID                                                                            | Título                                        | Prioridad   | Impacto |
| ----------------------------------------------------------------------------- | --------------------------------------------- | ----------- | ------- |
| [ADR-001](behavioral/ADR-001-api-gateway-single-entry-point.md)               | API Gateway como único punto de entrada       | Alta        | Alto    |
| [ADR-002](behavioral/ADR-002-jwt-hs256-authentication.md)                     | Autenticación JWT HS256 con Security Service  | **Crítica** | Crítico |
| [ADR-003](behavioral/ADR-003-environment-aware-rate-limiting.md)              | Rate Limiting diferenciado por ambiente       | Media       | Medio   |
| [ADR-004](behavioral/ADR-004-multienv-port-strategy.md)                       | Estrategia de puertos por ambiente            | Media       | Medio   |
| [ADR-005](behavioral/ADR-005-synchronous-http-inter-service-communication.md) | Comunicación sincrónica HTTP entre servicios  | Alta        | Alto    |
| [ADR-006](behavioral/ADR-006-stock-update-via-database-triggers.md)           | Actualización de stock via triggers de BD     | **Crítica** | Crítico |
| [ADR-007](behavioral/ADR-007-whatsapp-payment-confirmation.md)                | WhatsApp como canal de confirmación de pago   | Baja        | Bajo    |
| [ADR-008](behavioral/ADR-008-health-check-endpoints.md)                       | Health check endpoints en todos los servicios | Media       | Medio   |
| [ADR-009](behavioral/ADR-009-centralized-structured-logging.md)               | Logging estructurado centralizado en Gateway  | Media       | Medio   |

### Structural ADRs (Estructura y Organización del Sistema)

| ID                                                                   | Título                                         | Prioridad   | Impacto |
| -------------------------------------------------------------------- | ---------------------------------------------- | ----------- | ------- |
| [ADR-010](structural/ADR-010-polyglot-microservices-architecture.md) | Arquitectura de microservicios políglota       | Alta        | Alto    |
| [ADR-011](structural/ADR-011-shared-postgresql-schema-isolation.md)  | BD PostgreSQL compartida con schemas           | Alta        | Alto    |
| [ADR-012](structural/ADR-012-liquibase-database-migrations.md)       | Liquibase para migraciones de BD               | Alta        | Alto    |
| [ADR-013](structural/ADR-013-polyrepo-strategy.md)                   | Estrategia Polyrepo por servicio               | Media       | Medio   |
| [ADR-014](structural/ADR-014-docker-shared-network-deployment.md)    | Docker con red compartida externa              | Alta        | Alto    |
| [ADR-015](structural/ADR-015-postgresql-row-level-security.md)       | Row Level Security de PostgreSQL               | **Crítica** | Crítico |
| [ADR-016](structural/ADR-016-local-filesystem-image-storage.md)      | Almacenamiento de imágenes en filesystem local | Baja        | Medio   |

### Design ADRs (Diseño Interno de Componentes)

| ID                                                                   | Título                                        | Prioridad   | Impacto |
| -------------------------------------------------------------------- | --------------------------------------------- | ----------- | ------- |
| [ADR-017](design/ADR-017-layered-architecture-inventory-service.md)  | Arquitectura en capas en Inventory Service    | Alta        | Alto    |
| [ADR-018](design/ADR-018-dto-pattern-api-contract-decoupling.md)     | Patrón DTO para desacoplamiento               | Media       | Medio   |
| [ADR-019](design/ADR-019-prisma-orm-multischema-payment.md)          | Prisma ORM multi-schema en Payment Service    | **Alta**    | Crítico |
| [ADR-020](design/ADR-020-fastapi-sqlalchemy-dependency-injection.md) | FastAPI + SQLAlchemy + DI en Security Service | Alta        | Alto    |
| [ADR-021](design/ADR-021-jpa-hibernate-ddl-validate.md)              | JPA/Hibernate con ddl-auto=validate           | Media       | Alto    |
| [ADR-022](design/ADR-022-sha256-password-hashing.md)                 | SHA-256 con salt estático para contraseñas    | **Crítica** | Crítico |
| [ADR-023](design/ADR-023-35-performance-indexes-strategy.md)         | Estrategia de 35 índices de rendimiento       | Media       | Alto    |
| [ADR-024](design/ADR-024-analytical-views-reporting-layer.md)        | 10 vistas SQL para reportes analíticos        | Media       | Medio   |
| [ADR-025](design/ADR-025-cross-domain-8-schemas-data-model.md)       | Modelo de datos en 8 schemas de dominio       | Alta        | Alto    |

---

## 3. Distribución por Categoría

```
Behavioral:  9 ADRs  (36%)  — Comportamiento en runtime
Structural:  7 ADRs  (28%)  — Estructura y organización
Design:      9 ADRs  (36%)  — Diseño interno de componentes
```

---

## 4. Conclusión Arquitectónica Final

### 4.1 Evaluación General

El sistema Accesorios DM representa una implementación técnicamente ambiciosa y bien estructurada para un MVP académico/emprendimiento. La decisión de adoptar microservicios políglotas, Docker, Liquibase, schemas separados, RLS, triggers e índices refleja un nivel de madurez arquitectónica superior al esperado para un proyecto de este tamaño.

**Nivel de madurez arquitectónica: 6.5/10**

La nota baja no refleja la calidad del diseño estructural (que es sólido, ~8/10), sino las brechas críticas de seguridad e integridad de datos que existen en la implementación actual.

### 4.2 Nivel de Madurez por Dimensión

| Dimensión            | Calificación | Comentario                                             |
| -------------------- | ------------ | ------------------------------------------------------ |
| Arquitectura general | 8/10         | Decisiones sólidas y bien justificadas                 |
| Seguridad            | 4/10         | SHA-256 inseguro, RLS inactivo, secrets hardcodeados   |
| Integridad de datos  | 5/10         | Doble descuento de stock, sin transacciones en Payment |
| Observabilidad       | 5/10         | Logging básico, sin correlation ID, sin métricas       |
| Testing              | 3/10         | Sin tests unitarios ni de integración activos          |
| Operabilidad         | 7/10         | Docker bien configurado, healthchecks, multiambiente   |
| Escalabilidad        | 6/10         | Bien para una instancia; limitado para horizontalizar  |
| Documentación        | 8/10         | READMEs completos, CLAUDE.md, ADRs                     |

### 4.3 Riesgos Técnicos Críticos (Prioridad de Corrección)

**Antes de producción real — BLOQUEANTES:**

1. **[ADR-022]** Migrar de SHA-256 a bcrypt para contraseñas.
2. **[ADR-006]** Eliminar el `UPDATE producto.stock` directo del Payment Service (el trigger ya lo hace).
3. **[ADR-002]** Forzar `SECRET_KEY` desde `.env`; no permitir el valor por defecto en producción.
4. **[ADR-019]** Envolver `crearPedidoDesdeCarrito` en `prisma.$transaction`.

**Antes de escalar — IMPORTANTES:**

5. **[ADR-015]** Activar RLS con `SET ROLE` por usuario en cada servicio.
6. **[ADR-003]** Aplicar `authRateLimit` en la ruta de login.
7. **[ADR-002/020]** Eliminar todos los `print(DEBUG)` con tokens JWT.
8. **[ADR-009]** Implementar correlation ID (X-Request-ID).

**Mejoras de calidad:**

9. **[ADR-020]** Corregir doble sesión de BD en `require_role`.
10. **[ADR-018]** Introducir MapStruct para mapeo Entity→DTO.
11. **[ADR-016]** Migrar imágenes a Cloudinary o S3 cuando escale.

### 4.4 Oportunidades de Mejora

- **Testing**: El sistema carece de tests unitarios y de integración activos. Implementar `@SpringBootTest` slices para el Inventory Service y `pytest` para el Security Service.
- **Circuit Breaker**: Sin protección ante cascading failures. Implementar con Resilience4j (Java) o `tenacity` (Python).
- **Mensajería asíncrona**: El flujo de checkout es candidato a Saga Pattern con un message broker (RabbitMQ) cuando el volumen de pedidos crezca.
- **OpenAPI Contracts**: Definir y versionar contratos OpenAPI para cada servicio, generando clientes tipados para el frontend.
- **Observabilidad avanzada**: Correlation IDs, OpenTelemetry, Grafana Loki para trazabilidad distribuida.

### 4.5 Recomendaciones Futuras

1. **Corto plazo (Sprint siguiente)**: Correcciones de seguridad críticas (bcrypt, transacciones, stock).
2. **Mediano plazo (2-3 meses)**: Testing, circuit breakers, correlation ID, OpenAPI contracts.
3. **Largo plazo (6+ meses)**: Mensajería asíncrona para pedidos, separación del schema `security` a BD independiente, CDN para imágenes.

---

_Todos los ADRs están basados exclusivamente en evidencia encontrada en el código fuente, configuraciones, dependencias y documentación de los repositorios de DmApp._
