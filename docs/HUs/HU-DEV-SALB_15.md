# HU-DEV-SALB_15 — Gestión de imágenes de producto

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_15                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Media                                          |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008                               |
| **Rama**           | `HU-DEV-SALB_15`                               |
| **Schema BD**      | `catalogo`                                     |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** cliente del portal,
> **quiero** ver las imágenes asociadas a cada producto,
> **para** evaluar visualmente el artículo antes de comprarlo.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/catalog/products/{id}/images` devuelve la lista de imágenes del producto.
- [ ] Cada imagen incluye: `id`, `url`, `esPrincipal`, `orden`.
- [ ] Las imágenes se devuelven ordenadas por `orden` ascendente.
- [ ] Si el producto no existe → `404 PRODUCT_NOT_FOUND`.
- [ ] Si el producto no tiene imágenes, devuelve un array vacío `[]` (no es error).

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_14 | Requiere que el CRUD de productos exista |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que se devuelven las imágenes ordenadas correctamente.
- [ ] PR mergeado a `develop`.
