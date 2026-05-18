# ADR-024: 10 Vistas SQL para Capa de Reportes Analíticos

| Campo | Valor |
|---|---|
| **ID** | ADR-024 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Base de Datos, Payment Service (admin endpoints) |

---

## Contexto

El sistema necesita proveer reportes de negocio: ventas mensuales, top de productos, estado de inventario, historial de pedidos por cliente. Estos reportes requieren joins complejos entre múltiples schemas (`ventas`, `clientes`, `catalogo`, `logistica`, `inventario`). Si estas queries se construyen dinámicamente en los microservicios, cada cambio de lógica de reporte requiere modificar código de aplicación y desplegar.

---

## Problema

¿Dónde y cómo implementar la lógica de consultas analíticas complejas que cruzan múltiples schemas, de forma que sea mantenible, reutilizable y no acople los microservicios a queries SQL complejas?

---

## Decisión

Se crearon **10 vistas SQL** en PostgreSQL que encapsulan la lógica de reportes y son accesibles desde cualquier herramienta o microservicio. Las vistas están distribuidas en los schemas correspondientes a su dominio.

**Inventario de Vistas:**

| Vista | Schema | Propósito |
|---|---|---|
| `vw_producto_detalle` | `catalogo` | Productos con información de categoría y material |
| `vw_producto_promocion_activa` | `promociones` | Productos con promociones activas y precio calculado |
| `vw_pedido_cliente` | `ventas` | Pedidos con datos del cliente y estado actual |
| `vw_pedido_detalle_producto` | `ventas` | Detalle completo de pedidos con productos |
| `vw_pedido_historial_estados` | `logistica` | Historial completo de cambios de estado |
| `vw_carrito_activo_cliente` | `ventas` | Carritos activos con resumen y total |
| `vw_movimientos_producto` | `inventario` | Movimientos de inventario por producto |
| `vw_producto_bajo_stock` | `inventario` | Productos con stock bajo o crítico |
| `vw_ventas_por_mes` | `ventas` | Resumen de ventas agregado por mes |
| `vw_top_productos_vendidos` | `ventas` | Top 10 productos más vendidos |

**Ejemplo de vista compleja:**

```sql
-- vw_ventas_por_mes - Reporte ejecutivo de ventas
CREATE OR REPLACE VIEW ventas.vw_ventas_por_mes AS
SELECT 
    TO_CHAR(p.fecha_pedido, 'YYYY-MM') AS periodo,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    COUNT(DISTINCT p.id_cliente) AS clientes_unicos,
    SUM(p.total) AS ventas_totales,
    AVG(p.total) AS ticket_promedio,
    SUM(dp.cantidad) AS productos_vendidos
FROM ventas.pedido p
LEFT JOIN ventas.detalle_pedido dp ON p.id_pedido = dp.id_pedido
WHERE p.id_estado_actual IN (
    SELECT id_estado FROM logistica.estado_pedido WHERE nombre IN ('ENTREGADO', 'PAGADO')
)
GROUP BY periodo ORDER BY periodo DESC;
```

---

## Justificación Técnica

- **Encapsulación de lógica compleja**: Los joins cross-schema y las agregaciones se definen una vez en la BD, no en cada microservicio.
- **Reutilización**: Cualquier servicio o herramienta (Power BI, Metabase, Grafana) puede consultar las vistas sin duplicar la lógica.
- **Mantenibilidad**: Un cambio en la lógica de reporte (ej: qué estados cuentan como "vendido") se hace en un SQL, no en código de aplicación.
- **Performance**: Las vistas regulares en PostgreSQL no materializan datos; son atajos de query. Los índices existentes aplican sobre las queries de las vistas.
- **Comentarios en vistas**: Cada vista tiene `COMMENT ON VIEW` con descripción, facilitando el descubrimiento.

---

## Consecuencias

### Ventajas
- Cero código de aplicación para reportes estándar.
- Los endpoints del `adminController.js` del Payment Service pueden consultar vistas directamente.
- Retrocompatibles con cambios en tablas (siempre que los campos referenciados existan).
- Habilitadas para herramientas de BI/dashboards sin exportar datos.
- `vw_producto_bajo_stock` permite alertas de inventario crítico.

### Desventajas
- **Sin materialización**: Las vistas son "live queries". Para reportes complejos con millones de filas, pueden ser lentas. Las materialized views (directorio existe pero vacío) serían más eficientes para reportes frecuentes.
- **Lógica de negocio distribuida**: La regla "qué estados cuentan como ventas completadas" está en la vista SQL. Si cambia la lógica de negocio, hay que actualizar tanto el código como las vistas.
- **`vw_top_productos_vendidos` con LIMIT hardcodeado**: `LIMIT 10` en la vista no es configurable. Si se quiere top 20, debe modificarse la vista.
- **Sin parámetros**: Las vistas SQL no aceptan parámetros. Para filtrar por fecha o categoría, la query encima de la vista agrega el WHERE.

### Trade-offs
Simplicidad de consulta vs. flexibilidad. Las vistas son excelentes para reportes estándar; para reportes ad-hoc con parámetros dinámicos, una capa de BI o funciones SQL parametrizadas son más adecuadas.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Queries raw en microservicios | Lógica duplicada, difícil mantenimiento |
| Stored Procedures | Mayor complejidad que vistas para consultas de lectura |
| Materialized Views | Adecuadas para reportes lentos; estructura existe pero vacía |
| Herramienta BI externa (Metabase) | Correcta para visualización; no para el API de admin |

---

## Impacto Arquitectónico

**Medio**. Las vistas son una capa de abstracción sobre los datos que facilita el desarrollo de los endpoints de reporting del admin.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Views lentas con alto volumen | Media | Medio | Materialize `vw_ventas_por_mes` y `vw_top_productos_vendidos` |
| Lógica de negocio en SQL acoplada | Media | Medio | Documentar bien qué estados cuentan como "ventas" |
| `LIMIT 10` en top productos rígido | Certero | Bajo | Convertir a función SQL con parámetro |

---

## Mejora: Materialize Vistas Pesadas

```sql
-- Para reportes que se consultan frecuentemente y pueden tener datos históricos
CREATE MATERIALIZED VIEW ventas.mvw_ventas_por_mes AS
SELECT ... (misma query que la vista regular);

-- Refrescar periódicamente (cron o manual)
REFRESH MATERIALIZED VIEW ventas.mvw_ventas_por_mes;
```

---

## Relación con Otros Componentes

- **ADR-011**: Las vistas cruzan múltiples schemas; solo posible en BD compartida.
- **ADR-023**: Los índices en fechas y estados benefician las queries de las vistas.
- **ADR-019**: El `adminController.js` usa Prisma `$executeRaw` o queries directas para consultar estas vistas.

---

## Consideraciones Futuras

- Materializar `vw_ventas_por_mes` y `vw_top_productos_vendidos` con refresh automático.
- Convertir `vw_top_productos_vendidos` a función SQL con parámetro de límite.
- Conectar herramienta de BI (Metabase, Grafana) directamente a las vistas.

---

## Por qué es Design

Es **Design** porque define los patrones de diseño de la capa analítica del sistema: cómo se estructuran las consultas de reporte, dónde se encapsula la lógica de negocio analítica, y cómo se abstrae la complejidad de los joins cross-schema.
