# ADR-009: Formato Estándar de Errores HTTP

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-009                              |
| **Título**  | Formato Estándar de Errores HTTP     |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema está compuesto por múltiples microservicios construidos con stacks
tecnológicos distintos: NestJS (TypeScript) y Spring Boot (Java). Cada framework
tiene su propio formato de error por defecto:

- **NestJS** retorna errores en formato `{ statusCode, message, error }`.
- **Spring Boot** retorna errores en formato `{ timestamp, status, error, path }`.

Sin un estándar unificado, el frontend Angular debe manejar múltiples formatos
de error dependiendo del servicio que responde, lo que genera:

- Código de manejo de errores duplicado y frágil en el cliente.
- Dificultad para mostrar mensajes de error consistentes al usuario.
- Complejidad en el debugging y en los logs de producción.
- Imposibilidad de generalizar interceptores HTTP en Angular.

Se requiere un contrato de error único que todos los servicios respeten y que
el API Gateway normalice antes de devolver al cliente.

---

## 2. Decisión

**Todos los servicios del sistema responden errores en un formato JSON único y
estandarizado. El API Gateway es responsable de normalizar cualquier error que
no cumpla el formato antes de entregarlo al cliente.**

---

## 3. Formato Estándar de Error

### 3.1 Estructura de respuesta de error

```json
{
  "status": 404,
  "error": "NOT_FOUND",
  "message": "El producto con ID 'abc-123' no fue encontrado.",
  "path": "/api/v1/inventory/products/abc-123",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### 3.2 Descripción de campos

| Campo       | Tipo            | Requerido | Descripción                                                       |
|-------------|-----------------|-----------|-------------------------------------------------------------------|
| `status`    | `integer`       | Sí        | Código de estado HTTP (400, 401, 403, 404, 409, 422, 500…)       |
| `error`     | `string`        | Sí        | Código de error legible en UPPER_SNAKE_CASE (ver catálogo)        |
| `message`   | `string`        | Sí        | Mensaje descriptivo en lenguaje natural — orientado al desarrollador |
| `path`      | `string`        | Sí        | Ruta HTTP donde ocurrió el error                                  |
| `timestamp` | `string (ISO8601)`| Sí      | Fecha y hora del error en UTC                                     |
| `traceId`   | `string (UUID)` | Sí        | ID de trazabilidad de la petición — propagado desde el Gateway    |
| `details`   | `array`         | No        | Lista de errores de validación específicos (ver sección 3.3)      |

### 3.3 Estructura de `details` (para errores de validación)

Cuando el error involucra múltiples campos inválidos (ej. validación de un formulario),
el campo `details` contiene la lista de violaciones:

```json
{
  "status": 422,
  "error": "VALIDATION_ERROR",
  "message": "La solicitud contiene campos inválidos.",
  "path": "/api/v1/inventory/products",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": [
    {
      "field": "precio",
      "rejectedValue": -500,
      "message": "El precio debe ser mayor a cero."
    },
    {
      "field": "nombre",
      "rejectedValue": "",
      "message": "El nombre del producto no puede estar vacío."
    }
  ]
}
```

| Campo en `details` | Tipo     | Descripción                                        |
|--------------------|----------|----------------------------------------------------|
| `field`            | `string` | Nombre del campo que falló la validación           |
| `rejectedValue`    | `any`    | Valor recibido que fue rechazado                   |
| `message`          | `string` | Descripción específica del problema de validación  |

---

## 4. Catálogo de Códigos de Error

### 4.1 Errores de cliente (4xx)

| HTTP | `error` code            | Cuándo usar                                                   |
|------|-------------------------|---------------------------------------------------------------|
| 400  | `BAD_REQUEST`           | Request malformado, parámetros inválidos no de validación     |
| 401  | `UNAUTHORIZED`          | Token ausente, inválido o expirado                            |
| 403  | `FORBIDDEN`             | Token válido pero sin permisos para la operación              |
| 404  | `NOT_FOUND`             | Recurso no encontrado                                         |
| 405  | `METHOD_NOT_ALLOWED`    | Método HTTP no soportado en esa ruta                          |
| 409  | `CONFLICT`              | Conflicto de estado: recurso ya existe, versión desactualizada|
| 422  | `VALIDATION_ERROR`      | Campos del body no pasan las reglas de validación de dominio  |
| 429  | `RATE_LIMIT_EXCEEDED`   | Límite de peticiones superado                                 |

### 4.2 Errores de servidor (5xx)

| HTTP | `error` code              | Cuándo usar                                                 |
|------|---------------------------|-------------------------------------------------------------|
| 500  | `INTERNAL_SERVER_ERROR`   | Error no controlado en el servicio                          |
| 502  | `BAD_GATEWAY`             | El Gateway no recibió respuesta válida del servicio interno |
| 503  | `SERVICE_UNAVAILABLE`     | Servicio interno no disponible o en mantenimiento           |
| 504  | `GATEWAY_TIMEOUT`         | El servicio interno no respondió dentro del tiempo límite   |

### 4.3 Errores de dominio específicos del sistema

Estos códigos extienden el catálogo base con errores propios del negocio:

| HTTP | `error` code                    | Dominio     | Descripción                              |
|------|---------------------------------|-------------|------------------------------------------|
| 401  | `TOKEN_EXPIRED`                 | Security    | El access token ha expirado              |
| 401  | `REFRESH_TOKEN_EXPIRED`         | Security    | El refresh token ha expirado             |
| 401  | `INVALID_CREDENTIALS`           | Security    | Email o contraseña incorrectos           |
| 403  | `INSUFFICIENT_PERMISSIONS`      | Security    | No tiene el permiso específico requerido |
| 409  | `USER_ALREADY_EXISTS`           | Security    | El email ya está registrado              |
| 404  | `PRODUCT_NOT_FOUND`             | Inventory   | Producto no encontrado por ID            |
| 404  | `CATEGORY_NOT_FOUND`            | Inventory   | Categoría no encontrada                  |
| 409  | `PRODUCT_ALREADY_EXISTS`        | Inventory   | Producto con ese SKU ya existe           |
| 422  | `INSUFFICIENT_STOCK`            | Inventory   | Stock insuficiente para el movimiento    |
| 422  | `INVALID_MOVEMENT_TYPE`         | Inventory   | Tipo de movimiento no válido             |

> Este catálogo es extensible. Cada servicio puede agregar sus propios códigos
> de dominio siguiendo la convención UPPER_SNAKE_CASE y documentándolos aquí.

---

## 5. Responsabilidades por Componente

### API Gateway (NestJS)

- Implementa un `ExceptionFilter` global que intercepta todos los errores.
- Normaliza errores de servicios internos que no cumplan el formato estándar.
- Agrega el `traceId` a todas las respuestas de error (generado al inicio del request).
- Transforma errores de infraestructura (timeout, conexión rechazada) a `502`/`504`
  con el formato estándar.
- Nunca expone stack traces, nombres de clases internas ni mensajes de excepción
  crudos al cliente.

### Inventory Service (Spring Boot)

- Implementa un `@ControllerAdvice` global con `@ExceptionHandler` para cada tipo
  de excepción de dominio.
- Responde directamente en el formato estándar (no usa el formato por defecto de
  Spring Boot).
- Define excepciones de dominio propias (`ProductNotFoundException`,
  `InsufficientStockException`, etc.) mapeadas a los códigos del catálogo.

### Security Service (Spring Boot)

- Mismo patrón que Inventory Service.
- Define excepciones propias para errores de autenticación y autorización.

---

## 6. Propagación del TraceId

El `traceId` es un UUID generado por el API Gateway al recibir cada petición.
Se propaga a todos los servicios internos mediante el header `X-Trace-Id`.

```
Cliente → [genera traceId] → Gateway → [header X-Trace-Id] → Servicio Interno
                                              ↑
                              Incluido en todos los logs y respuestas de error
