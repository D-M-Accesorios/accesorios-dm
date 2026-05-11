# Accesorios D&M — Sistema E-Commerce

**Accesorios D&M** es un emprendimiento que actualmente comercializa accesorios a través de Instagram y WhatsApp, gestionando los pedidos de forma manual. Este proyecto digitaliza y centraliza la operación mediante un **sistema distribuido de microservicios** que cubre catálogo, inventario, pagos, autenticación y frontend web/mobile.

---

## Integrantes

| Nombre | Rol |
|---|---|
| Sergio Andrés Losada Bahamón | Backend / DevOps |
| Dayana Motta Camayo | Frontend Web |
| Juan Sebastián Agudelo Quintero | Mobile |
| Dany Yulieth Campos Bustos | QA / Documentación |

---

## Arquitectura

```
                        ┌─────────────┐   ┌─────────────┐
                        │  Frontend   │   │   Mobile    │
                        │  (Angular)  │   │Flutter/RN)  │
                        └──────┬──────┘   └──────┬──────┘
                               │                 │
                               └────────┬────────┘
                                        │ HTTPS
                               ┌────────▼────────┐
                               │   API Gateway   │  JWT RS256
                               │   (NestJS)      │  Rate Limiting
                               │   :3000         │  Proxy / CORS
                               └────────┬────────┘
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
           ┌────────▼────────┐ ┌────────▼────────┐ ┌───────▼────────┐
           │ Inventory Svc   │ │  Security Svc   │ │  Payment Svc   │
           │ (Spring Boot)   │ │  (pendiente)    │ │  (pendiente)   │
           │  :8082          │ └─────────────────┘ └────────────────┘
           └────────┬────────┘
                    │
           ┌────────▼────────┐
           │   PostgreSQL    │  Liquibase migrations
           │   (schemas:     │  accesorios-dm-database
           │   catalogo /    │
           │   inventario)   │
           └─────────────────┘
```

---

## Repositorios

