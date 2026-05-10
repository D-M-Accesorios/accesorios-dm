# HU-DEV-SALB_03 — Filtro global de errores y formato estándar

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_03                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Crítica                                    |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-009                           |
| **Rama**           | `HU-DEV-SALB_03`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** cliente del API (Angular o Mobile),
> **quiero** recibir todos los errores en un formato JSON consistente sin importar
> qué servicio los origine,
> **para** poder manejarlos de forma predecible con un único interceptor HTTP en el
> frontend sin lógica especial por servicio.

---

## Criterios de Aceptación

- [ ] Existe un `HttpExceptionFilter` global registrado en el Gateway que intercepta todas las excepciones.
- [ ] Todo error devuelto al cliente cumple exactamente el esquema de ADR-009:
  ```json
  {
    "status": 404,
    "error": "NOT_FOUND",
    "message": "...",
    "path": "/api/v1/...",
    "timestamp": "2026-05-10T14:32:00.000Z",
    "traceId": "uuid-v4",
    "details": []
  }
  ```
- [ ] Los errores de servicios internos que lleguen en formato distinto (Spring Boot default) son normalizados.
- [ ] Los errores `502 Bad Gateway` y `504 Gateway Timeout` son mapeados al formato estándar con los mensajes del catálogo (ADR-009).
- [ ] Los stack traces internos y nombres de clases Java nunca aparecen en la respuesta al cliente.
- [ ] El campo `traceId` siempre está presente en errores (leído desde el contexto de la petición — ver HU-DEV-SALB_04).
- [ ] El campo `path` refleja la ruta pública del Gateway, no la ruta interna del servicio proxeado.
- [ ] Los errores de validación (`422`) incluyen el array `details` correctamente poblado.

---

## Formato de Normalización de Errores Externos

Cuando un servicio interno (Spring Boot) responde con su formato por defecto, el Gateway lo normaliza:

**Entrada (error de Spring Boot):**
```json
{
  "timestamp": "2026-05-10T14:32:00.000+00:00",
  "status": 404,
  "error": "Not Found",
  "path": "/api/v1/products/123"
}
```

**Salida normalizada al cliente:**
```json
{
  "status": 404,
  "error": "NOT_FOUND",
  "message": "El recurso solicitado no fue encontrado.",
  "path": "/api/v1/catalog/products/123",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

---

## Notas Técnicas

- Implementar como `@Catch()` global registrado en `app.useGlobalFilters(...)` en `main.ts`.
- La normalización de errores de servicios proxeados ocurre en el handler del proxy (intercepta la respuesta downstream antes de enviarla al cliente).
- Para leer el `traceId` desde el contexto HTTP usar `request.headers['x-trace-id']`.
- El campo `error` siempre en `UPPER_SNAKE_CASE`. Mapear los status HTTP a los códigos del catálogo ADR-009.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |
| Relacionada con | HU-DEV-SALB_04 | Necesita el `traceId` generado por el interceptor de logging |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que un error 404 de servicio interno llega normalizado al cliente.
- [ ] Verificado que ningún stack trace aparece en respuestas de error.
- [ ] PR mergeado a `develop`.