```

Esto permite correlacionar logs de múltiples servicios para una misma petición
de usuario. Es la base mínima de trazabilidad distribuida del sistema.

---

## 7. Ejemplos por Escenario

### Token expirado (401)
```json
{
  "status": 401,
  "error": "TOKEN_EXPIRED",
  "message": "El token de acceso ha expirado. Por favor, renueve su sesión.",
  "path": "/api/v1/inventory/products",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### Sin permisos (403)
```json
{
  "status": 403,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "No tiene permisos para realizar esta operación.",
  "path": "/api/v1/inventory/products",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### Recurso no encontrado (404)
```json
{
  "status": 404,
  "error": "PRODUCT_NOT_FOUND",
  "message": "El producto con ID 'abc-123' no fue encontrado.",
  "path": "/api/v1/inventory/products/abc-123",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### Error de validación (422)
```json
{
  "status": 422,
  "error": "VALIDATION_ERROR",
  "message": "La solicitud contiene campos inválidos.",
  "path": "/api/v1/inventory/products",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": [
    {
      "field": "precio",
      "rejectedValue": -500,
      "message": "El precio debe ser mayor a cero."
    }
  ]
}
```

### Servicio interno caído (502)
```json
{
  "status": 502,
  "error": "BAD_GATEWAY",
  "message": "El servicio no está disponible temporalmente. Intente de nuevo.",
  "path": "/api/v1/inventory/products",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

---

## 8. Reglas Derivadas

| # | Regla                                                                                              | Alcance            |
|---|----------------------------------------------------------------------------------------------------|--------------------|
| R1 | Todos los servicios responden errores usando el formato estándar definido en este ADR             | Código, todos svcs |
| R2 | El API Gateway normaliza errores que no cumplan el formato antes de devolver al cliente           | Gateway            |
| R3 | Los stack traces y mensajes de excepción internos nunca se exponen en la respuesta al cliente     | Seguridad, código  |
| R4 | Todo servicio debe tener un handler global de excepciones no controladas                          | Código, todos svcs |
| R5 | El campo `traceId` es obligatorio en toda respuesta de error                                      | Gateway, código    |
| R6 | Los códigos de error de dominio nuevos deben registrarse en el catálogo de este ADR              | Proceso, docs      |
| R7 | El frontend Angular implementa un único interceptor HTTP para manejar el formato estándar        | Frontend           |

---

## 9. Referencias

- RFC 7807 — Problem Details for HTTP APIs (inspiración del formato)
- NestJS — Exception Filters
- Spring Boot — `@ControllerAdvice` y `@ExceptionHandler`
- ADR-002: API Gateway Custom con NestJS (normalización de errores en Gateway)
- ADR-008: Estrategia de Versionamiento de APIs
