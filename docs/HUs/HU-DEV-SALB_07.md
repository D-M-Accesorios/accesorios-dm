# HU-DEV-SALB_07 — Proxy routing hacia Security Service

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_07                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Crítica                                    |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-003, ADR-006, ADR-008         |
| **Rama**           | `HU-DEV-SALB_07`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** cliente Angular,
> **quiero** que las rutas de autenticación (`/api/v1/auth/**`) sean atendidas
> por el Security Service a través del Gateway,
> **para** poder autenticarme, registrarme y gestionar mi sesión sin conocer
> la dirección interna del Security Service.

---

## Criterios de Aceptación

- [ ] Todas las rutas bajo `/api/v1/auth/**` son redirigidas al Security Service (`SECURITY_SERVICE_URL`).
- [ ] Las rutas de auth son públicas: el Auth Guard (HU-DEV-SALB_05) no se aplica en este grupo.
- [ ] El timeout de conexión es de 3 segundos y el de petición de 10 segundos.
- [ ] Si el Security Service no responde en tiempo → `504 GATEWAY_TIMEOUT` con formato estándar.
- [ ] Si el Security Service no está disponible → `502 BAD_GATEWAY` con formato estándar.
- [ ] El header `X-Trace-Id` es propagado en cada petición proxeada.
- [ ] Los headers de respuesta del Security Service (incluidas las cookies `httpOnly`) se preservan y retransmiten al cliente sin modificación.
- [ ] Las rutas de gestión de usuarios y roles (`/api/v1/users/**`, `/api/v1/roles/**`) también son proxeadas al Security Service y requieren autenticación.

---

## Mapa de Rutas Proxeadas

| Ruta pública (Gateway)              | Destino interno              | Auth requerida |
|-------------------------------------|------------------------------|----------------|
| `POST /api/v1/auth/login`           | Security Service             | No             |
| `POST /api/v1/auth/register`        | Security Service             | No             |
| `POST /api/v1/auth/refresh`         | Security Service             | No (cookie)    |
| `POST /api/v1/auth/logout`          | Security Service             | Sí             |
| `GET  /api/v1/auth/me`              | Security Service             | Sí             |
| `PUT  /api/v1/auth/me/password`     | Security Service             | Sí             |
| `GET  /api/v1/users/**`             | Security Service             | Sí (ADMIN)     |
| `GET  /api/v1/roles/**`             | Security Service             | Sí (ADMIN)     |

---

## Notas Técnicas

- Usar `http-proxy-middleware` o el módulo `HttpService` de NestJS para el proxy.
- Las cookies `Set-Cookie` del Security Service deben llegar al cliente intactas. Evitar que el Gateway las consuma o modifique.
- No re-emitir ni transformar el body de respuesta del Security Service salvo para normalizar errores.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |
| Bloqueada por | HU-DEV-SALB_04 | Necesita propagación de `traceId` |
| Bloqueada por | HU-DEV-SALB_05 | Necesita Auth Guard configurado para rutas protegidas |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que `POST /api/v1/auth/login` llega al Security Service y retorna tokens.
- [ ] Verificado que la cookie `httpOnly` del refresh token llega al browser.
- [ ] Verificado que timeout genera `504` con formato estándar.
- [ ] PR mergeado a `develop`.
