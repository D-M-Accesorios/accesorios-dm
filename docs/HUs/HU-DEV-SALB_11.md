# HU-DEV-SALB_11 — Manejador global de excepciones (@ControllerAdvice)

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_11                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Crítica                                        |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-009                                        |
| **Rama**           | `HU-DEV-SALB_11`                               |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** cliente del API,
> **quiero** que el Inventory Service devuelva todos sus errores en el formato
> estándar del sistema,
> **para** que el Gateway y el frontend los procesen de forma consistente sin
> lógica especial por servicio.

---

## Criterios de Aceptación

- [ ] Existe un `@ControllerAdvice` global (`GlobalExceptionHandler`) que intercepta todas las excepciones del servicio.
- [ ] Las excepciones de dominio propias se mapean a los códigos del catálogo de ADR-009:

| Excepción                     | HTTP | Código de error          |
|-------------------------------|------|--------------------------|
| `ProductNotFoundException`    | 404  | `PRODUCT_NOT_FOUND`      |
| `CategoryNotFoundException`   | 404  | `CATEGORY_NOT_FOUND`     |
| `MaterialNotFoundException`   | 404  | `MATERIAL_NOT_FOUND`     |
| `InsufficientStockException`  | 422  | `INSUFFICIENT_STOCK`     |
| `InvalidMovementTypeException`| 422  | `INVALID_MOVEMENT_TYPE`  |
| `ProductAlreadyExistsException`| 409 | `PRODUCT_ALREADY_EXISTS` |

- [ ] Las excepciones de validación de Bean Validation (`MethodArgumentNotValidException`) se transforman en `422 VALIDATION_ERROR` con el array `details` poblado con campo, valor rechazado y mensaje.
- [ ] Las excepciones no controladas (`Exception`) responden `500 INTERNAL_SERVER_ERROR` sin exponer stack trace.
- [ ] El campo `traceId` se lee del header `X-Trace-Id` (inyectado por el Gateway) y se incluye en todas las respuestas de error.
- [ ] El campo `path` refleja la ruta del request actual.
- [ ] Ninguna respuesta de error expone información interna del servidor (nombres de clase, queries SQL, stack traces).

---

## Formato de Respuesta de Error

Todas las respuestas de error del servicio deben cumplir el contrato de ADR-009:

```json
{
  "status": 404,
  "error": "PRODUCT_NOT_FOUND",
  "message": "El producto con ID 'abc-123' no fue encontrado.",
  "path": "/api/v1/catalog/products/abc-123",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

---

## Notas Técnicas

- El `traceId` se lee con `request.getHeader("X-Trace-Id")`. Inyectar `HttpServletRequest` en el handler.
- Usar `@ExceptionHandler` individual para cada excepción de dominio más un `@ExceptionHandler(Exception.class)` como fallback.
- El `timestamp` debe ser ISO 8601 UTC: `ZonedDateTime.now(ZoneOffset.UTC).toString()`.
- Para `MethodArgumentNotValidException`, iterar `ex.getBindingResult().getFieldErrors()` para construir el array `details`.
- Registrar las excepciones no controladas con nivel `ERROR` en el log antes de responder `500`.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_10 | Requiere proyecto base |
| Requerida por | Todas las HUs de endpoints | Toda HU con endpoints asume que este handler existe |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que un producto inexistente devuelve `404 PRODUCT_NOT_FOUND` con formato estándar.
- [ ] Verificado que campos inválidos devuelven `422 VALIDATION_ERROR` con `details` poblados.
- [ ] Verificado que ningún stack trace aparece en respuestas de error.
- [ ] Verificado que el `traceId` del header está presente en la respuesta de error.
- [ ] PR mergeado a `develop`.
