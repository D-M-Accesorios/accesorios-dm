# ADR-025: Modelo de Datos Distribuido en 8 Schemas de Dominio

| Campo | Valor |
|---|---|
| **ID** | ADR-025 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Base de Datos, todos los microservicios |

---

## Contexto

El sistema tiene 17 tablas que representan diferentes dominios de negocio: seguridad, clientes, catálogo de productos, promociones, ventas, logística e inventario. Organizar estas tablas en una única base de datos sin separación lógica resultaría en un modelo difícil de mantener y sin límites de dominio claros.

---

## Problema

¿Cómo organizar el modelo de datos de 17 tablas en una base de datos compartida para que refleje los límites de dominio del negocio, facilite la comprensión del sistema, y permita que múltiples microservicios accedan a sus datos con claridad?

---

## Decisión

Se adoptó un **modelo de datos distribuido en 8 schemas de PostgreSQL**, donde cada schema agrupa tablas del mismo dominio de negocio. Las relaciones entre schemas se expresan mediante foreign keys explícitas.

**Modelo de datos completo:**

```
security (Autenticación y autorización)
├── rol                      → Roles del sistema (ADMIN, VENDEDOR, BODEGUERO)
└── empleado                 → Usuarios internos del negocio (FK → rol)

clientes (Gestión de clientes)
└── cliente                  → Clientes del e-commerce

catalogo (Productos)
├── categoria                → Categorías de productos
├── material                 → Materiales de los productos
├── producto                 → Productos (FK → categoria, material)
└── imagen_producto          → Imágenes del producto (FK → producto)

promociones (Descuentos)
├── promocion                → Definición de promociones
└── promocion_producto       → Relación M:N producto-promoción (FK → producto, promocion)

ventas (Transacciones)
├── carrito                  → Carritos de compra (FK → cliente)
├── item_carrito             → Items del carrito (FK → carrito, producto)
├── pedido                   → Pedidos creados (FK → cliente, estado_pedido)
└── detalle_pedido           → Líneas del pedido (FK → pedido, producto)

logistica (Seguimiento)
├── estado_pedido            → Catálogo de estados
└── historial_estado_pedido  → Cambios de estado del pedido (FK → pedido, estado_pedido)

inventario (Movimientos)
├── tipo_movimiento          → Tipos de movimiento (entrada, salida, ajuste)
└── inventario_movimiento    → Registro de movimientos (FK → producto, tipo_movimiento)

public                       → Schema por defecto de PostgreSQL (sin tablas propias)
```

**Relaciones cross-schema:**

```
ventas.pedido.id_cliente          → clientes.cliente.id_cliente
ventas.item_carrito.id_producto   → catalogo.producto.id_producto
ventas.pedido.id_estado_actual    → logistica.estado_pedido.id_estado
inventario.movimiento.id_producto → catalogo.producto.id_producto
```

---

## Justificación Técnica

- **Alineamiento con dominios de negocio**: Cada schema corresponde a un bounded context claro: seguridad, clientes, catálogo, ventas, etc.
- **Namespacing semántico**: `catalogo.producto` vs. `ventas.detalle_pedido` vs. `inventario.inventario_movimiento` comunica el contexto sin ambigüedad.
- **Foreign keys cross-schema**: PostgreSQL soporta FK entre schemas en la misma base de datos, manteniendo integridad referencial sin duplicación de datos.
- **Propiedad de schema por microservicio**: Security Service es el propietario lógico de `security` y `clientes`. Inventory Service de `catalogo`, `promociones`, `inventario`. Payment Service de `ventas` y `logistica`.
- **Escalabilidad futura**: Si se decide separar en BDs independientes, los schemas son las unidades de migración.

---

## Consecuencias

### Ventajas
- Modelo de datos auto-documentado: el schema name comunica el dominio.
- Integridad referencial garantizada por FK entre schemas.
- Los ORMs pueden apuntar a schemas específicos (`@Table(schema="catalogo")`).
- Las vistas de reporte son naturales dado que los joins cross-schema son soportados.
- Las políticas RLS se aplican por schema, simplificando la configuración de seguridad.

