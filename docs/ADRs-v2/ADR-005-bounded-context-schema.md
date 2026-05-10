# ADR-005: Bounded Context por Schema PostgreSQL

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-005                              |
| **Título**  | Bounded Context por Schema PostgreSQL |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema adopta una base de datos PostgreSQL compartida entre todos los
microservicios (ADR-001). Sin una estrategia explícita de aislamiento, los servicios
pueden comenzar a acceder a tablas de dominios ajenos directamente, convirtiendo
el sistema en un monolito disfrazado con las desventajas de ambos mundos:
complejidad de microservicios sin los beneficios de aislamiento.

Se necesita una regla de aislamiento lógico que:

- Defina con precisión qué datos pertenecen a cada servicio.
- Prevenga el acoplamiento directo entre servicios a través de la base de datos.
- Sea verificable en revisiones de código.
- Permita evolucionar hacia bases de datos independientes en el futuro sin
  reescribir los servicios.

---

## 2. Decisión

**Cada microservicio opera dentro de un Bounded Context delimitado por schemas
de PostgreSQL. El ownership de un schema es exclusivo: un solo servicio puede
escribir y leer de sus schemas asignados.**

La base de datos tiene 7 schemas definidos. La asignación de ownership es la
siguiente:

### Mapa de ownership de schemas

| Schema        | Servicio propietario          | Operaciones permitidas | Fase      |
|---------------|-------------------------------|------------------------|-----------|
| `security`    | Security Service              | READ / WRITE           | Activa    |
| `catalogo`    | Inventory Service             | READ / WRITE           | Activa    |
| `inventario`  | Inventory Service             | READ / WRITE           | Activa    |
| `clientes`    | Customer Service *(futuro)*   | READ / WRITE           | Futura    |
| `ventas`      | Payment Service *(futuro)*    | READ / WRITE           | Futura    |
| `promociones` | Payment Service *(futuro)*    | READ / WRITE           | Futura    |
| `logistica`   | Logistics Service *(futuro)*  | READ / WRITE           | Futura    |

### Accesos de lectura cruzada permitidos (excepciones justificadas)

En casos excepcionales y documentados, un servicio puede tener acceso de **solo
lectura** a un schema ajeno, siempre que:

1. La necesidad esté justificada en un ADR o decisión técnica documentada.
2. No exista una alternativa viable mediante llamada HTTP al servicio propietario.
3. Sea acceso de lectura exclusivamente — nunca escritura cross-schema.

| Servicio lector       | Schema ajeno   | Justificación                             | Tipo    |
|-----------------------|----------------|-------------------------------------------|---------|
| *(ninguno actualmente)*| —             | —                                         | —       |

> Esta tabla debe mantenerse actualizada. Toda excepción nueva requiere entrada aquí.

---

## 3. Reglas de Acceso a Datos

### 3.1 Regla principal

```
Un servicio SOLO puede ejecutar queries (SELECT, INSERT, UPDATE, DELETE)
sobre los schemas que le pertenecen según el mapa de ownership.
```

### 3.2 Cómo obtener datos de otro dominio

Si el Inventory Service necesita validar que un cliente existe antes de registrar
un movimiento, NO consulta el schema `clientes` directamente. En cambio:

```
Inventory Service  →  HTTP GET /api/v1/customers/{id}  →  Customer Service
```

El servicio propietario expone los datos mediante su API. El consumidor llama
a esa API. La base de datos de cada dominio es un detalle de implementación
interno del servicio propietario.

### 3.3 Implementación del aislamiento a nivel de base de datos

Para reforzar el aislamiento mediante el motor de base de datos, cada servicio
usa un **usuario de PostgreSQL con permisos restringidos a su schema**:

| Usuario de BD            | Schema(s) con permisos | Permisos          |
|--------------------------|------------------------|-------------------|
| `svc_security`           | `security`             | SELECT, INSERT, UPDATE, DELETE |
| `svc_inventory`          | `catalogo`, `inventario` | SELECT, INSERT, UPDATE, DELETE |
| `svc_customer` *(futuro)*| `clientes`             | SELECT, INSERT, UPDATE, DELETE |
| `svc_payment` *(futuro)* | `ventas`, `promociones`| SELECT, INSERT, UPDATE, DELETE |
| `svc_logistics` *(futuro)*| `logistica`           | SELECT, INSERT, UPDATE, DELETE |

Un intento de acceso cross-schema fallará a nivel de base de datos con error de
permisos, independientemente del código del servicio.

---

## 4. Visión de Dominios y Entidades por Servicio

