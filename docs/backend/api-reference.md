# API Reference — Backend Accesorios DM

**Base URL (desarrollo local):** `http://localhost:3000`  
**Versión:** v1  
**Autenticación:** `Authorization: Bearer <token>` en todos los endpoints (excepto `/health`)

> Ver [authentication.md](./authentication.md) para obtener tokens de desarrollo.

---

## Formato de error estándar (ADR-009)

Todos los errores usan este formato:

```json
{
  "status": 422,
  "error": "VALIDATION_ERROR",
  "message": "La solicitud contiene campos inválidos.",
  "path": "/api/v1/catalog/products",
  "timestamp": "2026-05-10T22:00:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": [
    {
      "field": "precio",
      "rejectedValue": -100,
      "message": "El precio debe ser mayor a 0"
    }
  ]
}
```

---

## Paginación

Los endpoints de listado devuelven este envelope:

```json
{
  "content": [...],
  "page": {
    "size": 20,
    "number": 0,
    "totalElements": 45,
    "totalPages": 3
  }
}
```

Parámetros de query: `?page=0&size=20`

---

## Health

### `GET /health`
Estado del gateway. **Sin autenticación.**

```bash
curl http://localhost:3000/health
```

```json
{ "status": "UP", "timestamp": "2026-05-10T22:00:00.000Z" }
```

### `GET /health/services`
Estado del gateway y sus dependencias. **Sin autenticación.**

```bash
curl http://localhost:3000/health/services
```

```json
{
  "status": "DEGRADED",
  "timestamp": "2026-05-10T22:00:00.000Z",
  "services": {
    "security-service": { "status": "DOWN", "responseTimeMs": null },
    "inventory-service": { "status": "UP", "responseTimeMs": 12 }
  }
}
```

`status` puede ser `UP` | `DEGRADED` | `DOWN`.

---

## Catálogo — Categorías

### `GET /api/v1/catalog/categories`
Lista las categorías activas. Requiere autenticación.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/catalog/categories?page=0&size=20"
```

**Response 200:**
```json
{
  "content": [
    {
      "id": 1,
      "nombre": "Anillos",
      "descripcion": "Anillos en diferentes estilos",
      "estado": true
    },
    {
      "id": 2,
      "nombre": "Collares",
      "descripcion": "Collares y gargantillas",
      "estado": true
    }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 4, "totalPages": 1 }
}
```

---

### `GET /api/v1/catalog/categories/{id}`
Obtiene una categoría por ID.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/catalog/categories/1
```

**Response 200:**
```json
{
  "id": 1,
  "nombre": "Anillos",
  "descripcion": "Anillos en diferentes estilos",
  "estado": true
}
```

**Response 404:**
```json
{
  "status": 404,
  "error": "CATEGORY_NOT_FOUND",
  "message": "La categoría '999' no fue encontrada.",
  ...
}
```

---

### `POST /api/v1/catalog/categories` — Rol: ADMIN

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Pulseras", "descripcion": "Pulseras y brazaletes"}' \
  http://localhost:3000/api/v1/catalog/categories
```

**Body:**
```json
{
  "nombre": "Pulseras",
  "descripcion": "Pulseras y brazaletes"
}
```

**Response 201:**
```json
{
  "id": 5,
  "nombre": "Pulseras",
  "descripcion": "Pulseras y brazaletes",
  "estado": true
}
```

---

### `PUT /api/v1/catalog/categories/{id}` — Rol: ADMIN

```bash
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Pulseras premium", "activo": true}' \
  http://localhost:3000/api/v1/catalog/categories/5
```

**Body (todos los campos son opcionales):**
```json
{
  "nombre": "Pulseras premium",
  "descripcion": "Pulseras y brazaletes de alta gama",
  "activo": true
}
```

---

### `DELETE /api/v1/catalog/categories/{id}` — Rol: ADMIN

Elimina una categoría. Falla con 409 si tiene productos asociados.

```bash
curl -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/catalog/categories/5
```

**Response 204:** sin body.

**Response 409:**
```json
{
  "status": 409,
  "error": "CATEGORY_HAS_PRODUCTS",
  "message": "La categoría '1' tiene productos asociados y no puede eliminarse.",
  ...
}
```

---

## Catálogo — Materiales

### `GET /api/v1/catalog/materials`
Lista todos los materiales.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/catalog/materials
```

**Response 200:**
```json
{
  "content": [
    { "id": 1, "nombre": "General", "descripcion": "Material general" },
    { "id": 2, "nombre": "Oro 18K", "descripcion": "Oro de 18 quilates" },
    { "id": 3, "nombre": "Plata 925", "descripcion": "Plata esterlina" },
    { "id": 4, "nombre": "Acero Inoxidable", "descripcion": "Acero quirurgico" }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 4, "totalPages": 1 }
}
```

### `GET /api/v1/catalog/materials/{id}`
### `POST /api/v1/catalog/materials` — Rol: ADMIN
### `PUT /api/v1/catalog/materials/{id}` — Rol: ADMIN
### `DELETE /api/v1/catalog/materials/{id}` — Rol: ADMIN

