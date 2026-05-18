# ADR-022: SHA-256 con Salt Estático para Hashing de Contraseñas

| Campo | Valor |
|---|---|
| **ID** | ADR-022 |
| **Estado** | Aceptado con Reservas (Requiere corrección para producción) |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Security Service |

---

## Contexto

El sistema necesita almacenar contraseñas de empleados de forma segura en la base de datos. El estándar de la industria para hashing de contraseñas es usar algoritmos adaptativos lentos (bcrypt, argon2, scrypt) que resisten ataques de fuerza bruta. El código del Security Service incluye un comentario explícito que reconoce la limitación.

---

## Problema

¿Qué algoritmo usar para el hashing de contraseñas en el Security Service, sabiendo que debe balancear la seguridad con la simplicidad de implementación inicial?

---

## Decisión

Se implementó hashing con **SHA-256 + salt estático** como mecanismo de hashing de contraseñas. El salt es la cadena literal `"accesorios-dm-salt"` concatenada con la contraseña antes del hash.

**Evidencia en código:**

```python
# accesorios-dm-security-service/app/utils/security.py
def get_password_hash(password: str) -> str:
    """Genera un hash simple usando SHA256 (solo para desarrollo)"""
    salt = "accesorios-dm-salt"
    hash_obj = hashlib.sha256(f"{salt}{password}".encode())
    return base64.b64encode(hash_obj.digest()).decode()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica la contraseña usando SHA256"""
    return get_password_hash(plain_password) == hashed_password
```

El propio comentario en el código reconoce: `"Genera un hash simple usando SHA256 (solo para desarrollo)"`.

---

## Justificación Técnica (por qué se adoptó, no por qué es correcto)

- **Implementación inmediata**: `hashlib.sha256` está en la biblioteca estándar de Python, sin dependencias adicionales.
- **Suficiente para desarrollo**: En el ambiente de desarrollo con datos de prueba, la seguridad real no es crítica.
- **Velocidad de implementación**: Permite avanzar en las HUs de autenticación sin bloquearse en la configuración de bcrypt.

---

## Consecuencias

### Ventajas
- Sin dependencias adicionales (parte de la stdlib de Python).
- Implementación simple y directa.
- Funciona correctamente para el flujo de autenticación básico.

### Desventajas — **CRÍTICAS**

1. **SHA-256 es inadecuado para contraseñas**: SHA-256 es un hash de propósito general de alta velocidad. Una GPU moderna puede computar ~10 billones de hashes SHA-256 por segundo, haciendo ataques de fuerza bruta triviales.

2. **Salt estático global**: El salt `"accesorios-dm-salt"` es idéntico para todos los usuarios. Esto significa:
   - Dos usuarios con la misma contraseña tienen el mismo hash en la BD.
   - Un atacante con el hash de un usuario puede construir tablas rainbow para todo el sistema.
   - El salt está en el código fuente (en texto plano, visible en el repositorio).

3. **Sin factor de costo adaptativo**: bcrypt/argon2 permiten aumentar el factor de costo a medida que el hardware mejora; SHA-256 es siempre igual de rápido.

4. **El script de corrección en el README expone el mecanismo**: `"UC5g9HK3oclQfjko7ZDoYYY79CDV2KqxB5H7hnbOOAU="` es el hash SHA-256 de `"accesorios-dm-salt" + "admin123"`, que alguien puede calcular con el código visible.

### Trade-offs

No existe un trade-off legítimo aquí para producción. SHA-256 con salt estático es inseguro para contraseñas. La única justificación válida es la velocidad de desarrollo en MVP.

---

## Alternativas Correctas (Debería Migrar A)

| Algoritmo | Características | Recomendación |
|---|---|---|
| **bcrypt** | Standard de facto, slow hash, salt aleatorio por contraseña | **Recomendado** |
| Argon2id | Ganador de Password Hashing Competition, resistente a GPU | Mejor opción teórica |
| scrypt | Resistente a hardware especializado | Alternativa válida |
| PBKDF2-SHA256 | Estándar NIST, configurable | Mínimo aceptable |

---

## Impacto Arquitectónico

**Crítico para Seguridad**. Las contraseñas de todos los empleados en producción estarían vulnerables ante una brecha de datos.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Brecha de BD expone todas las contraseñas | Media | Crítico | Migrar a bcrypt antes de producción real |
| Salt en código fuente conocido | Certero | Alto | Migrar a salt único por usuario (bcrypt lo hace automáticamente) |
| Tablas rainbow pre-computadas | Alta (si hay brecha) | Crítico | bcrypt hace esto computacionalmente inviable |

---

## Plan de Migración a bcrypt

```python
# Instalar: pip install bcrypt
import bcrypt

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode(), hashed_password.encode())
```

La migración requiere resetear contraseñas existentes ya que los hashes SHA-256 son incompatibles con bcrypt.

---

## Relación con Otros Componentes

- **ADR-002**: El hash de contraseñas es parte del flujo de autenticación.
- **ADR-015**: RLS puede mitigar parcialmente el impacto de una brecha si está correctamente implementado.

---

## Consideraciones Futuras

- **Migrar a bcrypt inmediatamente antes de cualquier deploy a producción real**.
- Implementar política de contraseñas mínimas (longitud, complejidad).
- Considerar hash con pepper además de salt para doble protección.
- Implementar reset de contraseña seguro.

---

## Por qué es Design

Es **Design** porque define el mecanismo de seguridad interno para el almacenamiento de credenciales: qué algoritmo se usa, cómo se gestiona el salt, y cuál es la estrategia de verificación de contraseñas.
