# HU-DEV-SALB_12 — CRUD de Categorías

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_12                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Alta                                           |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008, ADR-009                      |
| **Rama**           | `HU-DEV-SALB_12`                               |
| **Schema BD**      | `catalogo`                                     |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** administrador,
> **quiero** gestionar las categorías del catálogo de productos,
> **para** organizar la oferta de la tienda de forma jerárquica y facilitar
> la navegación al cliente.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/catalog/categories` devuelve la lista paginada de categorías activas.
- [ ] `GET /api/v1/catalog/categories/{id}` devuelve el detalle de una categoría por ID.
- [ ] `POST /api/v1/catalog/categories` crea una nueva categoría (rol ADMIN).
- [ ] `PUT /api/v1/catalog/categories/{id}` actualiza una categoría existente (rol ADMIN).
- [ ] `DELETE /api/v1/catalog/categories/{id}` elimina una categoría (rol ADMIN).
- [ ] El listado soporta `page` (default 0) y `size` (default 20) como query params.
- [ ] Si la categoría no existe en GET, PUT o DELETE → `404 CATEGORY_NOT_FOUND`.
- [ ] Si se intenta eliminar una categoría con productos asociados → `409 CONFLICT` con mensaje descriptivo.
- [ ] La creación valida campos requeridos; campos inválidos → `422 VALIDATION_ERROR` con `details`.
- [ ] El rol del usuario se lee del header `X-User-Roles` inyectado por el Gateway.

---

## Campos de la Entidad Categoría

| Campo        | Tipo      | Requerido | Descripción                     |
|--------------|-----------|-----------|---------------------------------|
| `id`         | UUID      | Auto      | Identificador único             |
| `nombre`     | String    | Sí        | Nombre de la categoría          |
| `descripcion`| String    | No        | Descripción opcional            |
| `activo`     | Boolean   | Sí        | Estado activo/inactivo          |
| `creadoEn`   | Timestamp | Auto      | Fecha de creación               |
| `actualizadoEn` | Timestamp | Auto   | Fecha de última actualización   |

---

## Notas Técnicas

- El `userId` del creador/actualizador se lee del header `X-User-Id`.
- La autorización de rol (ADMIN) se valida en el servicio leyendo `X-User-Roles`, no en el Gateway.
- Usar `@PageableDefault(size = 20)` para paginación con Spring Data.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_11 | Requiere manejador global de excepciones |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Los 5 endpoints funcionan correctamente vía Gateway.
- [ ] El intento de eliminar categoría con productos devuelve `409`.
- [ ] PR mergeado a `develop`.
