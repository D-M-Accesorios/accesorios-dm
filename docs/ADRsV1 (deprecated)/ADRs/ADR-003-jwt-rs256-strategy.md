# ADR-003: Estrategia JWT con Firma Asimétrica RS256

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-003                              |
| **Título**  | Estrategia JWT con Firma Asimétrica RS256 |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema Accesorios DM requiere una estrategia de autenticación y autorización que
funcione correctamente en una arquitectura distribuida de microservicios, donde múltiples
servicios independientes (API Gateway, Inventory Service, Security Service) necesitan
verificar la identidad y los permisos de los usuarios que realizan peticiones.

Los requisitos que debe cumplir la estrategia de autenticación son:

- **Sin estado (stateless)**: los servicios no deben almacenar sesiones en memoria.
  Esto es fundamental para la escalabilidad horizontal.
- **Verificación descentralizada**: el API Gateway debe poder validar la autenticidad
  de un token sin realizar una llamada HTTP al Security Service en cada petición.
  Una llamada adicional por request multiplica la latencia y crea una dependencia
  crítica en el camino caliente.
- **Propagación de identidad**: los servicios internos deben recibir la identidad
  del usuario autenticado de forma segura y confiable.
- **Soporte de roles y permisos**: el token debe transportar información de
  autorización suficiente para que el Gateway y los servicios apliquen control
  de acceso.
- **Revocación controlada**: debe existir un mecanismo para invalidar tokens
  comprometidos antes de su expiración natural.
- **Seguridad ante compromiso de un servicio**: si un servicio interno es
  comprometido, no debe poder forjar tokens válidos.

---

## 2. Decisión

**Se adopta JWT (JSON Web Token) con firma asimétrica RS256 (RSA + SHA-256) como
mecanismo de autenticación y autorización del sistema.**

### Modelo de tokens

Se manejan dos tipos de token con responsabilidades distintas:

| Token           | Duración  | Almacenamiento cliente        | Propósito                              |
|-----------------|-----------|-------------------------------|----------------------------------------|
| **Access Token** | 15 minutos | Authorization header (Bearer) | Autenticar cada petición al Gateway    |
| **Refresh Token**| 7 días     | `httpOnly` cookie (Secure)    | Obtener un nuevo par de tokens         |

### Distribución de claves

| Componente        | Clave que posee    | Operación que realiza              |
|-------------------|--------------------|-------------------------------------|
| Security Service  | Clave privada RSA  | Firma (emite) los tokens            |
| API Gateway       | Clave pública RSA  | Verifica la firma (offline)         |
| Inventory Service | Ninguna            | Confía en headers del Gateway       |
| Otros servicios   | Ninguna            | Confían en headers del Gateway      |

**Principio de seguridad clave**: solo el Security Service conoce la clave privada.
Ningún otro servicio puede emitir tokens válidos aunque sea comprometido. El API
Gateway solo necesita la clave pública para verificar, lo que reduce
drásticamente la superficie de ataque.

---

## 3. Estructura del Access Token (Claims)

```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "accesorios-dm-key-v1"
  },
  "payload": {
    "iss": "accesorios-dm-security-service",
    "sub": "550e8400-e29b-41d4-a716-446655440000",
    "iat": 1746835200,
    "exp": 1746836100,
    "jti": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "roles": ["ROLE_ADMIN", "ROLE_VENDEDOR"],
    "permissions": ["inventory:read", "inventory:write", "catalog:read"],
    "email": "usuario@accesorios-dm.com"
  }
}
```

### Descripción de claims

| Claim           | Tipo     | Descripción                                                    |
|-----------------|----------|----------------------------------------------------------------|
| `iss`           | Estándar | Emisor del token — identifica al Security Service              |
| `sub`           | Estándar | ID único del usuario (UUID) — sujeto del token                 |
| `iat`           | Estándar | Timestamp de emisión (Unix epoch)                              |
| `exp`           | Estándar | Timestamp de expiración (Unix epoch)                           |
| `jti`           | Estándar | JWT ID único — permite identificar y revocar un token específico |
| `roles`         | Custom   | Lista de roles del usuario en el sistema                       |
| `permissions`   | Custom   | Lista de permisos granulares derivados de los roles            |
| `email`         | Custom   | Email del usuario para logging y trazabilidad                  |

> **Nota de seguridad**: no se incluyen datos sensibles (contraseñas, datos de pago,
> información personal completa) en el token. El token es verificable públicamente
> con la clave pública RSA.

