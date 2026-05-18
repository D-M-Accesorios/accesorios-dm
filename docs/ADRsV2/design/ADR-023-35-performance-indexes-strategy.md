# ADR-023: Estrategia de 35 Índices de Rendimiento en PostgreSQL

| Campo | Valor |
|---|---|
| **ID** | ADR-023 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Base de Datos, Todos los servicios |

---

## Contexto

El sistema tiene 17 tablas distribuidas en 7 schemas. Las operaciones más frecuentes incluyen: búsqueda de productos por categoría/nombre, listado de carritos activos por cliente, consulta de historial de pedidos, y reportes de ventas. Sin índices adecuados, estas operaciones harían full table scans que degradarían el rendimiento a medida que los datos crecen.

---

## Problema

¿Qué campos deben indexarse en la base de datos para garantizar el rendimiento de las operaciones más frecuentes del sistema, sin agregar overhead innecesario de mantenimiento de índices?

---

## Decisión

Se crearon **35 índices específicos** organizados por schema y patrón de acceso. Los índices incluyen tanto índices simples como índices compuestos para patrones de consulta combinados.

**Distribución de índices:**

| Schema | Cantidad | Ejemplos |
|---|---|---|
| `security` | 3 | `idx_empleado_correo`, `idx_empleado_id_rol`, `idx_empleado_estado` |
| `clientes` | 2 | `idx_cliente_correo`, `idx_cliente_nombre` |
| `catalogo` | 9 | `idx_producto_nombre`, `idx_producto_id_categoria`, `idx_producto_estado_precio` |
| `promociones` | 4 | `idx_promocion_activa_fechas`, `idx_promocion_producto_promocion_producto` |
| `ventas` (carrito) | 3 | `idx_carrito_cliente_estado`, `idx_item_carrito_carrito_producto` |
| `ventas` (pedidos) | 6 | `idx_pedido_id_cliente`, `idx_pedido_cliente_fecha`, `idx_detalle_pedido_pedido_producto` |
| `logistica` | 3 | `idx_historial_id_pedido`, `idx_historial_pedido_estado` |
| `inventario` | 4 | `idx_inventario_movimiento_id_producto`, `idx_inventario_producto_fecha` |

**Ejemplos de índices compuestos estratégicos:**

```sql
-- Búsqueda de productos activos ordenados por precio (filtro de catálogo)
CREATE INDEX idx_producto_estado_precio ON catalogo.producto(estado, precio);

-- Evita duplicados carrito-producto (constraint de unicidad implícita)
CREATE INDEX idx_item_carrito_carrito_producto ON ventas.item_carrito(id_carrito, id_producto);

-- Pedidos recientes de un cliente (historial de compras)
CREATE INDEX idx_pedido_cliente_fecha ON ventas.pedido(id_cliente, fecha_pedido);

-- Promociones vigentes (query más frecuente en la API de productos)
CREATE INDEX idx_promocion_activa_fechas ON promociones.promocion(activo, fecha_inicio, fecha_fin);

-- Movimientos por producto en período (reportes de inventario)
CREATE INDEX idx_inventario_producto_fecha ON inventario.inventario_movimiento(id_producto, fecha_movimiento);
```

---

## Justificación Técnica

- **Login optimizado**: `idx_empleado_correo` convierte el `SELECT WHERE correo = ?` del login de O(n) a O(log n).
- **Catálogo eficiente**: `idx_producto_estado_precio` soporta la query más frecuente: productos activos ordenados por precio.
- **Búsqueda de texto**: `idx_producto_nombre` acelera el `LIKE '%texto%'` aunque no es tan eficiente como Full Text Search; un índice GIN sería óptimo para búsqueda de texto.
- **Joins eficientes**: Los índices en FK (`id_categoria`, `id_material`, `id_cliente`) eliminan nested loops en joins.
- **Índices compuestos prefixed**: El índice `(id_cliente, fecha_pedido)` satisface tanto queries por `id_cliente` sola como queries `id_cliente AND fecha_pedido`.

---

## Consecuencias

### Ventajas
- Queries de lectura optimizadas para los patrones de acceso más frecuentes.
- Login de empleados prácticamente instantáneo con `idx_empleado_correo`.
- Queries de reporte eficientes con índices en fechas y estados.
- `IF NOT EXISTS` en todos los CREATE INDEX permite re-ejecutar sin errores.

### Desventajas
- **35 índices tienen costo de mantenimiento**: Cada INSERT/UPDATE/DELETE actualiza todos los índices relevantes. En tablas de alto volumen de escritura, esto añade latencia.
- **`idx_producto_nombre` no soporta `LIKE '%texto%'`**: Un índice B-tree en `nombre` solo acelera `nombre LIKE 'texto%'` (prefijo), no `LIKE '%texto%'`. Para búsqueda de texto completo, se necesita un índice GIN con `pg_trgm`.
- **Sin EXPLAIN ANALYZE previo**: Los índices se definieron por razonamiento, no por evidencia de queries lentas. Algunos pueden ser innecesarios.
- **Sin estadísticas de uso**: No hay mecanismo para verificar qué índices realmente se usan vs. cuáles son overhead puro.

### Trade-offs
Mejor rendimiento de lectura vs. mayor latencia en escrituras. Para un e-commerce donde el 80-90% de operaciones son lecturas (browse del catálogo), es el trade-off correcto.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Sin índices hasta que haya problemas | Deuda técnica acumulada; mejor prevenir |
| Índices automáticos de Hibernate | Solo crea índices para PK y UK; insuficiente |
| Full-text search con Elasticsearch | Complejidad excesiva para el volumen actual |

---

## Impacto Arquitectónico

**Medio-Alto**. Determina el rendimiento de las queries más frecuentes del sistema y tiene impacto directo en la experiencia de usuario.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Índices no utilizados | Media | Bajo | Ejecutar `pg_stat_user_indexes` periódicamente |
| Búsqueda de texto ineficiente | Alta | Medio | Agregar índice GIN con `pg_trgm` para `producto.nombre` |
| Overhead de escritura con alto volumen | Baja | Medio | Monitorear con EXPLAIN ANALYZE en producción |

---

## Mejora de Búsqueda de Texto

```sql
-- Habilitar extensión para trigrams
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índice GIN para búsqueda de texto con LIKE '%texto%'
CREATE INDEX idx_producto_nombre_gin ON catalogo.producto USING GIN (nombre gin_trgm_ops);
```

---

## Relación con Otros Componentes

- **ADR-011**: Los índices cubren todos los schemas de la BD compartida.
- **ADR-024**: Las vistas de reporte se benefician de los índices en fechas y estados.
- **ADR-017/019**: Los ORMs generan queries que se benefician de estos índices.

---

## Consideraciones Futuras

- Agregar índice GIN para búsqueda de texto completo en `producto.nombre`.
- Ejecutar `EXPLAIN ANALYZE` en queries de producción para validar uso de índices.
- Revisar índices no utilizados con `pg_stat_user_indexes` y eliminar los innecesarios.

---

## Por qué es Design

Es **Design** porque define la estrategia de optimización de la capa de datos: qué campos se indexan, qué tipo de índices se usan, y cómo se alinean con los patrones de acceso de los microservicios.
