# HU-DEV-SALB_04 — Logging centralizado y propagación de TraceId

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_04                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Alta                                       |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-009                           |
| **Rama**           | `HU-DEV-SALB_04`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** equipo de desarrollo y operaciones,
> **quiero** que el Gateway registre cada petición con un ID de traza único y lo
> propague a los servicios internos,
> **para** poder correlacionar logs entre múltiples servicios ante un error o
> incidente en producción.

---

## Criterios de Aceptación

- [ ] Cada petición entrante al Gateway genera un `traceId` (UUID v4) único al inicio del pipeline.
- [ ] Si la petición ya incluye el header `X-Trace-Id` (ej. desde herramienta de testing), se reutiliza ese valor.
- [ ] El `traceId` se propaga a los servicios internos en el header `X-Trace-Id` de cada proxy.
- [ ] El `traceId` se incluye en el header de respuesta al cliente: `X-Trace-Id`.
- [ ] Cada petición genera al menos dos entradas de log:
  - **Entrada**: método, ruta, IP de origen, `traceId`.
  - **Salida**: método, ruta, status HTTP de respuesta, tiempo de respuesta en ms, `traceId`.
- [ ] Los logs de error incluyen el `traceId`, el status y el mensaje de error.
- [ ] El formato de log es JSON estructurado (no texto plano) para facilitar su ingesta por herramientas de observabilidad.
- [ ] El nivel de log es configurable por variable de entorno `LOG_LEVEL` (debug, info, warn, error).

---

## Ejemplo de Log Estructurado

```json
{
  "level": "info",
  "timestamp": "2026-05-10T14:32:00.123Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "method": "GET",
  "path": "/api/v1/catalog/products",
  "statusCode": 200,
  "responseTimeMs": 47,
  "userAgent": "Mozilla/5.0...",
  "ip": "192.168.1.10"
}
```

---

## Notas Técnicas

- Implementar como `NestInterceptor` global registrado en `app.useGlobalInterceptors(...)`.
- Generar el `traceId` con `crypto.randomUUID()` (nativo en Node.js 18+, sin dependencias).
- Almacenar el `traceId` en el objeto `request` para que esté disponible en el `ExceptionFilter` (HU-DEV-SALB_03) y en los handlers del proxy.
- Usar `@nestjs/common` Logger o integrar `pino` / `winston` para logs estructurados JSON.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |
| Requerida por | HU-DEV-SALB_03 | El filtro de errores necesita el `traceId` del contexto |
| Requerida por | HU-DEV-SALB_07, 08 | El proxy necesita propagar el `traceId` a servicios internos |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que el `traceId` aparece en los logs de entrada y salida de una petición.
- [ ] Verificado que el `traceId` llega al servicio interno en el header `X-Trace-Id`.
- [ ] PR mergeado a `develop`.
