# ADR-001: Shared Database como Estrategia de Persistencia Unificada

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-001                              |
| **Título**  | Shared Database como Estrategia de Persistencia Unificada |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El proyecto **Accesorios DM** adopta una arquitectura de microservicios distribuidos,
separando responsabilidades en servicios independientes: Security, Inventory, Payment,
Logistics y otros por definir.

El patrón canónico de microservicios recomienda una base de datos exclusiva por servicio
(*Database-per-Service*) para garantizar autonomía, bajo acoplamiento y despliegue
independiente. Sin embargo, esta práctica introduce complejidad operacional significativa:

- Múltiples motores de base de datos que administrar, monitorear y respaldar.
- Necesidad de patrones como Saga, Event Sourcing o CQRS para mantener consistencia
  entre servicios.
- Mayor carga de infraestructura y costos operativos en etapas tempranas.
- Curva de aprendizaje elevada para un equipo pequeño.

Dado el tamaño actual del equipo (2–4 personas), la etapa del proyecto y la necesidad
de moverse con agilidad sin sacrificar escalabilidad futura, se evaluó una estrategia
alternativa de persistencia.

---

## 2. Decisión

**Se adopta el patrón Shared Database como estrategia de persistencia unificada.**

Todos los microservicios del sistema comparten una única instancia de **PostgreSQL 15+**.
El aislamiento lógico entre dominios se implementa mediante **schemas separados dentro
de la misma base de datos**, asignando a cada servicio ownership exclusivo sobre sus
schemas correspondientes.

Esta decisión es **firme, definitiva y no está sujeta a revisión** en la fase actual
del proyecto. Toda propuesta técnica, diseño de servicios, contrato de API y
documentación debe adaptarse a esta restricción.

### Base de datos y schemas definidos

| Schema          | Dominio           | Servicio propietario     |
|-----------------|-------------------|--------------------------|
| `security`      | Autenticación     | Security Service         |
| `catalogo`      | Productos         | Inventory Service        |
| `inventario`    | Stock / Movim.    | Inventory Service        |
| `clientes`      | Clientes          | Customer Service (futuro)|
| `ventas`        | Órdenes / Ventas  | Payment Service (futuro) |
| `promociones`   | Promociones       | Payment Service (futuro) |
| `logistica`     | Envíos            | Logistics Service (futuro)|

---

## 3. Alternativas Consideradas

### Opción A — Database-per-Service (estándar canónico de microservicios)

Cada servicio tiene su propio motor de base de datos o instancia dedicada.

**Razones de descarte:**
- Complejidad operacional desproporcionada para el tamaño actual del equipo.
- Requiere implementar Saga Pattern o Event Sourcing para transacciones distribuidas
  desde el inicio, aumentando la complejidad sin beneficio inmediato.
- Costos de infraestructura más elevados (múltiples instancias de DB en producción).
- Riesgo de inconsistencia de datos sin experiencia previa en sistemas distribuidos.

### Opción B — Base de datos por grupo de servicios (clustering parcial)

Agrupa servicios relacionados bajo una misma instancia, por ejemplo: una BD para
servicios de negocio y otra para seguridad.

**Razones de descarte:**
- Complejidad innecesaria para el volumen actual del sistema.
- No resuelve el problema de fondo (consistencia de datos) y añade una capa de
  administración adicional sin beneficio claro.
- Incrementa la superficie de configuración sin aportar aislamiento real.

### Opción C — Shared Database con schema ownership (ELEGIDA)

Una única base de datos PostgreSQL con schemas separados por dominio, y reglas
estrictas de ownership para garantizar aislamiento lógico entre servicios.

**Razones de elección:**
- Un único motor que administrar, monitorear, respaldar y optimizar.
- Aislamiento lógico garantizado mediante schemas y Row Level Security (RLS).
- Posibilidad de transacciones ACID entre dominios cuando sea estrictamente necesario.
- Sin latencia de red adicional para operaciones críticas de datos.
- Compatible con la escala y recursos actuales del equipo.
- Permite una migración progresiva hacia Database-per-Service en el futuro sin
  reescribir los servicios.

---

