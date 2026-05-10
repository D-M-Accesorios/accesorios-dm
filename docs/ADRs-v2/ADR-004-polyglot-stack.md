# ADR-004: Enfoque Políglota Controlado — NestJS + Spring Boot

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-004                              |
| **Título**  | Enfoque Políglota Controlado — NestJS + Spring Boot |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema Accesorios DM está compuesto por múltiples microservicios con
responsabilidades distintas. Al diseñar la arquitectura backend, surge la
pregunta fundamental: ¿se usa un único stack tecnológico para todos los
servicios, o se permite diversidad de tecnologías según las necesidades
de cada componente?

Una arquitectura de microservicios permite en teoría usar el lenguaje y
framework más adecuado para cada servicio. Sin embargo, esta libertad tiene
un costo: mayor complejidad operacional, mayor carga cognitiva para el equipo
y mayor superficie de mantenimiento.

El equipo es pequeño (2–4 personas) y maneja conocimiento de TypeScript
(Angular en frontend) y Java (experiencia previa en backend empresarial). Se
necesita una decisión explícita sobre qué stacks se permiten, cuántos son
aceptables y bajo qué criterios se elegiría uno sobre el otro.

---

## 2. Decisión

**Se adopta un enfoque políglota controlado con exactamente dos stacks de
backend: NestJS (TypeScript) y Spring Boot (Java 21). Ningún otro lenguaje
o framework puede incorporarse sin un nuevo ADR que lo justifique.**

### Asignación de stack por componente

| Componente         | Stack                    | Justificación principal                         |
|--------------------|--------------------------|------------------------------------------------|
| API Gateway        | NestJS + TypeScript      | I/O-bound, TypeScript shared con Angular, ligero |
| Security Service   | Spring Boot 3 + Java 21  | Spring Security maduro, OAuth2/JWT integrado    |
| Inventory Service  | Spring Boot 3 + Java 21  | Lógica de negocio compleja, JPA, transacciones  |
| Payment Service    | Spring Boot 3 + Java 21  | Transacciones críticas, tipado fuerte, madurez  |
| Logistics Service  | Por definir (Fase futura)| Se evaluará al incorporarlo                     |

---

## 3. Justificación de Cada Stack

### 3.1 NestJS (TypeScript) — API Gateway

**Por qué NestJS para el Gateway y no Java:**

- El Gateway realiza trabajo predominantemente **I/O-bound**: recibir peticiones,
  validar un JWT (operación criptográfica local) y hacer proxy al servicio
  interno. Para este patrón, el event loop de Node.js es más eficiente que
  los threads de la JVM.
- El equipo ya usa TypeScript en Angular. Compartir el lenguaje entre frontend
  y Gateway reduce la fricción cognitiva y abre la posibilidad de compartir
  tipos e interfaces en el futuro.
- NestJS es un framework estructurado con convenciones claras (módulos, guards,
  interceptors, pipes) que produce código predecible y mantenible, evitando los
  problemas de anarquía de Express puro.
- El arranque de NestJS en contenedor Docker es significativamente más rápido
  que Spring Boot (JVM warmup), lo cual es relevante en entornos con escalado
  frecuente.
- El ecosistema de NestJS (`@nestjs/passport`, `@nestjs/throttler`,
  `@nestjs/terminus`, `http-proxy-middleware`) cubre exactamente las necesidades
  del Gateway sin librerías adicionales.

### 3.2 Spring Boot 3 + Java 21 — Servicios de Negocio

**Por qué Spring Boot para los servicios de dominio y no NestJS:**

- **Spring Security** es el framework más maduro del ecosistema Java para
  autenticación y autorización. Ofrece integración nativa con JWT, OAuth2,
  manejo de roles y RBAC sin configuración compleja.
- **Spring Data JPA + Hibernate** proporciona un ORM robusto con soporte completo
  para PostgreSQL, transacciones ACID, lazy loading, criteria queries y
  migraciones con Liquibase.
- **Bean Validation** integrado en Spring MVC ofrece validación declarativa
  con anotaciones (`@NotNull`, `@Size`, `@Positive`) que reduce el código
  de validación manual.
- **Java 21** introduce Virtual Threads (Project Loom) que mejoran el rendimiento
  bajo carga de operaciones bloqueantes (I/O de BD) sin cambiar el modelo de
  programación.
- **Tipado fuerte de Java**: para lógica de negocio compleja (cálculos de stock,
  reglas de precio, flujos de pago), el sistema de tipos estático de Java previene
  errores en tiempo de compilación que TypeScript con `any` o tipos opcionales
  podría permitir pasar desapercibidos.
- **Ecosistema empresarial**: Spring Boot es estándar en el mundo empresarial
  con décadas de patrones documentados para exactamente estos casos de uso.

---

## 4. Alternativas Consideradas

### Opción A — Un solo stack: Spring Boot para todo

Todos los servicios, incluido el Gateway, en Spring Boot.

**Razones de descarte:**
- Spring Cloud Gateway (solución Java para Gateway) consume más recursos que
  NestJS para trabajo I/O-bound, sin beneficios de negocio adicionales.
- El equipo pierde la ventaja de TypeScript compartido con Angular.
- El arranque de la JVM añade latencia en entornos con escalado horizontal.

### Opción B — Un solo stack: NestJS para todo

Todos los servicios, incluida la lógica de negocio compleja, en NestJS.