Misma estructura que Categorías. El body de creación/actualización acepta `nombre` y `descripcion`.

---

## Catálogo — Productos

### `GET /api/v1/catalog/products`
Lista productos con filtros opcionales.

```bash
# Todos los productos activos
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/catalog/products?estado=true&page=0&size=10"

# Filtrar por categoría
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/catalog/products?categoryId=1"

# Filtrar por nombre (búsqueda parcial)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/catalog/products?nombre=collar"
```

**Query params:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `categoryId` | Integer | Filtrar por categoría |
| `materialId` | Integer | Filtrar por material |
| `nombre` | String | Búsqueda parcial por nombre |
| `estado` | Boolean | `true` = activos, `false` = inactivos |
| `page` | Integer | Número de página (base 0) |
| `size` | Integer | Tamaño de página (máx 100) |

**Response 200:**
```json
{
  "content": [
    {
      "id": 1,
      "nombre": "Producto Demo",
      "precio": 100000.00,
      "stock": 50,
      "estado": true,
      "categoria": { "id": 1, "nombre": "General" },
      "material": { "id": 1, "nombre": "General" },
      "fechaCreacion": "2026-05-10T20:00:00"
    }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 1, "totalPages": 1 }
}
```

> **Nota:** `stock` refleja el inventario real mantenido por triggers de base de datos. Siempre está actualizado.

---

### `GET /api/v1/catalog/products/{id}`
Detalle completo de un producto, incluyendo imágenes.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/catalog/products/1
```

**Response 200:**
```json
{
  "id": 1,
  "nombre": "Collar de plata 925",
  "descripcion": "Collar artesanal en plata esterlina con dije de corazón",
  "precio": 85000.00,
  "stock": 42,
  "estado": true,
  "categoria": { "id": 2, "nombre": "Collares" },
  "material": { "id": 3, "nombre": "Plata 925" },
  "imagenes": [
    { "id": 1, "urlImagen": "https://cdn.example.com/collar-01.jpg", "orden": 1 },
    { "id": 2, "urlImagen": "https://cdn.example.com/collar-02.jpg", "orden": 2 }
  ],
  "fechaCreacion": "2026-05-10T20:00:00"
}
```

---

### `GET /api/v1/catalog/products/{id}/images`
Lista solo las imágenes de un producto, ordenadas por `orden`.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/catalog/products/1/images
```

**Response 200:**
```json
[
  { "id": 1, "urlImagen": "https://cdn.example.com/collar-01.jpg", "orden": 1 },
  { "id": 2, "urlImagen": "https://cdn.example.com/collar-02.jpg", "orden": 2 }
]
```

---

### `POST /api/v1/catalog/products` — Rol: ADMIN

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Anillo de oro 18K",
    "descripcion": "Anillo solitario en oro amarillo 18 quilates",
    "precio": 450000,
    "categoriaId": 1,
    "materialId": 2
  }' \
  http://localhost:3000/api/v1/catalog/products
```

**Body:**
```json
{
  "nombre": "Anillo de oro 18K",
  "descripcion": "Anillo solitario en oro amarillo 18 quilates",
  "precio": 450000,
  "categoriaId": 1,
  "materialId": 2
}
```

> `categoriaId` y `materialId` son **requeridos** — el material no puede ser nulo.

**Response 201:**
```json
{
  "id": 2,
  "nombre": "Anillo de oro 18K",
  "descripcion": "Anillo solitario en oro amarillo 18 quilates",
  "precio": 450000.00,
  "stock": 0,
  "estado": true,
  "categoria": { "id": 1, "nombre": "Anillos" },
  "material": { "id": 2, "nombre": "Oro 18K" },
  "imagenes": [],
  "fechaCreacion": "2026-05-10T22:00:00"
}
```

---

### `PUT /api/v1/catalog/products/{id}` — Rol: ADMIN

Todos los campos son opcionales. Solo se actualizan los que se envían.

```bash
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"precio": 480000, "estado": true}' \
  http://localhost:3000/api/v1/catalog/products/2
```

---

### `DELETE /api/v1/catalog/products/{id}` — Rol: ADMIN

Soft delete — pone `estado: false`. No elimina el registro de la base de datos.

**Response 204:** sin body.

---

## Inventario — Stock

### `GET /api/v1/inventory/stock`
Stock de todos los productos activos, paginado.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/inventory/stock?page=0&size=20"
```

**Response 200:**
```json
{
  "content": [
    {
      "productoId": 1,
      "nombre": "Producto Demo",
      "cantidadDisponible": 50,
      "fechaCreacion": "2026-05-10T20:00:00"
    }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 1, "totalPages": 1 }
}
```

---

