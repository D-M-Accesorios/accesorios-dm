# ADR-015: Row Level Security (RLS) de PostgreSQL como Capa de Seguridad de Datos

| Campo | Valor |
|---|---|
| **ID** | ADR-015 |
| **Estado** | Aceptado (Parcialmente implementado) |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Base de Datos, todos los servicios |

---

## Contexto

El sistema maneja datos sensibles: información de empleados, clientes, pedidos y datos financieros. Múltiples microservicios y posiblemente herramientas de BI acceden a la misma base de datos. Se requiere garantizar que un servicio no pueda acceder a datos que no le pertenecen, incluso si comete un error de programación o si alguien obtiene acceso directo a la BD.

---

## Problema

¿Cómo garantizar que el aislamiento de datos entre tipos de usuarios (administradores, vendedores, clientes) se aplique a nivel de base de datos, de forma que no dependa únicamente de la lógica de aplicación?

---

## Decisión

Se implementó **Row Level Security (RLS) de PostgreSQL** con políticas diferenciadas por rol de base de datos. Se crearon 4 roles de BD (`app_admin`, `app_vendedor`, `app_cliente`, `app_bodeguero`) con políticas de acceso a nivel de fila.

**Evidencia en código:**

```sql
-- accesorios-dm-database/03_dcl/02_policies/001_rls_policies.sql

-- Habilitar RLS en tablas sensibles
ALTER TABLE security.empleado ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes.cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas.pedido ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas.carrito ENABLE ROW LEVEL SECURITY;

-- Políticas por rol
CREATE POLICY empleado_admin_all ON security.empleado
    FOR ALL TO app_admin USING (true) WITH CHECK (true);

CREATE POLICY cliente_self_select ON clientes.cliente
    FOR SELECT TO app_cliente
    USING (correo = current_user);

CREATE POLICY pedido_cliente_select ON ventas.pedido
    FOR SELECT TO app_cliente
    USING (id_cliente IN (
        SELECT id_cliente FROM clientes.cliente WHERE correo = current_user
    ));
```

---

## Justificación Técnica

- **Defense in depth**: La seguridad no depende solo de la capa de aplicación. Incluso si hay un bug en FastAPI que permita acceso no autorizado, RLS lo bloquea a nivel de BD.
- **Principio de mínimo privilegio**: Cada rol de BD tiene exactamente los permisos que necesita.
- **Seguridad declarativa**: Las políticas se definen una vez en la BD y aplican a todos los accesos, sin importar desde qué herramienta o servicio se acceda.
- **Auditoría facilitada**: Las políticas RLS son verificables directamente en el catálogo de PostgreSQL.

---

## Consecuencias

### Ventajas
- Segunda línea de defensa independiente de la lógica de aplicación.
- Los clientes solo pueden ver sus propios datos, incluso con acceso directo a la BD.
- Los vendedores ven todos los clientes pero no pueden modificar datos de otros empleados.
- Compatible con herramientas de BI que se conectan directamente a PostgreSQL.

### Desventajas
- **Brecha de implementación crítica**: Las políticas RLS definen roles `app_admin`, `app_vendedor`, `app_cliente`, pero los microservicios se conectan con el usuario `admin` que tiene acceso completo. **Las políticas RLS están definidas pero NO están activas para los microservicios**.
- **`admin` bypasea RLS**: El usuario `admin` usado en todos los `docker-compose.yml` probablemente es superusuario, lo que bypasea automáticamente todas las políticas RLS.
- **Sin SET ROLE en la aplicación**: Para que RLS funcione, la aplicación debe ejecutar `SET ROLE app_vendedor` según el usuario autenticado antes de las queries. Ningún microservicio hace esto.
- **Documentación contradictoria**: El código mismo anota: "Las políticas RLS requieren que la aplicación se conecte con el rol correspondiente" — esto no ocurre en ningún servicio actualmente.

### Trade-offs
Seguridad de datos a nivel de BD vs. complejidad de implementación en la aplicación. RLS requiere coordinación entre la capa de autenticación y la capa de base de datos.

---

## Estado de Implementación

| Componente | Estado |
|---|---|
| Tablas con RLS habilitado | ✅ Implementado |
| Roles de BD creados | ✅ Implementado |
| Políticas de acceso definidas | ✅ Implementado |
| Aplicación conecta con rol correcto | ❌ NO implementado |
| `SET ROLE` según usuario JWT | ❌ NO implementado |
| Pruebas de políticas RLS | ❌ NO implementado |

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Sin RLS (solo control en aplicación) | Única capa de defensa; sin protección ante bugs de app |
| Vistas por rol (sin RLS) | Menos flexible, requiere gestión de múltiples vistas |
| Cifrado de columnas sensibles | Complementario, no excluyente de RLS |
| BD separada por servicio | Aislamiento físico, pero sin RLS a nivel de usuario |

---

## Impacto Arquitectónico

**Alto (potencial)**. Si se implementa correctamente, agrega una capa de seguridad crítica. Actualmente, la infraestructura de seguridad está definida pero no activada.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| `admin` bypasea RLS en producción | Certero | Crítico | Crear usuarios de aplicación no superusuario; implementar `SET ROLE` |
| Políticas RLS bloquean operaciones legítimas | Media | Alto | Probar exhaustivamente antes de activar |
| Performance degradado por subqueries en políticas | Baja | Medio | Indexar columnas usadas en políticas (correo, id_cliente) |

---

## Plan de Corrección

1. Crear usuarios de BD específicos por servicio: `inv_user`, `sec_user`, `pay_user`.
2. Otorgar permisos mínimos a cada usuario.
3. En el Security Service, tras validar el JWT, ejecutar `SET ROLE app_admin/app_vendedor/app_cliente` según el rol del token.
4. Actualizar los `docker-compose.yml` para usar los usuarios específicos.
5. Probar que las políticas bloquean correctamente accesos no autorizados.

---

## Relación con Otros Componentes

- **ADR-002**: El JWT contiene el rol del usuario; este rol debería mapear al rol de BD.
- **ADR-011**: La BD compartida hace RLS más crítico para aislamiento entre servicios.
- **ADR-020**: FastAPI podría implementar `SET ROLE` antes de cada query.

---

## Consideraciones Futuras

- Implementar `SET ROLE` en cada servicio según el contexto de autenticación.
- Crear usuarios de BD específicos por servicio sin privilegios de superusuario.
- Agregar tests automatizados que verifiquen las políticas RLS.

---

## Por qué es Structural

Es **Structural** porque define la estructura de seguridad a nivel de datos: cómo se organiza el control de acceso en la base de datos, qué roles existen, y cómo se aplican las políticas de acceso a nivel de fila.
