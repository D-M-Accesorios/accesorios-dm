# HU-DEV-SALB_13 — CRUD de Materiales

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_13                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Media                                          |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008, ADR-009                      |
| **Rama**           | `HU-DEV-SALB_13`                               |
| **Schema BD**      | `catalogo`                                     |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** administrador,
> **quiero** gestionar los tipos de material de los productos,
> **para** clasificarlos por su composición y facilitar búsquedas y filtros.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/catalog/materials` devuelve la lista paginada de materiales activos.
- [ ] `GET /api/v1/catalog/materials/{id}` devuelve el detalle de un material por ID.
- [ ] `POST /api/v1/catalog/materials` crea un nuevo material (rol ADMIN).
- [ ] `PUT /api/v1/catalog/materials/{id}` actualiza un material existente (rol ADMIN).
- [ ] `DELETE /api/v1/catalog/materials/{id}` elimina un material (rol ADMIN).
- [ ] El listado soporta paginación con `page` y `size`.
- [ ] Si el material no existe → `404 MATERIAL_NOT_FOUND`.
- [ ] Si se intenta eliminar un material con productos asociados → `409 CONFLICT`.
- [ ] Campos inválidos → `422 VALIDATION_ERROR` con `details`.

---

## Campos de la Entidad Material

| Campo        | Tipo      | Requerido | Descripción               |
|--------------|-----------|-----------|---------------------------|
| `id`         | UUID      | Auto      | Identificador único       |
| `nombre`     | String    | Sí        | Nombre del material       |
| `descripcion`| String    | No        | Descripción opcional      |
| `activo`     | Boolean   | Sí        | Estado activo/inactivo    |
| `creadoEn`   | Timestamp | Auto      | Fecha de creación         |

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_11 | Requiere manejador global de excepciones |
| Paralela con | HU-DEV-SALB_12 | Mismo patrón, pueden desarrollarse en paralelo |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Los 5 endpoints funcionan correctamente vía Gateway.
- [ ] PR mergeado a `develop`.