### `GET /api/v1/inventory/stock/{productId}`
Stock de un producto específico.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/inventory/stock/1
```

**Response 200:**
```json
{
  "productoId": 1,
  "nombre": "Producto Demo",
  "cantidadDisponible": 50,
  "fechaCreacion": "2026-05-10T20:00:00"
}
```

---

## Inventario — Movimientos

### `POST /api/v1/inventory/movements` — Rol: ADMIN o VENDEDOR

Registra una entrada, salida o ajuste de inventario.

El `tipoMovimientoId` corresponde a los IDs de la tabla `inventario.tipo_movimiento`:

| ID | Nombre | Efecto en stock |
|---|---|---|
| 1 | ENTRADA | `+cantidad` |
| 2 | SALIDA | `-cantidad` (falla si stock insuficiente) |
| 3 | AJUSTE | `+cantidad` (puede ser negativo en DB) |

```bash
# Registrar una entrada de 20 unidades
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "productoId": 1,
    "tipoMovimientoId": 1,
    "cantidad": 20,
    "referencia": "Reposición proveedor ABC"
  }' \
  http://localhost:3000/api/v1/inventory/movements
```

**Body:**
```json
{
  "productoId": 1,
  "tipoMovimientoId": 1,
  "cantidad": 20,
  "referencia": "Reposición proveedor ABC"
}
```

> `cantidad` siempre debe ser un entero positivo. Para SALIDA, el servicio almacena el valor negativo internamente.

**Response 201:**
```json
{
  "id": 1,
  "productoId": 1,
  "tipoMovimiento": { "id": 1, "nombre": "ENTRADA" },
  "cantidad": 20,
  "referencia": "Reposición proveedor ABC",
  "fechaMovimiento": "2026-05-10T22:15:00"
}
```

**Response 422 — Stock insuficiente:**
```json
{
  "status": 422,
  "error": "INSUFFICIENT_STOCK",
  "message": "Stock insuficiente para el producto '1'. Solicitado: 100, disponible: 50.",
  ...
}
```

---

### `GET /api/v1/inventory/movements` — Rol: ADMIN

Historial paginado de movimientos con filtros.

```bash
# Todos los movimientos
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/inventory/movements"

# Movimientos de un producto específico
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/inventory/movements?productoId=1"

# Movimientos en un rango de fechas
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/inventory/movements?fechaDesde=2026-05-01T00:00:00&fechaHasta=2026-05-31T23:59:59"
```

**Query params:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `productoId` | Integer | Filtrar por producto |
| `tipoMovimientoId` | Integer | Filtrar por tipo (1=ENTRADA, 2=SALIDA, 3=AJUSTE) |
| `fechaDesde` | ISO 8601 LocalDateTime | Desde esta fecha |
| `fechaHasta` | ISO 8601 LocalDateTime | Hasta esta fecha |
| `page` | Integer | Página (base 0) |
| `size` | Integer | Tamaño |

**Response 200:**
```json
{
  "content": [
    {
      "id": 1,
      "producto": { "id": 1, "nombre": "Producto Demo" },
      "tipoMovimiento": { "id": 1, "nombre": "ENTRADA" },
      "cantidad": 20,
      "referencia": "Reposición proveedor ABC",
      "fechaMovimiento": "2026-05-10T22:15:00"
    }
  ],
  "page": { "size": 20, "number": 0, "totalElements": 1, "totalPages": 1 }
}
```

> **Nota:** `cantidad` puede ser negativo en respuestas de historial. Un valor de `-5` indica una salida de 5 unidades.

---

## Tablas de referencia

### IDs de tipos de movimiento (seeded en DB)

| id | nombre | uso |
|---|---|---|
| 1 | ENTRADA | Ingreso de productos al inventario |
| 2 | SALIDA | Salida de productos del inventario |
| 3 | AJUSTE | Ajuste manual de inventario |

### IDs de categorías (datos iniciales)

| id | nombre |
|---|---|
| 1 | General |
| 2 | Anillos |
| 3 | Collares |
| 4 | Pulseras |

### IDs de materiales (datos iniciales)

| id | nombre |
|---|---|
| 1 | General |
| 2 | Oro 18K |
| 3 | Plata 925 |
| 4 | Acero Inoxidable |

---

## Códigos de error por endpoint

| Código | Error | Descripción |
|---|---|---|
| 401 | `UNAUTHORIZED` | Token ausente, expirado o inválido |
| 403 | `INSUFFICIENT_PERMISSIONS` | El rol del usuario no tiene acceso |
| 404 | `CATEGORY_NOT_FOUND` | Categoría no existe |
| 404 | `MATERIAL_NOT_FOUND` | Material no existe |
| 404 | `PRODUCT_NOT_FOUND` | Producto no existe |
| 409 | `CATEGORY_HAS_PRODUCTS` | No se puede eliminar categoría con productos |
| 409 | `MATERIAL_HAS_PRODUCTS` | No se puede eliminar material con productos |
| 422 | `INSUFFICIENT_STOCK` | Stock insuficiente para la salida |
| 422 | `INVALID_MOVEMENT_TYPE` | El tipo de movimiento no existe |
| 422 | `VALIDATION_ERROR` | Campos requeridos ausentes o inválidos |
| 422 | `VALIDATION_ERROR` | `fechaDesde` posterior a `fechaHasta` |
| 429 | `TOO_MANY_REQUESTS` | Rate limit excedido (ver header `Retry-After`) |
