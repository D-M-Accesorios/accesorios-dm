# HU-DEV-SALB_06 — Rate Limiting por IP y por usuario

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_06                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Media                                      |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002                                    |
| **Rama**           | `HU-DEV-SALB_06`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** sistema,
> **quiero** limitar la cantidad de peticiones por IP y por usuario autenticado,
> **para** prevenir abuso, ataques de fuerza bruta y saturación de los servicios internos.

---

## Criterios de Aceptación

- [ ] El límite general es de `RATE_LIMIT_MAX` peticiones por IP por `RATE_LIMIT_TTL` segundos (configurables por variable de entorno).
- [ ] El límite predeterminado es 100 peticiones/IP/minuto.
- [ ] Las rutas de autenticación (`/api/v1/auth/login`, `/api/v1/auth/register`) tienen un límite más estricto: 10 peticiones/IP/minuto.
- [ ] Al superar el límite se devuelve `429 RATE_LIMIT_EXCEEDED` con el formato de error estándar (ADR-009).
- [ ] La respuesta `429` incluye el header `Retry-After` con los segundos restantes hasta que se renueve la ventana.
- [ ] Los endpoints de health check (`/api/v1/health/**`) están excluidos del rate limiting.

---

## Notas Técnicas

- Usar `@nestjs/throttler` con `ThrottlerGuard` configurado globalmente.
- Aplicar `@Throttle({ default: { limit: 10, ttl: 60000 } })` específicamente en los endpoints de auth.
- La clave de rate limiting es la IP del cliente (`request.ip`). Para entornos detrás de un proxy/load balancer, usar `request.headers['x-forwarded-for']`.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que después de 10 intentos de login rápidos se recibe `429`.
- [ ] Verificado que el header `Retry-After` está presente en la respuesta `429`.
- [ ] PR mergeado a `develop`.
