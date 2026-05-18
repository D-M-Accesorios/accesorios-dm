# ADR-019: Prisma ORM con Soporte Multi-Schema para el Payment Service

| Campo | Valor |
|---|---|
| **ID** | ADR-019 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Payment Service |

---

## Contexto

El Payment Service (Node.js/Express) necesita acceder a múltiples schemas de PostgreSQL: `ventas` y `logistica` (sus dominios propios), pero también `catalogo` (para leer precios y stock de productos), `clientes` (para gestionar clientes), y `security` (para datos de empleados en el módulo admin). Un ORM que soporte esta configuración multi-schema simplifica el acceso a datos.

---

## Problema

¿Qué estrategia de acceso a datos adoptar en el Payment Service (Node.js) para interactuar con múltiples schemas de PostgreSQL de forma tipada, con buen soporte de desarrollo y capacidad de joins cross-schema?

---

## Decisión

Se adoptó **Prisma ORM 5.22** con la funcionalidad `multiSchema` (en preview) para el Payment Service. El schema de Prisma declara todos los modelos necesarios con su schema de PostgreSQL correspondiente.

**Evidencia en código:**

```prisma
// accesorios-dm-payment-service/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
  previewFeatures = ["multiSchema"]
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  schemas  = ["security", "clientes", "catalogo", "ventas", "logistica", "inventario", "public"]
}

model Carrito {
  @@schema("ventas")
}
model Producto {
  @@schema("catalogo")
  carritoItems ItemCarrito[]
  detallesPedido DetallePedido[]
}
model EstadoPedido {
  @@schema("logistica")
}
```

```js
// accesorios-dm-payment-service/src/prisma/index.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
module.exports = prisma;

// Uso en controllers - sin necesidad de escribir SQL
const carrito = await prisma.carrito.findUnique({
    where: { id_carrito: parseInt(id_carrito) },
    include: { items: { include: { producto: true } } }
});
```

---

## Justificación Técnica

- **Type safety**: Prisma genera tipos TypeScript a partir del schema, reduciendo errores de runtime.
- **Autocompletado**: Los modelos generados permiten autocompletado en el IDE para queries complejas.
- **`multiSchema` para acceso cross-schema**: Una sola instancia de Prisma Client accede a todos los schemas necesarios sin JOIN manuales en SQL raw.
- **Migrations independientes**: Prisma puede generar migraciones, aunque en este proyecto se delega a Liquibase.
- **Raw SQL cuando es necesario**: `prisma.$executeRaw` permite SQL directo para operaciones que Prisma no soporta nativamente (el INSERT en `inventario_movimiento`).

---

## Consecuencias

### Ventajas
- Queries relacionales complejas sin SQL manual: `include: { items: { include: { producto: true } } }`.
- Generación automática de tipos a partir del schema de BD.
- Soporte nativo para transacciones: `prisma.$transaction([...])`.
- Conexión con pool integrado, sin necesidad de `pg` directamente.
- Experiencia de desarrollo superior a SQL raw o pg nativo.

### Desventajas
- **`multiSchema` está en preview**: La funcionalidad no está marcada como estable. Puede haber cambios breaking en futuras versiones de Prisma.
- **Violación de encapsulación de dominio**: El Payment Service declara en su Prisma schema modelos como `Empleado`, `Rol`, `Cliente`, `Producto` que son "propiedad" de otros microservicios (Security, Inventory). Esto crea acoplamiento implícito.
- **Schema de Prisma debe sincronizarse con Liquibase**: Si el esquema de BD cambia (por Liquibase), el schema de Prisma debe actualizarse manualmente y regenerarse con `npx prisma generate`.
- **Sin `detalle_pedido.subtotal` calculado**: El campo `subtotal` está marcado como `@ignore` en Prisma porque es una columna generada en BD que Prisma no maneja bien.
- **Sin transacciones en la creación de pedidos**: Los múltiples `await prisma.X.create/update` en `crearPedidoDesdeCarrito` no están envueltos en `prisma.$transaction`, lo que puede dejar datos inconsistentes si alguna operación falla a mitad del proceso.

### Trade-offs
Productividad de desarrollo con Prisma vs. posible fuga de encapsulación y dependencia de feature preview. Para el MVP, los beneficios superan los riesgos.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Knex.js (query builder) | Sin type safety, más boilerplate |
| `pg` nativo (SQL raw) | Sin abstracciones, propenso a errores |
| TypeORM | Más maduro para TypeScript/Node, pero más pesado |
| Sequelize | Menor soporte para multi-schema de PostgreSQL |

---

## Impacto Arquitectónico

**Alto**. Prisma es la única interfaz entre el Payment Service y la base de datos. Su schema define los modelos accesibles y los schemas de BD que puede consultar.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| `multiSchema` breaking change en Prisma 6 | Baja | Alto | Lockear versión de Prisma; monitorear changelog |
| Pedido incompleto por fallo sin transacción | Media | Crítico | Envolver todo en `prisma.$transaction` |
| Schema Prisma desincronizado con Liquibase | Media | Alto | Agregar `prisma db pull` a proceso de desarrollo |

---

## Corrección Crítica Necesaria

```js
// crearPedidoDesdeCarrito debería usar transacción:
const result = await prisma.$transaction(async (tx) => {
    const pedido = await tx.pedido.create({ ... });
    for (const item of carrito.items) {
        await tx.detallePedido.create({ ... });
        // actualizar stock (o solo insertar en inventario_movimiento via trigger)
    }
    await tx.historialEstadoPedido.create({ ... });
    await tx.carrito.update({ ... });
    return pedido;
});
```

---

## Relación con Otros Componentes

- **ADR-006**: El doble descuento de stock ocurre porque Prisma no ve los triggers de PostgreSQL.
- **ADR-011**: El `multiSchema` de Prisma refleja la arquitectura de schemas compartidos.
- **ADR-012**: Las migraciones de Liquibase deben mantenerse sincronizadas con el schema de Prisma.

---

## Consideraciones Futuras

- Envolver la creación de pedidos en `prisma.$transaction`.
- Remover modelos ajenos (`Empleado`, `Rol`) del schema de Prisma del Payment Service.
- Monitorear la estabilidad de `multiSchema` y migrar cuando sea GA.

---

## Por qué es Design

Es **Design** porque define el patrón de acceso a datos del Payment Service: qué ORM se usa, cómo se modela el acceso a múltiples schemas, y qué estrategias de transaccionalidad se aplican.
