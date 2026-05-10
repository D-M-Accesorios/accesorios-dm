# HU-DEV-SALB_16 — Consulta de stock por producto

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_16                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Alta                                           |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008                               |
| **Rama**           | `HU-DEV-SALB_16`                               |
| **Schema BD**      | `inventario`, `catalogo`                       |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** usuario autenticado,
> **quiero** consultar el stock disponible de un producto específico,
> **para** saber si está disponible antes de iniciar una compra o recomendarlo.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/inventory/stock/{productId}` devuelve la cantidad disponible actual del producto.
- [ ] `GET /api/v1/inventory/stock` devuelve el stock de todos los productos activos (paginado).
- [ ] El stock actual se calcula como la suma neta de todos los movimientos del producto (entradas - salidas).
- [ ] Si el producto no existe → `404 PRODUCT_NOT_FOUND`.
- [ ] Si el producto existe pero no tiene movimientos registrados → stock es `0` (no es un error).
- [ ] La respuesta incluye el `productoId`, `nombre` del producto y `cantidadDisponible`.

---

## Ejemplo de Respuesta

```json
{
  "productoId": "550e8400-e29b-41d4-a716-446655440000",
  "sku": "ACC-001",
  "nombre": "Collar de plata 925",
  "cantidadDisponible": 42,
  "actualizadoEn": "2026-05-10T14:32:00.000Z"
}
```

---

## Notas Técnicas

- El cálculo del stock puede hacerse con una query de agregación sobre `inventario.inventario_movimiento` usando `SUM` con signo positivo para entradas y negativo para salidas.
- Considerar una vista materializada en el futuro si el volumen de movimientos crece significativamente.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_11 | Requiere manejador global |
| Bloqueada por | HU-DEV-SALB_14 | El producto debe existir |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que el stock calculado coincide con los movimientos en BD.
- [ ] Verificado que un producto sin movimientos devuelve `0`.
- [ ] PR mergeado a `develop`.