### Security Service — schema `security`

Responsable del modelo de identidad y control de acceso.

| Entidad              | Responsabilidad                                    |
|----------------------|----------------------------------------------------|
| `usuario`            | Cuenta de acceso al sistema                        |
| `rol`                | Agrupación de permisos por función                 |
| `permiso`            | Acción granular sobre un recurso                   |
| `usuario_rol`        | Asociación muchos-a-muchos usuario ↔ rol          |
| `rol_permiso`        | Asociación muchos-a-muchos rol ↔ permiso          |
| `refresh_token`      | Tokens de refresco activos (para revocación)       |
| `token_blacklist`    | JTIs de access tokens revocados antes de expirar   |

### Inventory Service — schemas `catalogo` e `inventario`

Responsable del catálogo de productos y los movimientos de stock.

**Schema `catalogo`:**

| Entidad           | Responsabilidad                              |
|-------------------|----------------------------------------------|
| `categoria`       | Clasificación jerárquica de productos        |
| `material`        | Tipos de material de los productos           |
| `producto`        | Artículo del catálogo con sus atributos      |
| `imagen_producto` | Imágenes asociadas a un producto             |

**Schema `inventario`:**

| Entidad              | Responsabilidad                               |
|----------------------|-----------------------------------------------|
| `tipo_movimiento`    | Catálogo de tipos: entrada, salida, ajuste    |
| `inventario_movimiento` | Registro de cada movimiento de stock       |

---

## 5. Consecuencias

### 5.1 Consecuencias Positivas

- **Bajo acoplamiento en datos**: los servicios no dependen del modelo interno
  de datos de otros servicios. Cada uno puede evolucionar su schema sin impactar
  a los demás.
- **Migración futura simplificada**: mover un schema a una base de datos independiente
  en el futuro requiere solo cambiar la cadena de conexión del servicio propietario.
  El resto del sistema no se ve afectado.
- **Seguridad por capas**: el aislamiento es reforzado tanto por convención de código
  como por permisos de base de datos.
- **Trazabilidad de responsabilidades**: siempre es claro quién es dueño de qué datos.

### 5.2 Consecuencias Negativas

- **Latencia en datos cross-domain**: obtener datos de otro dominio requiere una
  llamada HTTP, con mayor latencia que un JOIN directo.
- **Complejidad en operaciones que cruzan dominios**: operaciones que antes eran un
  JOIN ahora requieren múltiples llamadas HTTP y gestión de consistencia eventual.
- **Disciplina de equipo requerida**: el aislamiento depende de que el equipo respete
  las reglas. El motor de base de datos solo es una segunda línea de defensa.

---

## 6. Reglas Derivadas

| # | Regla                                                                                     | Alcance          |
|---|-------------------------------------------------------------------------------------------|------------------|
| R1 | Cada servicio solo accede a sus schemas asignados en el mapa de ownership                | Código, ORM      |
| R2 | Está prohibido hacer JOINs entre schemas de distintos servicios                          | SQL, ORM, queries|
| R3 | Los datos de otro dominio se obtienen llamando al servicio propietario vía HTTP          | Arquitectura     |
| R4 | Cada servicio usa un usuario de BD exclusivo con permisos solo sobre sus schemas         | DevOps, BD       |
| R5 | Toda excepción de acceso cross-schema debe documentarse en la tabla de excepciones       | Proceso, PR      |
| R6 | Ningún servicio puede escribir en un schema ajeno bajo ninguna circunstancia             | Código, BD       |
| R7 | Los cambios en un schema deben ser revisados por el equipo del servicio propietario      | Proceso, Liquibase|

---

## 7. Condiciones de Revisión Futura

1. **Extracción de schema a BD independiente**: cuando un dominio necesite escalar
   de forma autónoma, su schema puede migrarse a una instancia propia. El ownership
   map se actualiza eliminando ese schema de la BD compartida.
2. **Necesidad de acceso de lectura cross-schema a alta frecuencia**: si una consulta
   crítica de alto volumen requiere datos de dos dominios y la latencia HTTP no es
   aceptable, se evalúa un modelo de replicación de datos con vistas materializadas
   o eventos, manteniendo el ownership original.

---

## 8. Referencias

- Eric Evans — *Domain-Driven Design*, Bounded Contexts
- Sam Newman — *Building Microservices*, capítulo Data Management
- ADR-001: Shared Database como Estrategia de Persistencia Unificada
- PostgreSQL Documentation — Schemas y GRANT/REVOKE de permisos