### Headers inyectados por el Gateway a los servicios internos

Una vez validado el token, el Gateway extrae los claims y los propaga como headers HTTP:

| Header HTTP          | Valor extraído del token   |
|----------------------|---------------------------|
| `X-User-Id`          | `sub` (UUID del usuario)  |
| `X-User-Email`       | `email`                   |
| `X-User-Roles`       | `roles` (serializado)     |
| `X-User-Permissions` | `permissions` (serializado)|

Los servicios internos leen estos headers directamente sin re-validar el token.

---

## 4. Flujo de Autenticación

### 4.1 Login inicial

```
Cliente Angular
     │
     │  POST /api/v1/auth/login
     │  { "email": "...", "password": "..." }
     ▼
API Gateway (NestJS)
     │  Ruta pública — sin validación JWT
     │  Proxy directo al Security Service
     ▼
Security Service (Spring Boot)
     │  1. Valida credenciales contra schema `security`
     │  2. Obtiene roles y permisos del usuario
     │  3. Genera Access Token (firma con clave privada RSA)
     │  4. Genera Refresh Token (UUID opaco, almacenado en BD)
     ▼
API Gateway
     │  Responde al cliente
     ▼
Cliente Angular
     │  Almacena Access Token en memoria (no localStorage)
     │  Almacena Refresh Token en httpOnly cookie (gestionada por el servidor)
```

### 4.2 Petición autenticada

```
Cliente Angular
     │
     │  GET /api/v1/inventory/products
     │  Authorization: Bearer <access_token>
     ▼
API Gateway (NestJS)
     │  1. Extrae token del header Authorization
     │  2. Verifica firma RS256 con clave pública (operación local, sin red)
     │  3. Verifica expiración (exp claim)
     │  4. Verifica que jti no esté en blacklist (caché local)
     │  5. Extrae claims y construye headers internos
     │  6. Inyecta X-User-Id, X-User-Roles, X-User-Permissions
     │  7. Proxy al Inventory Service
     ▼
Inventory Service (Spring Boot)
     │  Lee X-User-Id y X-User-Roles desde headers
     │  Aplica lógica de negocio y autorización a nivel de recurso si aplica
     │  Responde con datos
     ▼
API Gateway
     │  Normaliza respuesta si es necesario
     ▼
Cliente Angular
```

### 4.3 Renovación de token (Refresh)

```
Cliente Angular
     │  Access Token expirado (error 401 del Gateway)
     │
     │  POST /api/v1/auth/refresh
     │  Cookie: refresh_token=<token>
     ▼
API Gateway → Security Service
     │  1. Extrae refresh token de la cookie
     │  2. Busca el refresh token en BD (schema security)
     │  3. Verifica que no esté revocado ni expirado
     │  4. Genera nuevo Access Token + nuevo Refresh Token (rotación)
     │  5. Invalida el refresh token anterior
     ▼
Cliente Angular
     │  Nuevo par de tokens — reintenta la petición original
```

### 4.4 Logout

```
Cliente Angular
     │  POST /api/v1/auth/logout
     │  Authorization: Bearer <access_token>
     ▼
API Gateway → Security Service
     │  1. Agrega el jti del access token a la blacklist
     │  2. Revoca el refresh token en BD
     │  3. Limpia la cookie del refresh token
     ▼
Cliente Angular
     │  Limpia el access token de memoria
```

---

## 5. Estrategia de Revocación

JWT por diseño es autocontenido: una vez emitido, es válido hasta su expiración.
Esta es su debilidad principal. Se implementan dos mecanismos complementarios:

### 5.1 Blacklist de Access Tokens

Para revocar un access token antes de su expiración (logout, compromiso de cuenta):

- El `jti` (JWT ID único) del token se almacena en una tabla ligera en el schema
  `security` o en una caché Redis (si está disponible).
- El API Gateway consulta esta lista en cada petición autenticada.
- Dado que el access token dura solo 15 minutos, las entradas de la blacklist
  tienen TTL equivalente y se purgan automáticamente.
- **Impacto en rendimiento**: mínimo. La consulta es por clave primaria (jti UUID).
  Si se usa Redis, es una operación O(1) con latencia de microsegundos.

### 5.2 Rotación de Refresh Tokens

Cada vez que se usa un refresh token para obtener un nuevo par:

- El refresh token anterior se invalida inmediatamente en BD.
- Se emite un nuevo refresh token.
- Si se detecta que un refresh token ya usado intenta reutilizarse, se asume
  compromiso de sesión y se revocan **todos** los tokens de ese usuario.

