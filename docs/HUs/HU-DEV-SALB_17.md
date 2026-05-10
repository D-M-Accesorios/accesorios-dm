# HU-DEV-SALB_17 — Registro de movimiento de inventario

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_17                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Alta                                           |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008, ADR-009                      |
| **Rama**           | `HU-DEV-SALB_17`                               |
| **Schema BD**      | `inventario`                                   |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** administrador o vendedor,
> **quiero** registrar un movimiento de inventario (entrada, salida o ajuste),
> **para** mantener el stock del sistema actualizado y tener trazabilidad de
> todos los cambios.

---

## Criterios de Aceptación

- [ ] `POST /api/v1/inventory/movements` registra un nuevo movimiento.
- [ ] Campos requeridos: `productoId`, `tipoMovimientoId`, `cantidad`, `motivo`.
- [ ] La `cantidad` debe ser un número entero positivo; si no → `422 VALIDATION_ERROR`.
- [ ] El `productoId` debe corresponder a un producto existente; si no → `404 PRODUCT_NOT_FOUND`.
- [ ] El `tipoMovimientoId` debe ser un tipo válido; si no → `422 INVALID_MOVEMENT_TYPE`.
- [ ] Para movimientos de **salida** o **ajuste negativo**, verifica que el stock resultante no quede negativo; si quedaría negativo → `422 INSUFFICIENT_STOCK`.
- [ ] El `userId` del responsable se toma automáticamente del header `X-User-Id` (no debe enviarse en el body).
- [ ] El movimiento creado se devuelve en la respuesta con código `201 Created`.
- [ ] Solo accesible para roles `ADMIN` y `ROLE_VENDEDOR`.

---

## Ejemplo de Request

```json
{
  "productoId": "550e8400-e29b-41d4-a716-446655440000",
  "tipoMovimientoId": "entrada-uuid",
  "cantidad": 50,
  "motivo": "Reposición de inventario - proveedor ABC"
}
```

## Ejemplo de Respuesta (201 Created)

```json
{
  "id": "movimiento-uuid",
  "productoId": "550e8400-...",
  "tipoMovimiento": { "id": "...", "nombre": "Entrada" },
  "cantidad": 50,
  "motivo": "Reposición de inventario - proveedor ABC",
  "responsableId": "user-uuid",
  "registradoEn": "2026-05-10T14:32:00.000Z"
}
```

---

## Notas Técnicas

- El registro del movimiento debe ser una operación atómica: si falla la validación de stock, ningún movimiento se persiste.
- El `userId` se extrae del header `X-User-Id` en el controller y se pasa al servicio. No proviene del body.
- Registrar el movimiento en `inventario.inventario_movimiento` con todos los campos de auditoría.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_11 | Requiere manejador global |
| Bloqueada por | HU-DEV-SALB_16 | Necesita la lógica de cálculo de stock para validar suficiencia |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que una salida con stock insuficiente devuelve `422 INSUFFICIENT_STOCK`.
- [ ] Verificado que el `userId` del movimiento corresponde al usuario autenticado.
- [ ] Verificado que el stock se actualiza correctamente tras el movimiento.
- [ ] PR mergeado a `develop`.