| Repositorio | Descripción | Stack |
|---|---|---|
| [`accesorios-dm`](https://github.com/SergioLosadaDev/accesorios-dm) | Documentación central del proyecto | — |
| [`accesorios-dm-api-gateway`](https://github.com/SergioLosadaDev/accesorios-dm-api-gateway) | API Gateway — autenticación, proxy, rate limiting | NestJS · TypeScript |
| [`accesorios-dm-inventory-service`](https://github.com/SergioLosadaDev/accesorios-dm-inventory-service) | Catálogo de productos e inventario | Spring Boot 3 · Java 21 |
| [`accesorios-dm-database`](https://github.com/SergioLosadaDev/accesorios-dm-database) | Migraciones de base de datos | PostgreSQL 16 · Liquibase |
| [`accesorios-dm-frontend`](https://github.com/SergioLosadaDev/accesorios-dm-frontend) | Portal web del e-commerce | Angular |
| [`accesorios-dm-mobile`](https://github.com/SergioLosadaDev/accesorios-dm-mobile) | Aplicación móvil | Flutter / React Native |
| [`accesorios-dm-security-service`](https://github.com/SergioLosadaDev/accesorios-dm-security-service) | Autenticación y gestión de usuarios | En desarrollo |
| [`accesorios-dm-payment-service`](https://github.com/SergioLosadaDev/accesorios-dm-payment-service) | Pasarela de pagos | En desarrollo |
| [`dm-deployment`](https://github.com/SergioLosadaDev/dm-deployment) | Docker Compose + scripts de infraestructura | Docker |

---

## Inicio rápido — Levantar el backend en local

> Guía completa: [`docs/backend/quickstart.md`](docs/backend/quickstart.md)

### Prerrequisitos

| Herramienta | Versión mínima |
|---|---|
| Docker Desktop | 4.x (Engine ≥ 26) |
| Docker Compose | ≥ 2.24 |
| Git | cualquiera |

### Pasos

```bash
# 1. Clonar todos los repos en la misma carpeta padre
mkdir app-accesorios-dm && cd app-accesorios-dm
git clone https://github.com/SergioLosadaDev/accesorios-dm-database
git clone https://github.com/SergioLosadaDev/accesorios-dm-api-gateway
git clone https://github.com/SergioLosadaDev/accesorios-dm-inventory-service
git clone https://github.com/SergioLosadaDev/dm-deployment

# 2. Configurar entorno de desarrollo
cd dm-deployment
cp .env.dev.example .env

# 3. Levantar el stack de backend
docker compose up -d postgres liquibase inventory-service api-gateway

# 4. Verificar que todo está healthy
docker compose ps
```

Salida esperada:

```
NAME                        STATUS
accesorios-dm-postgres      running (healthy)
accesorios-dm-liquibase     exited (0)          ← normal
accesorios-dm-inventory     running (healthy)
accesorios-dm-gateway       running (healthy)
```

> Spring Boot puede tardar ~60 segundos en arrancar la primera vez.

### Verificar

```bash
# Health del gateway (sin autenticación)
curl http://localhost:3000/api/v1/health
# → {"status":"UP","timestamp":"..."}
```

---

## Documentación del backend

| Documento | Descripción |
|---|---|
| [`docs/backend/quickstart.md`](docs/backend/quickstart.md) | Guía completa de setup local |
| [`docs/backend/authentication.md`](docs/backend/authentication.md) | Flujo JWT, roles, interceptor Angular, errores de auth |
| [`docs/backend/api-reference.md`](docs/backend/api-reference.md) | Referencia completa de endpoints con ejemplos curl |
| [`docs/api-contracts/inventory-service-v1.yaml`](docs/api-contracts/inventory-service-v1.yaml) | Contrato OpenAPI 3.1.0 del Inventory Service |

### Endpoints disponibles

| Ruta | Método | Descripción | Rol requerido |
|---|---|---|---|
| `/api/v1/health` | GET | Estado del gateway | Público |
| `/api/v1/health/services` | GET | Estado de servicios dependientes | Público |
| `/api/v1/catalog/categories` | GET | Listar categorías | Autenticado |
| `/api/v1/catalog/categories/:id` | GET | Detalle de categoría | Autenticado |
| `/api/v1/catalog/categories` | POST | Crear categoría | ADMIN |
| `/api/v1/catalog/products` | GET | Listar productos (paginado, filtros) | Autenticado |
| `/api/v1/catalog/products/:id` | GET | Detalle de producto | Autenticado |
| `/api/v1/catalog/products` | POST | Crear producto | ADMIN |
| `/api/v1/catalog/materials` | GET | Listar materiales | Autenticado |
| `/api/v1/inventory/stock` | GET | Stock de todos los productos | Autenticado |
| `/api/v1/inventory/stock/:id` | GET | Stock de un producto | Autenticado |
| `/api/v1/inventory/movements` | GET | Historial de movimientos | ADMIN |
| `/api/v1/inventory/movements` | POST | Registrar movimiento | ADMIN · VENDEDOR |

### Autenticación

El gateway valida JWT RS256 en cada request e inyecta los headers internos:

```
Authorization: Bearer <token>
```

Para desarrollo, genera un token con el script incluido en `dm-deployment`:

```bash
cd dm-deployment
node scripts/generate-dev-token.js admin ADMIN    # token ADMIN
node scripts/generate-dev-token.js vendedor VENDEDOR  # token VENDEDOR
```

Ver [`docs/backend/authentication.md`](docs/backend/authentication.md) para el flujo completo e integración con Angular.

---

## Estrategia de ramas

```
main ──────────────────────────────────────── producción
  └── qa ──────────────────────────────────── staging / pruebas
        └── develop ─────────────────────── integración continua
               └── HU-{número}-{iniciales} ─ feature branch
```

Cada feature branch se crea desde `develop` y se integra mediante Pull Request. Los merges siguen el flujo `develop → qa → main`.

Ver [`docs/git-strategy/GIT-STRATEGY.md`](docs/git-strategy/GIT-STRATEGY.md) para la guía completa.

---

## Convención de commits

Todos los repositorios siguen **Conventional Commits**:

| Tipo | Uso | Ejemplo |
|---|---|---|
| `feat` | Nueva funcionalidad | `feat: agregar endpoint de movimientos` |
| `fix` | Corrección de errores | `fix: corregir validación de stock` |
| `docs` | Documentación | `docs: actualizar api-reference` |
| `chore` | Mantenimiento | `chore: actualizar dependencias` |
| `refactor` | Refactorización | `refactor: extraer MovimientoMapper` |
| `test` | Tests | `test: agregar test de StockService` |

Formato de rama: `HU-{NÚMERO}-{INICIALES}` — ejemplo: `HU-DEV-SALB_09`

---

## Decisiones de arquitectura (ADRs)

| ADR | Decisión |
|---|---|
| [ADR-001](docs/ADRs-v2/ADR-001-shared-database.md) | Base de datos compartida con schemas separados por bounded context |
| [ADR-002](docs/ADRs-v2/ADR-002-api-gateway-nestjs.md) | API Gateway con NestJS |
| [ADR-003](docs/ADRs-v2/ADR-003-jwt-rs256-strategy.md) | Autenticación JWT RS256 |
| [ADR-004](docs/ADRs-v2/ADR-004-polyglot-stack.md) | Stack políglota (NestJS + Spring Boot) |
| [ADR-005](docs/ADRs-v2/ADR-005-bounded-context-schema.md) | Bounded context por schema de PostgreSQL |
| [ADR-006](docs/ADRs-v2/ADR-006-sync-rest-communication.md) | Comunicación síncrona REST entre servicios |
| [ADR-007](docs/ADRs-v2/ADR-007-async-messaging-strategy.md) | Estrategia de mensajería asíncrona |
| [ADR-008](docs/ADRs-v2/ADR-008-api-versioning.md) | Versionado de API con prefijo `/api/v1` |
| [ADR-009](docs/ADRs-v2/ADR-009-error-handling-standard.md) | Estándar de manejo de errores |

---

## Estado del proyecto

| Módulo | Estado |
|---|---|
| API Gateway (NestJS) | Funcional — proxy, JWT, rate limiting |
| Inventory Service (Spring Boot) | Funcional — catálogo, stock, movimientos |
| Base de datos + migraciones | Funcional — Liquibase con datos de prueba |
| Security Service | En desarrollo |
| Payment Service | En desarrollo |
| Frontend Web (Angular) | En desarrollo |
| Mobile | En desarrollo |