## 4. Consecuencias

### 4.1 Consecuencias Positivas

- **Simplicidad operacional**: un solo motor de base de datos para administrar,
  monitorear, asegurar y respaldar.
- **Consistencia transaccional**: operaciones que involucran múltiples dominios
  pueden ejecutarse en una sola transacción ACID cuando sea estrictamente necesario.
- **Menor latencia interna**: no hay red adicional entre servicios para acceso a datos.
- **Onboarding simplificado**: el equipo administra un solo motor (PostgreSQL) con
  herramientas consolidadas.
- **Evolución progresiva**: los schemas pueden extraerse a bases de datos independientes
  en el futuro sin cambiar la lógica de negocio de los servicios.

### 4.2 Consecuencias Negativas

- **Punto único de fallo de datos**: un fallo en la instancia de PostgreSQL impacta
  todos los microservicios simultáneamente.
- **Riesgo de acoplamiento**: sin disciplina de ownership, los servicios pueden
  comenzar a acceder a schemas ajenos, convirtiendo el sistema en un monolito
  disfrazado.
- **Escalado limitado por BD**: el escalado horizontal de datos es más complejo al
  compartir una sola instancia.
- **Contención de conexiones**: bajo alta carga, todos los servicios compiten por
  el pool de conexiones de la misma instancia. Requiere configuración cuidadosa
  de `max_connections` y uso de connection pooler (PgBouncer recomendado a futuro).

### 4.3 Restricciones que impone esta decisión

- Ningún servicio puede acceder directamente a schemas que no le pertenecen.
- No se permiten JOINs cross-schema en queries de producción.
- Los datos de otro dominio se obtienen llamando al servicio propietario vía HTTP,
  no consultando su schema directamente.
- Todo cambio en el schema de un dominio requiere revisión del equipo del servicio
  propietario antes de ejecutarse en cualquier entorno compartido.

---

## 5. Reglas Derivadas

Las siguientes reglas son de cumplimiento obligatorio para todo el equipo y deben
validarse en revisiones de código (PR reviews):

| # | Regla | Alcance |
|---|-------|---------|
| R1 | Cada servicio accede **únicamente** a los schemas que le pertenecen | Backend, ORM, queries |
| R2 | Está **prohibido** hacer JOIN entre schemas de distintos servicios en producción | Backend, queries SQL |
| R3 | Si un servicio necesita datos de otro dominio, debe llamar al servicio propietario vía HTTP | Arquitectura, código |
| R4 | Todo cambio de schema (DDL) pasa por revisión del equipo antes de ejecutarse | DB, Liquibase |
| R5 | Las migraciones Liquibase están organizadas por schema/dominio | DB, DevOps |
| R6 | Cada servicio usa su propio usuario de base de datos con permisos restringidos al schema asignado | Seguridad, DB |
| R7 | El connection pooling debe configurarse por servicio para evitar saturación del pool compartido | Infraestructura |

---

## 6. Condiciones de Revisión Futura

Esta decisión puede revisarse únicamente si se cumple alguna de las siguientes condiciones:

1. **Cuello de botella medible**: la instancia compartida de PostgreSQL representa un
   bottleneck de rendimiento documentado y confirmado mediante métricas de producción.
2. **Escala de equipo**: el equipo crece a un punto donde múltiples squads trabajan
   en paralelo sobre el mismo motor y los tiempos de coordinación se vuelven
   insostenibles.
3. **Requisito de compliance**: una regulación externa requiere aislamiento físico de
   ciertos datos (ej. datos de pago bajo PCI-DSS en infraestructura separada).

En caso de revisión, la estrategia de migración recomendada es **schema extraction
progresiva**: mover un schema a una instancia propia por vez, comenzando por el
servicio con mayor carga o mayor necesidad de autonomía.

---

## 7. Referencias

- Martin Fowler — *Patterns of Enterprise Application Architecture* (Shared Database)
- Sam Newman — *Building Microservices* (Database-per-Service vs Shared Database)
- PostgreSQL Documentation — Schemas and Search Path
- Repositorio de base de datos: `accesorios-dm-database` (Liquibase migrations, RLS, schemas)
