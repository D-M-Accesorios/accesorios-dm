# ADR-006: Actualización de Stock mediante Triggers de Base de Datos

| Campo | Valor |
|---|---|
| **ID** | ADR-006 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Payment Service, Inventory Service, Base de Datos |

---

## Contexto

El sistema gestiona el stock de productos. Cuando se procesa un pedido, el stock debe decrementarse. Cuando se hace un movimiento de inventario (entrada de mercancía), el stock debe incrementarse. Esta lógica puede implementarse en la capa de aplicación (microservicios) o en la capa de persistencia (base de datos).

El Payment Service crea pedidos y descuenta stock directamente. Paralelamente, existe una tabla `inventario.inventario_movimiento` que registra todos los movimientos y actualiza el stock mediante triggers de PostgreSQL.

---

## Problema

¿Dónde debe residir la lógica de actualización del stock: en los microservicios (capa de aplicación) o en la base de datos (triggers/funciones)? ¿Cómo garantizar consistencia entre la tabla de movimientos de inventario y el stock actual del producto?

---

## Decisión

Se adoptó un **modelo dual**: los triggers de PostgreSQL son la fuente autoritativa para la actualización de stock a través de la tabla de movimientos, pero el Payment Service también actualiza el stock directamente en la tabla `producto` durante la creación del pedido. Los triggers actúan como mecanismo de auditoría y para movimientos manuales de inventario.

**Evidencia en código:**

```sql
-- accesorios-dm-database/01_ddl/08_triggers/001_inventario_triggers.sql
CREATE TRIGGER trg_update_stock_on_insert
    AFTER INSERT ON inventario.inventario_movimiento
    FOR EACH ROW
    EXECUTE FUNCTION inventario.f_update_stock_on_insert();

-- accesorios-dm-database/01_ddl/06_functions/001_update_stock_functions.sql
CREATE OR REPLACE FUNCTION inventario.f_update_stock_on_insert()
RETURNS TRIGGER AS '
BEGIN
    UPDATE catalogo.producto SET stock = stock + NEW.cantidad
    WHERE id_producto = NEW.id_producto;
    RETURN NEW;
END;';
```

```js
// accesorios-dm-payment-service/src/controllers/pedidoController.js
// El Payment Service actualiza stock directamente Y registra el movimiento
await prisma.producto.update({
    where: { id_producto: item.id_producto },
    data: { stock: item.producto.stock - item.cantidad }
});

// Y también inserta en inventario_movimiento (que TAMBIÉN dispara el trigger):
await prisma.$executeRaw`
    INSERT INTO inventario.inventario_movimiento (cantidad, referencia, id_producto, id_tipo_movimiento)
    VALUES (${-item.cantidad}, ${`Pedido #${pedido.id_pedido}`}, ${item.id_producto}, 2)
`;
```

---

## Justificación Técnica

- **Integridad garantizada**: Los triggers se ejecutan en la misma transacción que el INSERT, garantizando consistencia ACID.
- **Auditoría completa**: Cada cambio de stock queda registrado en `inventario_movimiento` con fecha, referencia y tipo.
- **Cross-service consistency**: Cualquier servicio que inserte en `inventario_movimiento` automáticamente actualiza el stock, sin depender de coordinación de microservicios.

---

## Consecuencias

### Ventajas
- Consistencia de datos garantizada por la base de datos, no por la aplicación.
- Historial completo de movimientos de inventario (entrada, salida, ajuste).
- Cualquier herramienta que acceda directamente a la BD respeta la lógica de negocio.
- Los triggers para UPDATE y DELETE permiten rollback de movimientos.

### Desventajas
- **DOBLE DESCUENTO DE STOCK**: El Payment Service actualiza el stock directamente (`producto.update`) Y luego inserta en `inventario_movimiento` que dispara el trigger que lo descuenta nuevamente. **El stock queda incorrecto.**
- **Lógica de negocio en dos capas**: El stock se controla tanto en triggers SQL como en la aplicación, violando el principio de responsabilidad única.
- **Acoplamiento a PostgreSQL**: Los triggers son específicos de PostgreSQL y dificultan la migración a otro motor.
- **Debugging complejo**: Un bug de stock requiere investigar tanto el código de aplicación como los triggers.

### Trade-offs
Integridad de datos vs. claridad de lógica de negocio. Los triggers son robustos pero ocultan comportamiento.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Solo actualización en aplicación (sin triggers) | Sin auditoría automática, sin garantía en acceso directo a BD |
| Solo triggers (sin actualización en app) | Requiere siempre insertar en movimiento; menos intuitivo |
| Event Sourcing | Complejidad excesiva para el tamaño del proyecto |
| Stored Procedures | Similar a triggers pero menos automático |

---

## Impacto Arquitectónico

**Alto**. Hay un bug crítico activo: el stock se descuenta **dos veces** por pedido porque el Payment Service hace UPDATE directo Y luego INSERT en movimientos (que dispara el trigger de UPDATE adicional).

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| **Doble descuento de stock** | **Certero** | **Crítico** | Eliminar el UPDATE directo en pedidoController.js; solo insertar en inventario_movimiento |
| Trigger falla silenciosamente | Baja | Alto | Agregar manejo de errores y monitoreo |
| Inconsistencia en migración a otra BD | Baja | Medio | Documentar dependencia de PostgreSQL |

---

## Corrección Necesaria

```js
// ELIMINAR del pedidoController.js:
await prisma.producto.update({
    where: { id_producto: item.id_producto },
    data: { stock: item.producto.stock - item.cantidad }
});
// El stock ya se actualiza vía trigger cuando se inserta en inventario_movimiento
```

---

## Relación con Otros Componentes

- **ADR-011**: El diseño de schemas incluye `inventario` específicamente para movimientos.
- **ADR-019**: Prisma no tiene visibilidad de los triggers; los efectos colaterales son invisibles.
- **ADR-024**: Las vistas de reportes incluyen `vw_movimientos_producto` basada en esta tabla.

---

## Consideraciones Futuras

- Corregir el doble descuento eliminando el UPDATE directo del Payment Service.
- Unificar la lógica de stock en un servicio dedicado de inventario.
- Agregar monitoreo de stock negativo como señal de alerta.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento del sistema ante operaciones de negocio (creación de pedidos, movimientos de inventario), cómo se actualiza el estado de los datos, y garantiza consistencia a través de mecanismos reactivos de la base de datos.
