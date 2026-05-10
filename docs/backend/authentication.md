# Autenticación — Guía para el frontend

## Cómo funciona el flujo JWT

```
Frontend → API Gateway (valida JWT) → Inventory Service
                    ↓
             inyecta headers:
             X-User-Id, X-User-Roles, X-Username
```

El **API Gateway** intercepta todos los requests, valida el token JWT con RS256 y, si es válido, inyecta la identidad del usuario como headers internos antes de redirigir al microservicio. El Inventory Service **no valida tokens** — confía en los headers del gateway.

---

## Headers que inyecta el gateway

Estos headers son añadidos automáticamente por el gateway a cada request interno:

| Header | Tipo | Ejemplo |
|---|---|---|
| `X-User-Id` | String (UUID) | `"550e8400-e29b-41d4-a716-446655440000"` |
| `X-Username` | String | `"admin@accesoriosdm.com"` |
| `X-User-Roles` | String (coma-separado) | `"ADMIN,VENDEDOR"` |

---

## Roles y permisos

| Rol | Descripción | Permisos en el backend actual |
|---|---|---|
| `ADMIN` | Administrador | Acceso completo — CRUD catálogo + historial movimientos |
| `VENDEDOR` | Vendedor | Registrar movimientos de inventario |
| `BODEGUERO` | Encargado de bodega | Acceso de lectura (mismo que usuario autenticado) |
| `CLIENTE` | Cliente del e-commerce | Acceso de lectura al catálogo |

---

## Formato del token JWT

```json
{
  "sub": "dev-admin",
  "username": "admin",
  "roles": ["ADMIN"],
  "iss": "accesorios-dm",
  "iat": 1746912000,
  "exp": 1747516800
}
```

El token va en el header `Authorization`:
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Tokens de desarrollo (sin servicio de seguridad)

Mientras el servicio de seguridad está en desarrollo, usa el generador incluido en `dm-deployment`:

```bash
cd dm-deployment

# ADMIN — acceso total
node scripts/generate-dev-token.js admin ADMIN

# VENDEDOR — solo puede registrar movimientos
node scripts/generate-dev-token.js vendedor VENDEDOR

# BODEGUERO
node scripts/generate-dev-token.js bodeguero BODEGUERO
```

Los tokens son válidos por **7 días** y están firmados con la clave privada de desarrollo (`scripts/dev-private.pem`). El gateway acepta estos tokens porque tiene la clave pública correspondiente en `JWT_PUBLIC_KEY` del `.env`.

---

## Usar el token en el frontend (Angular)

### Interceptor HTTP recomendado

```typescript
// auth.interceptor.ts
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private authService: AuthService) {}

  intercept(req: HttpCloneOptions, next: HttpHandler): Observable<HttpEvent<any>> {
    const token = this.authService.getToken();
    if (token) {
      req = req.clone({
        setHeaders: { Authorization: `Bearer ${token}` }
      });
    }
    return next.handle(req);
  }
}
```

### Para desarrollo sin login real

```typescript
// environment.ts — token temporal para dev
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000',
  devToken: 'PEGAR_AQUÍ_EL_TOKEN_GENERADO_CON_generate-dev-token.js'
};
```

```typescript
// en auth.service.ts para dev
getToken(): string | null {
  if (!environment.production && environment.devToken) {
    return environment.devToken;  // usa token de dev mientras no hay login
  }
  return localStorage.getItem('access_token');
}
```

---

## Respuestas de error de autenticación

### 401 — Token ausente o inválido

```json
{
  "status": 401,
  "error": "UNAUTHORIZED",
  "message": "Token de acceso requerido.",
  "path": "/api/v1/catalog/products",
  "timestamp": "2026-05-10T22:00:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### 403 — Sin permisos para la operación

```json
{
  "status": 403,
  "error": "INSUFFICIENT_PERMISSIONS",
  "message": "Se requiere el rol ADMIN para esta operación.",
  "path": "/api/v1/catalog/categories",
  "timestamp": "2026-05-10T22:00:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

### 429 — Rate limit excedido

```json
{
  "status": 429,
  "error": "TOO_MANY_REQUESTS",
  "message": "Has excedido el límite de peticiones. Intenta de nuevo en 60 segundos.",
  "path": "/api/v1/catalog/products",
  "timestamp": "2026-05-10T22:00:00.000Z",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": []
}
```

El header `Retry-After` indica cuántos segundos esperar.

---

## Cuando el servicio de seguridad esté listo

El flujo de login será:

```
POST /api/v1/auth/login
Body: { "email": "...", "password": "..." }

Response:
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "expiresIn": 3600
}
```

El frontend guarda el `accessToken` y lo envía en `Authorization: Bearer <token>` en cada request. No hay ningún cambio en cómo el gateway o el inventory service manejan los tokens — el único cambio es que el token vendrá del servicio de seguridad real en lugar del script generador.
