# HU-DEV-SALB_09 — Health Check del Gateway y servicios internos

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_09                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Media                                      |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002                                    |
| **Rama**           | `HU-DEV-SALB_09`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** equipo de operaciones,
> **quiero** endpoints de health check que indiquen el estado del Gateway y de
> los servicios internos,
> **para** monitorear la disponibilidad del sistema y detectar caídas sin
> autenticación.

---

## Criterios de Aceptación

- [ ] `GET /api/v1/health` devuelve `200 OK` con el estado del Gateway propio.
- [ ] `GET /api/v1/health/services` devuelve el estado de cada servicio interno (Security Service, Inventory Service).
- [ ] Ambos endpoints son públicos (sin Auth Guard, sin rate limiting).
- [ ] Si un servicio interno no responde, su estado es `DOWN` pero el endpoint devuelve `200` con el detalle (no falla el Gateway).
- [ ] El tiempo de respuesta de cada servicio interno se incluye en la respuesta.

---

## Formato de Respuesta

**`GET /api/v1/health`**
```json
{
  "status": "UP",
  "timestamp": "2026-05-10T14:32:00.000Z"
}
```

**`GET /api/v1/health/services`**
```json
{
  "status": "DEGRADED",
  "timestamp": "2026-05-10T14:32:00.000Z",
  "services": {
    "security-service": { "status": "UP", "responseTimeMs": 12 },
    "inventory-service": { "status": "DOWN", "responseTimeMs": null }
  }
}
```

Estado global: `UP` si todos están UP, `DEGRADED` si alguno está DOWN, `DOWN` si todos están DOWN.

---

## Notas Técnicas

- Usar `@nestjs/terminus` para los health checks.
- Los health checks de servicios internos llaman al endpoint `/api/v1/health` de cada servicio con timeout de 2 segundos.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que `GET /api/v1/health` responde `200` sin autenticación.
- [ ] Verificado que cuando Inventory Service está caído, `health/services` devuelve `DEGRADED`.
- [ ] PR mergeado a `develop`.
