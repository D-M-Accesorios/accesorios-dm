# ADR-002: Autenticación JWT HS256 con Security Service como Autoridad Central

| Campo | Valor |
|---|---|
| **ID** | ADR-002 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Security Service, API Gateway, todos los servicios protegidos |

---

## Contexto

El sistema requiere autenticar y autorizar a dos tipos de actores: **empleados internos** (con roles ADMIN, VENDEDOR, BODEGUERO) y **clientes** (acceso a sus propios recursos). Se necesita un mecanismo stateless que funcione en un entorno distribuido de microservicios heterogéneos.

---

## Problema

¿Qué mecanismo de autenticación y autorización debe utilizarse en un sistema de microservicios heterogéneo (Java, Python, Node.js) que sea stateless, simple de implementar en cada servicio y compatible con el modelo de roles del negocio?

---

## Decisión

Se implementó **JWT (JSON Web Tokens) con algoritmo HS256** como mecanismo de autenticación. El **Security Service (FastAPI/Python)** es la autoridad única que emite y valida tokens. Los tokens incluyen en el payload: `sub` (user_id), `email`, `rol` y `exp`.

**Evidencia en código:**

```python
# accesorios-dm-security-service/app/utils/security.py
def create_access_token(data: dict, expires_delta: timedelta = None):
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

# accesorios-dm-security-service/app/config.py
SECRET_KEY: str = "prod-secret-key-cambiar-en-produccion"
ALGORITHM: str = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
```

```python
# accesorios-dm-security-service/app/routers/auth.py
access_token = create_access_token(
    data={"sub": str(user.id_empleado), "email": user.correo, "rol": rol_nombre},
    expires_delta=access_token_expires
)
```

---

## Justificación Técnica

- **Stateless**: Los tokens JWT no requieren estado servidor, facilitando la escalabilidad horizontal.
- **Self-contained**: El token incluye el rol, evitando consultas adicionales a la base de datos en la mayoría de flujos de autorización.
- **Simplicidad**: HS256 con clave compartida es simple de implementar en cualquier lenguaje. Las librerías `python-jose`, `java-jwt` y equivalentes Node.js están disponibles.
- **Expiración**: Tokens con TTL de 30 minutos limitan la ventana de riesgo ante tokens comprometidos.

---

## Consecuencias

### Ventajas
- Implementación sencilla y portable entre los diferentes runtimes.
- No requiere sesión server-side ni almacenamiento distribuido de sesiones.
- El rol incluido en el token permite RBAC sin roundtrip adicional al Security Service.
- Compatible con el flujo OAuth 2.0 si se decide migrar en el futuro.

### Desventajas
- **Revocación imposible sin infraestructura adicional**: No existe mecanismo de blacklist de tokens. Si un empleado es desactivado, su token sigue siendo válido hasta el vencimiento (30 min).
- **SECRET_KEY hardcodeada como fallback**: `"prod-secret-key-cambiar-en-produccion"` en config.py es el valor por defecto, lo que es un riesgo de seguridad crítico si `.env` no se configura correctamente en producción.
- **HS256 vs RS256**: HS256 usa clave simétrica compartida. Si algún servicio se ve comprometido, la clave compartida queda expuesta. El README menciona RS256 en el diagrama pero la implementación usa HS256.
- **Solo autenticación de empleados**: Los clientes no tienen un mecanismo de autenticación formal (el Payment Service crea o busca clientes por email sin autenticación).

### Trade-offs
Simplicidad de desarrollo vs. seguridad robusta. HS256 es adecuado para MVP; en producción con múltiples servicios que validan tokens, RS256 sería más seguro al no requerir compartir la clave privada.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| JWT RS256 (clave asimétrica) | Mayor complejidad, pero más seguro para microservicios |
| OAuth 2.0 + OpenID Connect | Complejidad excesiva para MVP |
| API Keys | Sin expiración automática, gestión manual complicada |
| Session-based auth | No funciona en entorno stateless y multi-servicio |

---

## Impacto Arquitectónico

**Crítico**. Define el contrato de seguridad de todo el sistema. Todos los servicios protegidos dependen del Security Service para la emisión de tokens.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| SECRET_KEY débil en producción | Alta | Crítico | Forzar configuración via `.env`, validar en startup |
| Tokens no revocables | Media | Alto | Reducir TTL, implementar blacklist en Redis |
| Compromiso de clave compartida | Baja | Crítico | Migrar a RS256, rotar claves periódicamente |
| Debug prints en producción | Alta | Medio | Eliminar `print(f"DEBUG: ...")` del código de producción |

---

## Deuda Técnica Detectada

1. `print(f"DEBUG: Token decodificado: {payload}")` expone datos sensibles en logs de producción.
2. El valor por defecto de `SECRET_KEY` es un string predecible y explícito.
3. No hay endpoint de refresh token implementado (está documentado pero no codificado).
4. La función `require_role` abre una nueva sesión de BD (`SessionLocal()`) en lugar de reutilizar la sesión inyectada por `get_db`.

---

## Relación con Otros Componentes

- **ADR-001**: El gateway no valida JWT, lo reenvía al Security Service.
- **ADR-015**: Las políticas RLS de PostgreSQL usan roles de BD separados, no JWT.
- **ADR-020**: El modelo de dependencias FastAPI implementa la validación del token.

---

## Consideraciones Futuras

- Migrar a RS256 para que cada microservicio pueda validar tokens con la clave pública sin conocer la privada.
- Implementar refresh tokens con almacenamiento en Redis.
- Agregar validación de JWT en el API Gateway para no delegar al Security Service en cada request.
- Extender autenticación a clientes (no solo empleados).
- Eliminar todos los `print(DEBUG)` y reemplazar con logging estructurado.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento de autenticación en tiempo de ejecución: cómo se validan las identidades, qué datos se incluyen en el token, cómo responde el sistema ante tokens inválidos o usuarios inactivos, y cómo se propaga la identidad entre servicios.
