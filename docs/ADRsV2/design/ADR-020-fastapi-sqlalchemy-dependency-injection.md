# ADR-020: FastAPI con SQLAlchemy y Dependency Injection para el Security Service

| Campo | Valor |
|---|---|
| **ID** | ADR-020 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Security Service |

---

## Contexto

El Security Service gestiona autenticación, empleados, clientes y roles. Requiere validación automática de esquemas de request/response, documentación de API automática, gestión eficiente de sesiones de base de datos, y un mecanismo de inyección de dependencias para la autenticación JWT.

---

## Problema

¿Cómo diseñar el Security Service en Python para que tenga validación automática de datos, documentación de API, gestión segura de sesiones de BD, y un sistema de autenticación con JWT integrado de forma limpia?

---

## Decisión

Se adoptó **FastAPI + SQLAlchemy 2.0 + Pydantic** con el sistema de inyección de dependencias nativo de FastAPI para gestionar:
1. Sesiones de BD (patrón `get_db`).
2. Autenticación JWT (`get_current_user`).
3. Autorización RBAC (`require_role`).

**Evidencia en código:**

```python
# Gestión de sesiones - patrón Dependency Injection
# app/database.py
def get_db():
    db = SessionLocal()
    try:
        yield db  # Context manager garantiza cierre
    finally:
        db.close()

# Autenticación como dependencia reutilizable
# app/utils/dependencies.py
security = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> Empleado:
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido")
    user = db.query(Empleado).filter(Empleado.id_empleado == int(payload.get("sub"))).first()
    return user

def require_role(allowed_roles: list):
    def role_checker(current_user: Empleado = Depends(get_current_user)):
        # verifica rol
        return current_user
    return role_checker

# Uso en endpoints
@router.get("/empleados/")
def listar_empleados(
    db: Session = Depends(get_db),
    current_user: Empleado = Depends(require_role(["ADMIN"]))
):
    return db.query(Empleado).all()
```

```python
# Schemas Pydantic - validación automática
# app/schemas/auth.py
class LoginRequest(BaseModel):
    correo: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    nombre: str
    correo: str
    rol: str
```

---

## Justificación Técnica

- **Pydantic para validación**: FastAPI usa Pydantic para validar automáticamente el request body, generando errores 422 descriptivos ante datos inválidos.
- **Swagger UI automático**: FastAPI genera documentación OpenAPI en `/docs` sin configuración adicional, permitiendo al equipo explorar y probar la API interactivamente.
- **`Depends()` para transversalización**: El sistema de dependencias de FastAPI permite inyectar `get_db`, `get_current_user` y `require_role` en cualquier endpoint sin repetir código.
- **Context manager para sesiones**: `yield db` en `get_db` garantiza que la sesión se cierra siempre, incluso ante excepciones.
- **SQLAlchemy 2.0**: ORM maduro con soporte de type hints en Python 3.11, múltiples schemas y transacciones.

---

## Consecuencias

### Ventajas
- Documentación de API autogenerada con Swagger UI en `/docs`.
- Validación de datos de entrada con errores HTTP 422 descriptivos automáticos.
- Inyección de dependencias declarativa y compositional.
- Separación limpia entre routers, modelos SQLAlchemy y schemas Pydantic.
- El patrón `require_role(["ADMIN"])` es legible y reutilizable.

### Desventajas
- **`require_role` abre nueva sesión de BD**: Dentro de `role_checker`, se crea `db = SessionLocal()` manualmente en lugar de reusar la sesión del contexto de la request, generando una segunda conexión innecesaria por request autenticado.
- **`print(DEBUG)` en código de producción**: `dependencies.py` tiene `print(f"DEBUG: Token recibido...")` que expone información sensible en logs.
- **No async**: Las funciones de BD son síncronas (`db.query()`), usando el ORM síncrono de SQLAlchemy. FastAPI soporta async; usar `asyncpg` y `SQLAlchemy async` mejoraría el throughput.
- **Sin schemas de response distintos**: El mismo schema Pydantic se usa para crear y retornar objetos; idealmente deberían ser diferentes (sin exponer campos internos).

### Trade-offs
Productividad con FastAPI vs. profundidad de diseño. FastAPI facilita el arranque rápido; el sistema DI permite evolucionarlo. Los problemas detectados son deuda técnica puntual, no fallas de diseño estructural.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Django + DRF | Más pesado, opinionado; FastAPI más moderno para microservicios |
| Flask + SQLAlchemy | Sin validación automática ni DI nativo |
| SQLModel (FastAPI + SQLAlchemy unificado) | Merece consideración en refactor |
| Django Ninja | Buena opción pero menos comunidad que FastAPI |

---

## Impacto Arquitectónico

**Alto**. Define el stack completo del Security Service: framework, ORM, validación y mecanismos de autenticación.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Segunda sesión de BD en `require_role` | Certero | Medio | Pasar `db` como parámetro a `role_checker` |
| Debug prints en producción | Certero | Medio | Eliminar todos los `print(DEBUG)` |
| ORM síncrono limita concurrencia | Baja | Medio | Migrar a SQLAlchemy async cuando escale |

---

## Corrección de `require_role` (doble sesión de BD)

```python
# CORRECCIÓN: pasar db como dependencia en lugar de crear nueva
def require_role(allowed_roles: list):
    def role_checker(
        current_user: Empleado = Depends(get_current_user),
        db: Session = Depends(get_db)  # ← reutiliza la sesión de la request
    ):
        rol = db.query(Rol).filter(Rol.id_rol == current_user.id_rol).first()
        if rol.nombre not in allowed_roles:
            raise HTTPException(status_code=403, ...)
        return current_user
    return role_checker
```

---

## Relación con Otros Componentes

- **ADR-002**: Este ADR define la implementación del JWT en el Security Service.
- **ADR-011**: SQLAlchemy mapea `security` y `clientes` schemas.
- **ADR-015**: La futura implementación de `SET ROLE` iría en `get_db`.

---

## Consideraciones Futuras

- Migrar `require_role` para reutilizar la sesión de BD inyectada.
- Eliminar todos los `print(DEBUG)` y reemplazar con `logging.debug()`.
- Considerar SQLModel para unificar schemas Pydantic y modelos SQLAlchemy.
- Implementar async cuando el volumen de requests lo justifique.

---

## Por qué es Design

Es **Design** porque define los patrones de diseño internos del Security Service: el sistema de dependencias, el flujo de autenticación, la gestión de sesiones, y la estructura de validación de datos.
