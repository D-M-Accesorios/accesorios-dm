# Accesorios D&M — Sistema E-Commerce

**Accesorios D&M** es un emprendimiento que actualmente comercializa accesorios a través de Instagram y WhatsApp, gestionando los pedidos de forma manual. Este proyecto digitaliza y centraliza la operación mediante un **sistema distribuido de microservicios** que cubre catálogo, inventario, pagos, autenticación y frontend web/mobile.

---

## Integrantes

| Nombre                          | Rol       |
| ------------------------------- | --------- |
| Sergio Andrés Losada Bahamón    | DevOps    |
| Dayana Motta Camayo             | Frontend. |
| Juan Sebastián Agudelo Quintero | Backend   |
| Dany Yulieth Campos Bustos      | QA        |

---

## Arquitectura

```
                        ┌─────────────┐   ┌─────────────┐
                        │  Frontend   │   │   Mobile    │
                        │  (Angular)  │   │Flutter/RN   │
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

| Repositorio                                                                                             | Descripción                                       |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| [`accesorios-dm`](https://github.com/SergioLosadaDev/accesorios-dm)                                     | Documentación central del proyecto                |
| [`accesorios-dm-api-gateway`](https://github.com/SergioLosadaDev/accesorios-dm-api-gateway)             | API Gateway — autenticación, proxy, rate limiting |
| [`accesorios-dm-inventory-service`](https://github.com/SergioLosadaDev/accesorios-dm-inventory-service) | Catálogo de productos e inventario                |
| [`accesorios-dm-database`](https://github.com/SergioLosadaDev/accesorios-dm-database)                   | Migraciones de base de datos                      |
| [`accesorios-dm-frontend`](https://github.com/SergioLosadaDev/accesorios-dm-frontend)                   | Portal web del e-commerce                         |
| [`accesorios-dm-mobile`](https://github.com/SergioLosadaDev/accesorios-dm-mobile)                       | Aplicación móvil                                  |
| [`accesorios-dm-security-service`](https://github.com/SergioLosadaDev/accesorios-dm-security-service)   | Autenticación y gestión de usuarios               |
| [`accesorios-dm-payment-service`](https://github.com/SergioLosadaDev/accesorios-dm-payment-service)     | Pasarela de pagos                                 |
| [`dm-deployment`](https://github.com/SergioLosadaDev/dm-deployment)                                     | Docker Compose + scripts de infraestructura       |

---

## Estrategia de ramas

```
main ────────────────────────────────────────────────────── producción
  └── qa ────────────────────────────────────────────────── staging / pruebas
        └── develop ─────────────────────────────────────── integración continua
               └── HU-{número}-{iniciales}-{Descripcion} ── feature branch
```

Cada feature branch se crea desde `develop` y se integra mediante Pull Request. Los merges siguen el flujo `develop → qa → main`.

---

## Convención de commits

Todos los repositorios siguen **Conventional Commits**:

| Tipo       | Uso                   | Ejemplo                                 |
| ---------- | --------------------- | --------------------------------------- |
| `feat`     | Nueva funcionalidad   | `feat: agregar endpoint de movimientos` |
| `fix`      | Corrección de errores | `fix: corregir validación de stock`     |
| `docs`     | Documentación         | `docs: actualizar api-reference`        |
| `chore`    | Mantenimiento         | `chore: actualizar dependencias`        |
| `refactor` | Refactorización       | `refactor: extraer MovimientoMapper`    |
| `test`     | Tests                 | `test: agregar test de StockService`    |

Formato de rama: `HU-{NÚMERO}-{INICIALES}` — ejemplo: `HU-DEV-SALB_09`

---
