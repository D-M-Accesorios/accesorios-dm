# HU-DEV-SALB_05 — Auth Guard con validación JWT RS256

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_05                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Crítica                                    |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-003                           |
| **Rama**           | `HU-DEV-SALB_05`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** sistema,
> **quiero** que el Gateway valide el JWT de cada petición autenticada usando la
> clave pública RSA sin llamar al Security Service,
> **para** garantizar que solo usuarios autenticados acceden a recursos protegidos
> con mínima latencia adicional.

---

## Criterios de Aceptación

- [ ] El `JwtAuthGuard` valida la firma RS256 del token usando la clave pública RSA leída de `JWT_PUBLIC_KEY` (variable de entorno).
- [ ] El Guard verifica la expiración del token mediante el claim `exp`.
- [ ] El Guard verifica que el emisor sea el esperado (`iss` = `accesorios-dm-security-service`).
- [ ] El Guard verifica que el `jti` del token no esté en la blacklist activa (tabla o caché).
- [ ] Si el token es válido, extrae los claims y los inyecta como headers internos:
  - `X-User-Id` ← `sub`
  - `X-User-Email` ← `email`
  - `X-User-Roles` ← `roles` (serializado como JSON o CSV)
- [ ] Si el token está **ausente** → `401 UNAUTHORIZED`.
- [ ] Si el token es **inválido** (firma incorrecta) → `401 UNAUTHORIZED`.
- [ ] Si el token está **expirado** → `401 TOKEN_EXPIRED`.
- [ ] Si el `jti` está en la **blacklist** → `401 UNAUTHORIZED`.
- [ ] Las rutas decoradas con `@Public()` (o equivalente) omiten el Guard completamente.
- [ ] Las rutas `/api/v1/auth/**` y `/api/v1/health/**` son públicas por defecto.
- [ ] La validación del token es una operación local (criptográfica), sin llamadas HTTP al Security Service.

---

## Flujo de Validación

```
Request entrante
      │
      ▼
¿Ruta pública? ──── Sí ──→ Continúa sin validación
      │
      No
      │
      ▼
¿Header Authorization: Bearer <token> presente?
      │ No → 401 UNAUTHORIZED
      │
      Sí
      ▼
¿Firma RS256 válida con clave pública?
      │ No → 401 UNAUTHORIZED
      │
      Sí
      ▼
¿Token expirado (exp)?
      │ Sí → 401 TOKEN_EXPIRED
      │
      No
      ▼
¿jti en blacklist?
      │ Sí → 401 UNAUTHORIZED
      │
      No
      ▼
Extraer claims → inyectar headers X-User-*
      │
      ▼
Continúa al handler / proxy
```

---

## Notas Técnicas

- Usar `@nestjs/passport` + `passport-jwt` con estrategia RS256 y clave pública PEM.
- La clave pública RSA en `JWT_PUBLIC_KEY` debe estar en formato PEM con `\n` escapados como `\\n` en la variable de entorno, o cargarse desde archivo.
- El decorador `@Public()` se implementa con `SetMetadata('isPublic', true)` y el Guard lo detecta con `Reflector`.
- La blacklist en Fase 1 puede ser una tabla `token_blacklist` en el schema `security` consultada por el Gateway vía HTTP al Security Service (solo al detectar un jti, no en cada request normal).
- En Fase 2 se evalúa Redis para la blacklist si el volumen lo justifica.

---

## Dependencias

| Tipo | HU | Descripción |
|---|---|---|
| Bloqueada por | HU-DEV-SALB_01 | Requiere proyecto base |
| Relacionada con | HU-DEV-SALB_04 | Necesita `traceId` disponible en el contexto |
| Requerida por | HU-DEV-SALB_07 | Proxy de Security Service usa rutas públicas |
| Requerida por | HU-DEV-SALB_08 | Proxy de Inventory Service requiere autenticación |

---

## Definición de Done

- [ ] Código revisado y aprobado.
- [ ] Verificado que una petición sin token recibe `401`.
- [ ] Verificado que una petición con token expirado recibe `401 TOKEN_EXPIRED`.
- [ ] Verificado que una petición con token válido pasa y los headers `X-User-*` llegan al servicio interno.
- [ ] Verificado que las rutas `/api/v1/auth/**` son accesibles sin token.
- [ ] PR mergeado a `develop`.
