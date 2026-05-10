# HU-DEV-SALB_08 — Proxy routing hacia Inventory Service

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_08                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Crítica                                    |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-006, ADR-008                  |
| **Rama**           | `HU-DEV-SALB_08`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** cliente Angular,
> **quiero** que las rutas del catálogo e inventario sean atendidas por el
> Inventory Service a través del Gateway,
> **para** poder consultar productos y stock con autenticación gestionada
> de forma transparente.

---

## Criterios de Aceptación

- [ ] Las rutas bajo `/api/v1/catalog/**` e `/api/v1/inventory/**` son redirigidas al Inventory Service (`INVENTORY_SERVICE_URL`).
- [ ] El Auth Guard (HU-DEV-SALB_05) se aplica en todas estas rutas.
- [ ] Los headers de identidad son inyectados en cada petición proxeada: `X-User-Id`, `X-User-Email`, `X-User-Roles`.
- [ ] El header `X-Trace-Id` es propagado en cada petición proxeada.
- [ ] Timeout de conexión: 3 segundos. Timeout de petición: 10 segundos.
- [ ] Si el Inventory Service no responde → `502`/`504` con formato estándar (ADR-009).
- [ ] Los errores del Inventory Service que no estén en formato estándar son normalizados por el Gateway.

---

## Mapa de Rutas Proxeadas

| Ruta pública (Gateway)                        | Destino interno       | Auth   |
|-----------------------------------------------|-----------------------|--------|
| `GET  /api/v1/catalog/categories`             | Inventory Service     | Sí     |
| `GET  /api/v1/catalog/categories/{id}`        | Inventory Service     | Sí     |
| `POST /api/v1/catalog/categories`             | Inventory Service     | ADMIN  |
| `PUT  /api/v1/catalog/categories/{id}`        | Inventory Service     | ADMIN  |
| `DELETE /api/v1/catalog/categories/{id}`      | Inventory Service     | ADMIN  |
| `GET  /api/v1/catalog/products`               | Inventory Service     | Sí     |
| `GET  /api/v1/catalog/products/{id}`          | Inventory Service     | Sí     |
| `POST /api/v1/catalog/products`               | Inventory Service     | ADMIN  |
| `PUT  /api/v1/catalog/products/{id}`          | Inventory Service     | ADMIN  |
| `DELETE /api/v1/catalog/products/{id}`        | Inventory Service     | ADMIN  |
| `GET  /api/v1/catalog/products/{id}/images`   | Inventory Service     | Sí     |
| `GET  /api/v1/inventory/stock`                | Inventory Service     | Sí     |
| `GET  /api/v1/inventory/stock/{productId}`    | Inventory Service     | Sí     |
| `GET  /api/v1/inventory/movements`            | Inventory Service     | ADMIN  |
| `POST /api/v1/inventory/movements`            | Inventory Service     | ADMIN  |

---

## Notas Técnicas

- Las rutas de solo lectura (GET) pueden implementarse con autorización parcial: autenticado pero no necesariamente ADMIN. La granularidad de roles se valida en el Inventory Service leyendo el header `X-User-Roles`.
- El Gateway no valida roles, solo autentica. La autorización granular es responsabilidad del servicio downstream.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_04 | Necesita propagación de `traceId` |
| Bloqueada por | HU-DEV-SALB_05 | Necesita Auth Guard activo |
| Relacionada con | HU-DEV-SALB_10+ | El Inventory Service debe estar funcionando |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que `GET /api/v1/catalog/products` devuelve datos del Inventory Service.
- [ ] Verificado que sin token recibe `401`.
- [ ] Verificado que los headers `X-User-*` llegan al Inventory Service.
- [ ] PR mergeado a `develop`.
