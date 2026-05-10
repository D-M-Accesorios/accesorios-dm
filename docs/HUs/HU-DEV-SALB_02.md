# HU-DEV-SALB_02 — Configuración de CORS y headers de seguridad HTTP

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_02                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Alta                                       |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002                                    |
| **Rama**           | `HU-DEV-SALB_02`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** frontend Angular,
> **quiero** que el Gateway configure correctamente los headers CORS y de seguridad HTTP,
> **para** poder consumir la API desde el browser sin errores de política de origen
> cruzado y con las protecciones de seguridad adecuadas.

---

## Criterios de Aceptación

- [ ] Solo los orígenes definidos en `ALLOWED_ORIGINS` (variable de entorno, lista separada por comas) son aceptados.
- [ ] En desarrollo, `http://localhost:4200` está en la lista de orígenes permitidos.
- [ ] Los métodos HTTP permitidos están configurados explícitamente: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`.
- [ ] Los headers permitidos en peticiones incluyen: `Authorization`, `Content-Type`, `X-Trace-Id`.
- [ ] Las credenciales (`credentials: true`) están habilitadas para permitir el envío de cookies `httpOnly` (refresh token).
- [ ] Una petición `OPTIONS` de preflight recibe `204 No Content` con los headers CORS correctos.
- [ ] Una petición desde un origen no autorizado recibe `403` con el formato de error estándar (ADR-009).
- [ ] Los siguientes headers de seguridad están presentes en toda respuesta:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (en producción)

---

## Notas Técnicas

- Usar el módulo nativo de CORS de NestJS (`app.enableCors(...)`) en `main.ts`.
- Los headers de seguridad se configuran mediante un middleware global o con `helmet` (`@fastify/helmet` o `helmet` según el adaptador HTTP).
- `ALLOWED_ORIGINS` debe parsearse como array al arrancar: `process.env.ALLOWED_ORIGINS.split(',')`.
- No hardcodear ningún origen en el código; siempre leer de la variable de entorno.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base configurado |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado manualmente desde Angular en localhost que no hay errores CORS.
- [ ] Verificado que una petición desde origen no permitido es rechazada.
- [ ] PR mergeado a `develop`.
