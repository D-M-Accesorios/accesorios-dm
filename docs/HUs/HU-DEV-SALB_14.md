# HU-DEV-SALB_14 — CRUD de Productos

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_14                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Crítica                                        |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008, ADR-009                      |
| **Rama**           | `HU-DEV-SALB_14`                               |
| **Schema BD**      | `catalogo`                                     |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** administrador y como cliente del portal,
> **quiero** gestionar y consultar el catálogo de productos,
> **para** mantener actualizada la oferta de la tienda y permitir que los
> clientes naveguen y seleccionen artículos.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/catalog/products` devuelve lista paginada de productos.
- [ ] `GET /api/v1/catalog/products/{id}` devuelve el detalle completo de un producto.
- [ ] `POST /api/v1/catalog/products` crea un nuevo producto (rol ADMIN).
- [ ] `PUT /api/v1/catalog/products/{id}` actualiza un producto existente (rol ADMIN).
- [ ] `DELETE /api/v1/catalog/products/{id}` elimina lógicamente un producto (rol ADMIN).
- [ ] El listado soporta filtros por query params: `categoryId`, `materialId`, `nombre` (búsqueda parcial), `activo`.
- [ ] El listado soporta paginación: `page` (default 0), `size` (default 20).
- [ ] El detalle del producto incluye: categorías, materiales e imágenes asociadas.
- [ ] Si el SKU ya existe al crear → `409 PRODUCT_ALREADY_EXISTS`.
- [ ] Si el producto no existe → `404 PRODUCT_NOT_FOUND`.
- [ ] El DELETE es lógico: cambia `activo = false`, no elimina el registro físicamente.
- [ ] Campos obligatorios inválidos → `422 VALIDATION_ERROR` con `details`.

---

## Campos de la Entidad Producto

| Campo          | Tipo      | Requerido | Descripción                              |
|----------------|-----------|-----------|------------------------------------------|
| `id`           | UUID      | Auto      | Identificador único                      |
| `sku`          | String    | Sí        | Código único del producto                |
| `nombre`       | String    | Sí        | Nombre del producto                      |
| `descripcion`  | String    | No        | Descripción larga                        |
| `precio`       | Decimal   | Sí        | Precio de venta (> 0)                    |
| `categoriaId`  | UUID      | Sí        | Referencia a categoría                   |
| `materialId`   | UUID      | No        | Referencia a material                    |
| `activo`       | Boolean   | Auto      | Estado activo (default true)             |
| `creadoEn`     | Timestamp | Auto      | Fecha de creación                        |
| `actualizadoEn`| Timestamp | Auto      | Fecha de última actualización            |

---

## Ejemplo de Respuesta GET /api/v1/catalog/products/{id}

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "sku": "ACC-001",
  "nombre": "Collar de plata 925",
  "descripcion": "Collar artesanal en plata de ley 925...",
  "precio": 85000.00,
  "activo": true,
  "categoria": {
    "id": "...",
    "nombre": "Collares"
  },
  "material": {
    "id": "...",
    "nombre": "Plata 925"
  },
  "imagenes": [
    {
      "id": "...",
      "url": "https://cdn.accesorios-dm.com/products/acc-001-main.jpg",
      "esPrincipal": true,
      "orden": 1
    }
  ],
  "creadoEn": "2026-05-10T14:32:00.000Z",
  "actualizadoEn": "2026-05-10T14:32:00.000Z"
}
```

---

## Ejemplo de Respuesta GET /api/v1/catalog/products (lista paginada)

```json
{
  "content": [ /* array de productos */ ],
  "page": 0,
  "size": 20,
  "totalElements": 150,
  "totalPages": 8,
  "first": true,
  "last": false
}
```

---

## Notas Técnicas

- Usar `@Query` con JPQL o Criteria API para los filtros dinámicos de búsqueda.
- El `precio` debe almacenarse y devolver como `BigDecimal`, nunca como `double` (precisión monetaria).
- La búsqueda por `nombre` usa `ILIKE` en PostgreSQL para búsqueda case-insensitive.
- Usar proyecciones o DTOs de respuesta para no exponer la entidad JPA directamente.
- `categoriaId` debe ser validado: si la categoría no existe → `404 CATEGORY_NOT_FOUND`.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_11 | Requiere manejador global de excepciones |
| Bloqueada por | HU-DEV-SALB_12 | Las categorías deben existir para asignarlas |
| Relacionada con | HU-DEV-SALB_15 | Las imágenes se consultan junto al producto |
| Requerida por | HU-DEV-SALB_16, 17 | Stock y movimientos referencian productos |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Los 5 endpoints funcionan correctamente vía Gateway.
- [ ] El frontend Angular puede consumir `GET /api/v1/catalog/products` y mostrar la lista.
- [ ] La búsqueda por `nombre` funciona de forma case-insensitive.
- [ ] PR mergeado a `develop`.