### Desventajas
- **Acoplamiento de datos entre microservicios**: `ventas.pedido` tiene FK a `clientes.cliente` y `catalogo.producto`. Un DELETE en catálogo puede fallar por FK constraint desde ventas. Esto crea acoplamiento de datos implícito.
- **Payment Service accede a schemas ajenos**: El Prisma schema del Payment Service declara modelos de `security` y `catalogo` para leer datos que "pertenecen" al Security e Inventory Services.
- **Sin schema de pagos**: El modelo no tiene un schema `pagos` con tablas de transacciones financieras. Los pagos son externos (WhatsApp). Si se integra una pasarela, requiere agregar el schema.
- **`public` sin uso**: El schema `public` está declarado en el Prisma schema pero sin tablas, generando overhead en la configuración.

### Trade-offs
Organización semántica y mantenibilidad vs. acoplamiento de datos entre dominios. Para una BD compartida, los schemas son el mejor balance entre organización y pragmatismo.

---

## Diseño de Foreign Keys Cross-Schema

| FK Source | FK Target | Cardinalidad |
|---|---|---|
| `security.empleado.id_rol` | `security.rol.id_rol` | N:1 |
| `catalogo.producto.id_categoria` | `catalogo.categoria.id_categoria` | N:1 |
| `catalogo.producto.id_material` | `catalogo.material.id_material` | N:1 |
| `catalogo.imagen_producto.id_producto` | `catalogo.producto.id_producto` | N:1 |
| `promociones.promocion_producto.id_producto` | `catalogo.producto.id_producto` | M:N |
| `ventas.carrito.id_cliente` | `clientes.cliente.id_cliente` | N:1 |
| `ventas.item_carrito.id_producto` | `catalogo.producto.id_producto` | N:1 |
| `ventas.pedido.id_cliente` | `clientes.cliente.id_cliente` | N:1 |
| `ventas.pedido.id_estado_actual` | `logistica.estado_pedido.id_estado` | N:1 |
| `ventas.detalle_pedido.id_producto` | `catalogo.producto.id_producto` | N:1 |
| `inventario.inventario_movimiento.id_producto` | `catalogo.producto.id_producto` | N:1 |

---

## Impacto Arquitectónico

**Fundamental**. El modelo de datos es el foundation de todo el sistema. Todas las decisiones de ORM, API, y performance se derivan de él.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Borrado de producto con FK activas | Media | Medio | Usar soft delete (campo `estado=false`) en lugar de DELETE físico |
| Separación futura en BDs independientes costosa | Baja | Alto | Documentar dependencias cross-schema para facilitar la migración |
| Schema `public` innecesario | Certero | Bajo | Remover de la configuración de Prisma |

---

## Relación con Otros Componentes

- **ADR-011**: Los schemas son el mecanismo de aislamiento de la BD compartida.
- **ADR-012**: Liquibase gestiona la evolución de todos los schemas.
- **ADR-015**: RLS se aplica por schema con roles específicos.
- **ADR-023**: Los 35 índices cubren campos de todos los schemas.
- **ADR-024**: Las vistas cruzan schemas para generar reportes consolidados.

---

## Consideraciones Futuras

- Agregar schema `pagos` cuando se integre pasarela de pago.
- Implementar soft delete consistente en todas las tablas para evitar problemas de FK.
- Documentar el mapa de dependencias cross-schema para facilitar una eventual separación en BDs independientes.
- Remover `public` de la configuración de Prisma si no tiene tablas propias.

---

## Por qué es Design

Es **Design** porque define la arquitectura del modelo de datos del sistema: cómo se organizan los dominios de negocio en schemas, cuáles son las relaciones entre entidades, y cómo este diseño impacta el acceso a datos de los microservicios.