**Razones de descarte:**
- El ecosistema de TypeScript/Node.js para operaciones de base de datos
  complejas (TypeORM, Prisma) no alcanza la madurez de Spring Data JPA
  para casos de uso empresariales con múltiples schemas y transacciones
  distribuidas.
- Spring Security no tiene equivalente de madurez comparable en Node.js
  para gestión de autenticación compleja.
- El tipado de TypeScript, aunque bueno, es menos estricto que Java en
  tiempo de compilación para lógica de negocio crítica (pagos, stock).

### Opción C — Tres o más stacks (Go, Python, etc.)

Añadir Go para servicios de alta performance o Python para integraciones.

**Razones de descarte:**
- Tres o más stacks con un equipo de 2–4 personas no es sostenible.
- El costo de onboarding, tooling, debugging y mantenimiento se multiplica
  por cada stack adicional.
- Los beneficios de Go o Python no justifican ese costo en este contexto.
- La regla explícita es: máximo dos stacks. Cualquier adición requiere un
  nuevo ADR aprobado por el equipo.

### Opción D — Elegida: NestJS + Spring Boot (políglota controlado)

**Razones de elección:**
- Cada stack se usa donde aporta mayor valor según el tipo de trabajo del servicio.
- El número de stacks (dos) es manejable para el tamaño del equipo.
- Se aprovecha el conocimiento existente del equipo en ambas tecnologías.
- Se establece una regla explícita que previene la proliferación de stacks.

---

## 5. Estrategia para Gestionar la Complejidad Políglota

### 5.1 Estandarización cross-stack

Para reducir la fricción entre los dos stacks, se estandarizan los siguientes
elementos de forma que sean idénticos independientemente del lenguaje:

| Elemento                | Estándar                              | ADR de referencia |
|-------------------------|---------------------------------------|-------------------|
| Formato de errores HTTP | Estructura JSON única                 | ADR-009           |
| Versionamiento de API   | `/api/v1/` en todos los endpoints     | ADR-008           |
| Propagación de identidad| Headers `X-User-*` en todas las rutas | ADR-003           |
| Trazabilidad            | Header `X-Trace-Id` en todos los logs | ADR-009           |
| Contratos de API        | OpenAPI 3.1 para todos los servicios  | ADR-008           |

### 5.2 Regla de no traducción de lógica

Si una lógica de negocio existe en un servicio Spring Boot, **no se replica**
en el Gateway NestJS para evitar inconsistencias. El Gateway es un proxy; la
lógica vive en el servicio propietario.

### 5.3 Docker como abstracción de runtime

Cada servicio se empaqueta en su propio contenedor Docker. El stack interno
(Node.js o JVM) es un detalle de implementación que el resto del sistema no
necesita conocer. Desde el punto de vista del sistema, todos los servicios
son contenedores que hablan HTTP.

---

## 6. Consecuencias

### 6.1 Consecuencias Positivas

- Cada componente usa el stack más adecuado para su tipo de trabajo.
- Se aprovecha el conocimiento existente del equipo sin forzar el aprendizaje
  de una tecnología completamente nueva.
- La restricción de dos stacks máximos previene la entropía tecnológica.
- Docker abstrae las diferencias de runtime para el resto del sistema.

### 6.2 Consecuencias Negativas

- El equipo debe mantener competencia en dos ecosistemas distintos.
- El tooling de desarrollo local (IDE, linters, testing) debe configurarse
  para ambos stacks.
- No es posible reutilizar código directamente entre servicios (solo contratos
  OpenAPI y documentación).
- El debugging de un flujo que cruza el Gateway (NestJS) y un servicio
  (Spring Boot) requiere conocimiento de ambos ecosistemas.

---

## 7. Reglas Derivadas

| # | Regla                                                                                         | Alcance         |
|---|-----------------------------------------------------------------------------------------------|-----------------|
| R1 | Solo NestJS y Spring Boot son stacks permitidos. Ningún otro sin ADR aprobado               | Arquitectura    |
| R2 | El API Gateway usa NestJS. Los servicios de negocio usan Spring Boot                        | Arquitectura    |
| R3 | Los contratos de API (OpenAPI) son la única forma de comunicación formal entre stacks        | Proceso, docs   |
| R4 | La lógica de negocio no se replica en el Gateway independientemente del stack                | Código          |
| R5 | Todo servicio se empaqueta en Docker independientemente de su stack interno                  | DevOps          |
| R6 | Los estándares cross-stack (errores, headers, trazabilidad) aplican sin excepción a ambos    | Código, todos   |

---

## 8. Condiciones de Revisión Futura

1. **Incorporación de un nuevo servicio con necesidades especiales**: si un
   servicio futuro tiene requisitos de rendimiento que ni NestJS ni Spring Boot
   satisfacen (ej. procesamiento intensivo de datos, ML inference), se abre un
   ADR para evaluar un tercer stack de forma justificada y acotada.
2. **Reducción a un solo stack**: si el equipo crece y se especializa en un
   solo lenguaje, puede proponerse migrar el Gateway a Spring Cloud Gateway o
   los servicios de negocio a NestJS con una justificación de productividad
   documentada.

---

## 9. Referencias

- NestJS Official Documentation
- Spring Boot 3 Documentation — Spring Security, Spring Data JPA
- Java 21 — Virtual Threads (Project Loom)
- Martin Fowler — *Polyglot Persistence* y *Microservices*
- ADR-002: API Gateway Custom con NestJS
- ADR-003: Estrategia JWT RS256
- ADR-006: Comunicación Síncrona REST (abstracción HTTP entre stacks)