### 5.3 Expiración corta del Access Token

Con 15 minutos de duración, la ventana de exposición ante un token robado es
acotada. Incluso sin blacklist, el daño potencial está limitado en el tiempo.

---

## 6. Gestión de Claves RSA

### 6.1 Generación y distribución

- El Security Service genera el par de claves RSA (2048 bits mínimo, 4096 bits
  recomendado) al inicio del sistema o mediante un proceso controlado.
- La **clave privada** se almacena como secret en el entorno del Security Service
  (variable de entorno o secret manager). Nunca se comparte ni se sube a repositorios.
- La **clave pública** se distribuye al API Gateway mediante:
  - Variable de entorno en el entorno del Gateway.
  - Endpoint JWKS (`/.well-known/jwks.json`) expuesto por el Security Service,
    que el Gateway consulta al arrancar y cachea localmente.

### 6.2 Rotación de claves

- El campo `kid` (Key ID) en el header del JWT permite identificar qué clave se
  usó para firmar.
- En caso de rotación, el Security Service emite nuevos tokens con el nuevo `kid`
  mientras el Gateway mantiene ambas claves en caché durante el período de transición.
- Los tokens firmados con la clave antigua siguen siendo válidos hasta su expiración.

### 6.3 Regla de oro de gestión de claves

> **La clave privada RSA nunca abandona el Security Service.**
> Ningún otro servicio, repositorio, log o variable de entorno de otro componente
> debe contenerla. Si se compromete, se rota inmediatamente y se invalidan todos
> los tokens activos.

---

## 7. Alternativas Consideradas

### Opción A — JWT con firma simétrica HS256

Usa un secret compartido entre todos los servicios para firmar y verificar.

**Razones de descarte:**
- El secret debe distribuirse a todos los servicios que necesiten verificar tokens.
  Si cualquier servicio es comprometido, el atacante puede forjar tokens válidos.
- Viola el principio de mínimo privilegio: no todos los servicios necesitan capacidad
  de emisión, solo de verificación.
- En un sistema distribuido con múltiples servicios, la gestión segura del secret
  compartido es compleja y propensa a errores.
- RS256 resuelve este problema con elegancia sin costo adicional significativo.

### Opción B — Sesiones con almacenamiento en servidor (Session-based Auth)

El servidor emite un ID de sesión que se almacena en base de datos o Redis.

**Razones de descarte:**
- Introduce estado en los servicios: cada servicio o el Gateway debe consultar
  el almacén de sesiones en cada petición (equivalente al problema de llamar al
  Security Service por cada request).
- Escalar horizontalmente requiere sesiones distribuidas (Redis compartido),
  añadiendo dependencia de infraestructura.
- No es compatible con el requisito de verificación offline descentralizada.

### Opción C — OAuth2 / OpenID Connect completo (Keycloak, Auth0, Okta)

Implementación completa del protocolo OAuth2 con un Authorization Server dedicado.

**Razones de descarte:**
- Complejidad de configuración y operación desproporcionada para el tamaño actual
  del sistema y del equipo.
- Introduce una dependencia de infraestructura crítica (Authorization Server) que
  requiere alta disponibilidad propia.
- Los costos de soluciones SaaS (Auth0, Okta) escalan con usuarios activos.
- El sistema no requiere federación de identidad ni login social en esta etapa.
- **Migración posible**: la arquitectura propuesta (Security Service + JWT RS256)
  es compatible con una migración futura a Keycloak o similar si el sistema crece
  y lo justifica, ya que el mecanismo de validación de tokens en el Gateway es
  el mismo (JWKS + RS256).

### Opción D — API Keys estáticas

Claves estáticas generadas por usuario para autenticar peticiones.

**Razones de descarte:**
- No transportan identidad ni roles de forma estándar.
- La rotación y revocación son operaciones manuales o de administración compleja.
- No son adecuadas para autenticación de usuarios finales (UI/UX).
- Pueden ser útiles como mecanismo complementario para integraciones máquina a
  máquina en el futuro, pero no son la solución principal de autenticación.

---

## 8. Consecuencias

### 8.1 Consecuencias Positivas

- **Validación offline y sin latencia adicional**: el Gateway verifica tokens
  localmente sin llamadas HTTP extra, manteniendo la latencia mínima.
- **Seguridad por diseño**: solo el Security Service puede emitir tokens válidos.
  El compromiso de cualquier otro servicio no permite forjar identidades.
