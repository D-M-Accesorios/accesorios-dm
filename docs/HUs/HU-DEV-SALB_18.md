# HU-DEV-SALB_18 — Consulta de historial de movimientos

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_18                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Media                                          |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008                               |
| **Rama**           | `HU-DEV-SALB_18`                               |
| **Schema BD**      | `inventario`, `catalogo`                       |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** administrador,
> **quiero** consultar el historial completo de movimientos de inventario con
> filtros y paginación,
> **para** auditar los cambios de stock e identificar irregularidades o patrones.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/inventory/movements` devuelve la lista paginada de movimientos.
- [ ] Soporta filtros por query params: `productoId`, `tipoMovimientoId`, `responsableId`, `fechaDesde` (ISO 8601), `fechaHasta` (ISO 8601).
- [ ] Soporta paginación: `page` (default 0), `size` (default 20).
- [ ] Los resultados están ordenados por `registradoEn` descendente (más reciente primero).
- [ ] Cada movimiento en la respuesta incluye: datos del producto (id, sku, nombre), tipo de movimiento, cantidad, motivo, responsableId y fecha.
- [ ] Solo accesible para rol `ADMIN`.
- [ ] Si `fechaDesde` es posterior a `fechaHasta` → `422 VALIDATION_ERROR`.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_17 | Los movimientos deben poder registrarse primero |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que los filtros de fecha funcionan correctamente.
- [ ] Verificado que solo ADMIN puede acceder al historial.
- [ ] PR mergeado a `develop`.