- **Stateless**: los servicios no almacenan sesiones. Escalan horizontalmente
  sin coordinación.
- **Propagación segura de identidad**: los servicios internos reciben identidad
  y roles vía headers de confianza del Gateway, sin duplicar lógica de autenticación.
- **Estándar ampliamente soportado**: JWT + RS256 es soportado nativamente por
  Spring Security, NestJS passport y prácticamente cualquier framework moderno.

### 8.2 Consecuencias Negativas

- **Tokens no revocables instantáneamente**: un access token comprometido es válido
  hasta expiración sin blacklist activa. Mitigado por duración corta (15 min)
  y blacklist por `jti`.
- **Tamaño del token**: incluir roles y permisos aumenta el tamaño del JWT. Debe
  balancearse para no incrementar el overhead de red excesivamente.
- **Gestión de claves RSA**: requiere proceso formal de gestión y rotación de
  claves. Más complejo que un secret simétrico, pero significativamente más seguro.
- **Caché de blacklist**: el Gateway debe mantener una caché local o consultar
  Redis para verificar tokens revocados, añadiendo una dependencia ligera.

### 8.3 Restricciones que impone esta decisión

- El access token tiene duración máxima de **15 minutos**. No se extiende este
  período bajo ninguna justificación.
- El refresh token se almacena exclusivamente en `httpOnly` cookie con flag
  `Secure`. No se expone en el body de respuesta ni en localStorage.
- La clave privada RSA reside **únicamente** en el Security Service.
- Los servicios internos no validan el JWT. Confían en los headers del Gateway.
- Todo logout debe invalidar tanto el access token (blacklist por jti) como el
  refresh token (revocación en BD).

---

## 9. Reglas Derivadas

| # | Regla                                                                                                  | Alcance               |
|---|--------------------------------------------------------------------------------------------------------|-----------------------|
| R1 | Solo el Security Service posee y usa la clave privada RSA                                             | Seguridad, código     |
| R2 | El API Gateway valida el JWT con la clave pública sin llamar al Security Service por request          | Arquitectura, código  |
| R3 | Los servicios internos leen identidad desde headers HTTP inyectados por el Gateway                    | Código, contratos     |
| R4 | El access token tiene duración máxima de 15 minutos. No negociable                                    | Configuración         |
| R5 | El refresh token se entrega y almacena exclusivamente en `httpOnly` cookie `Secure`                    | Seguridad, frontend   |
| R6 | Todo logout invalida el jti del access token en blacklist y revoca el refresh token en BD             | Código, Security Svc  |
| R7 | La rotación de refresh tokens es obligatoria: cada uso invalida el token anterior                     | Código, Security Svc  |
| R8 | Las claves RSA se almacenan como secrets de entorno, nunca en repositorios de código                  | DevOps, seguridad     |
| R9 | El token nunca transporta datos sensibles (contraseñas, datos de pago, PII completa)                  | Diseño, código        |

---

## 10. Condiciones de Revisión Futura

Esta decisión puede revisarse si se cumple alguna de las siguientes condiciones:

1. **Federación de identidad requerida**: si el sistema necesita integración con
   proveedores externos de identidad (Google, Facebook, SSO empresarial), se evalúa
   migrar a un Authorization Server completo (Keycloak) que soporte OIDC, manteniendo
   el mecanismo de validación RS256 en el Gateway sin cambios.
2. **Necesidad de revocación instantánea a escala**: si los requisitos de seguridad
   exigen revocación de tokens en milisegundos a alto volumen, se evalúa introducir
   Redis como almacén de blacklist dedicado, reemplazando la tabla en BD.
3. **Requisitos de compliance estrictos**: si regulaciones (PCI-DSS, HIPAA) exigen
   sesiones con expiración controlada por el servidor y auditoría completa de acceso,
   se evalúa un modelo híbrido session + JWT.

---

## 11. Referencias

- RFC 7519 — JSON Web Token (JWT)
- RFC 7517 — JSON Web Key (JWK)
- RFC 7518 — JSON Web Algorithms (JWA) — RS256
- OWASP JWT Security Cheat Sheet
- Spring Security — OAuth2 Resource Server con JWT RS256
- NestJS — `@nestjs/passport` + `passport-jwt`
- ADR-002: API Gateway Custom con NestJS (validación offline en Gateway)
- ADR-001: Shared Database (blacklist de tokens en schema `security`)
