# ADR-002: API Gateway Custom con NestJS

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-002                              |
| **Título**  | API Gateway Custom con NestJS        |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema Accesorios DM expone múltiples microservicios independientes (Security,
Inventory, Payment, Logistics) que deben ser consumidos por clientes externos: el
portal web Angular y la aplicación móvil.

Exponer directamente cada microservicio al cliente presenta los siguientes problemas:

- **Acoplamiento cliente-servicio**: el frontend debe conocer la dirección, puerto y
  contrato de cada servicio individualmente. Cualquier cambio interno rompe el cliente.
- **Seguridad dispersa**: la validación de autenticación y autorización debe
  implementarse en cada servicio de forma independiente y sincronizada.
- **Sin punto centralizado de control**: el logging, el rate limiting, la gestión de
  CORS y la normalización de errores deben replicarse en cada servicio.
- **Experiencia de API fragmentada**: el frontend recibe respuestas con formatos
  heterogéneos dependiendo del servicio que responde.

Se requiere una capa de entrada única y controlada que abstraiga la topología interna
del sistema y centralice las responsabilidades transversales.

---

## 2. Decisión

**Se implementa un API Gateway de código propio utilizando NestJS (Node.js +
TypeScript).**

El Gateway actúa como el **único punto de entrada** para todos los clientes externos.
Ningún cliente accede directamente a un microservicio. Toda petición entra por el
Gateway, que valida la autenticación, aplica políticas transversales y redirige
la solicitud al servicio correspondiente.

### Responsabilidades del Gateway (qué SÍ hace)

| Responsabilidad          | Descripción                                                      |
|--------------------------|------------------------------------------------------------------|
| **Routing / Proxy**      | Redirige peticiones al microservicio correcto según la ruta      |
| **Validación JWT**       | Verifica el access token con la clave pública RSA (offline)      |
| **CORS**                 | Gestiona headers de Cross-Origin para los clientes autorizados   |
| **Rate Limiting**        | Limita peticiones por IP/usuario para prevenir abuso             |
| **Logging centralizado** | Registra todas las peticiones entrantes con trazabilidad         |
| **Normalización de errores** | Transforma errores de servicios internos al formato estándar |
| **Inyección de headers** | Propaga identidad del usuario autenticado a los servicios internos |
| **Health Check**         | Expone estado del Gateway y de los servicios downstream          |

### Lo que el Gateway NO hace (límites estrictos)

| Prohibición                              | Razón                                              |
|------------------------------------------|----------------------------------------------------|
| Lógica de negocio                        | Rompe SRP y convierte el Gateway en un monolito    |
| Acceso directo a la base de datos        | El Gateway no tiene conocimiento del modelo de datos |
| Validación de reglas de dominio          | Es responsabilidad de cada servicio                |
| Orquestación compleja de servicios       | Agrega complejidad y acoplamiento; usar con extrema cautela |
| Emisión o refresco de tokens JWT         | Es responsabilidad exclusiva del Security Service  |
| Transformación profunda de payloads      | Transformaciones de negocio pertenecen al servicio |

---

## 3. Justificación de NestJS

### 3.1 Alineación de stack tecnológico

El frontend está construido en Angular (TypeScript). El uso de NestJS (TypeScript)
en el Gateway reduce la fricción cognitiva del equipo: mismo lenguaje, mismo sistema
de tipos, posibilidad de compartir tipos e interfaces entre proyectos si se adopta
un monorepo parcial o paquetes compartidos en el futuro.

### 3.2 Ecosistema adecuado para un Gateway

NestJS ofrece de forma nativa o con integración directa:

- **Guards**: interceptación de peticiones para validación de JWT antes del handler.
- **Interceptors**: transformación de respuestas y logging centralizado.
- **Pipes**: validación de inputs en los endpoints propios del Gateway.
- **Middleware**: procesamiento transversal como CORS, rate limiting, request ID.
- **`http-proxy-middleware`**: proxy HTTP hacia servicios downstream con mínima
  configuración.
- **`@nestjs/throttler`**: rate limiting integrado.
- **`@nestjs/terminus`**: health checks para el Gateway y servicios internos.

### 3.3 Alto rendimiento para carga I/O

El Gateway realiza trabajo principalmente I/O-bound: recibir peticiones, validar
un token (operación criptográfica local), y reenviar al servicio interno. Node.js
con su event loop no bloqueante es ideal para este patrón de trabajo, con capacidad
de manejar alta concurrencia sin múltiples hilos.

### 3.4 Curva de aprendizaje y mantenibilidad

El equipo puede mantener el Gateway sin necesidad de aprender una herramienta
adicional (Kong, Nginx avanzado). NestJS es un framework maduro con documentación
exhaustiva, amplia comunidad y convenciones claras que reducen el tiempo de
onboarding.

---

## 4. Alternativas Consideradas

### Opción A — Kong API Gateway

Plataforma de API Gateway gestionada y extensible mediante plugins.

**Razones de descarte:**
- Complejidad de instalación y configuración desproporcionada para el tamaño actual
  del sistema.
- Requiere infraestructura adicional (Kong necesita su propia base de datos o modo
  DB-less con archivos de configuración).
- La lógica personalizada requiere plugins escritos en Lua o Go, lenguajes fuera
  del stack del equipo.
- Los beneficios de Kong (gestión avanzada de plugins, portal de desarrolladores,
  analytics) no son necesarios en esta etapa.
- **Migración posible**: si el sistema escala y se requiere gestión avanzada de
  plugins sin cambiar la interfaz externa, Kong puede adoptarse frente al mismo
  Gateway NestJS de forma transparente.

### Opción B — AWS API Gateway

Servicio gestionado de API Gateway en la nube de AWS.

**Razones de descarte:**
- Dependencia de un proveedor cloud específico (vendor lock-in) desde el inicio.
- El costo crece proporcionalmente con el volumen de peticiones.
- Menor control sobre la lógica de autenticación y transformación personalizada.
- Configuración mediante consola o IaC (Terraform/CDK) añade complejidad operacional
  que no es prioritaria en esta etapa.
- El equipo debería manejar conocimiento de AWS desde el inicio, lo que no está
  garantizado.

### Opción C — Nginx como reverse proxy

Nginx configurado como proxy inverso con módulos de autenticación (nginx-auth-request).

**Razones de descarte:**
- Capacidad de programación muy limitada: la lógica personalizada requiere módulos
  compilados o Lua (OpenResty), fuera del stack del equipo.
- La validación de JWT, el rate limiting granular y la normalización de errores
  requieren configuración compleja y frágil en Nginx.
- Mantenimiento difícil para un equipo de desarrollo que no es especialista en
  administración de Nginx.
- No es extensible sin cambiar el motor subyacente.

### Opción D — Spring Cloud Gateway (Java)

Gateway basado en el ecosistema Spring, coherente con los servicios backend en
Spring Boot.

**Razones de descarte:**
- Mayor consumo de recursos (JVM) para una capa que hace trabajo principalmente
  I/O-bound.
- Añade un tercer lenguaje/runtime si el Gateway ya está separado del dominio de
  Spring Boot (aunque sea Java).
- El tiempo de arranque de la JVM es mayor, lo que impacta en entornos de
  contenedores con escaldo frecuente.
- El equipo tiene conocimiento de TypeScript (Angular) que se aprovecha mejor con
  NestJS.

---

## 5. Consecuencias

### 5.1 Consecuencias Positivas

- **Desacoplamiento cliente-servicio**: el frontend no conoce la topología interna.
  Los servicios pueden moverse, dividirse o renombrarse sin impactar al cliente.
- **Seguridad centralizada**: la validación de JWT ocurre una vez en el Gateway.
  Los servicios internos confían en los headers inyectados por el Gateway.
- **Observabilidad unificada**: un solo lugar para logging, métricas de peticiones
  y trazabilidad de errores.
- **Evolución interna sin impacto externo**: cambios en la arquitectura interna
  (nuevos servicios, división de servicios) son transparentes para el cliente.
- **Contrato de API estable**: el Gateway presenta una API versionada y estable
  independientemente de los cambios internos.

### 5.2 Consecuencias Negativas

- **Punto único de falla de entrada**: si el Gateway falla, todos los clientes
  pierden acceso al sistema. Requiere alta disponibilidad y estrategia de
  redundancia en producción.
- **Latencia adicional**: cada petición pasa por una capa extra antes de llegar
  al servicio. Debe minimizarse mediante validación JWT offline (sin llamada a
  Security Service por petición).
- **Riesgo de concentración de lógica**: sin disciplina, el Gateway puede acumular
  lógica de negocio y convertirse en un monolito. Las reglas de la sección 2 deben
  respetarse estrictamente.
- **Mantenimiento de un servicio adicional**: el Gateway es un servicio más que
  desplegar, monitorear y actualizar.

### 5.3 Restricciones que impone esta decisión

- El frontend (Angular) **solo** se comunica con el Gateway. Está prohibido llamar
  directamente a un microservicio desde el cliente.
- El Gateway valida el JWT **localmente** usando la clave pública RSA del Security
  Service. No realiza una llamada HTTP al Security Service por cada petición.
- Los servicios internos **confían** en los headers inyectados por el Gateway
  (`X-User-Id`, `X-User-Roles`) y no re-validan el token.
- Toda nueva ruta expuesta al cliente debe definirse como contrato en el Gateway
  antes de implementarse en el servicio downstream.

---

## 6. Flujo de Petición a través del Gateway

```
Cliente Angular
     │
     │  HTTPS  /api/v1/inventory/products
     ▼
┌─────────────────────────────────────────────────────────┐
│                    API GATEWAY (NestJS)                 │
│                                                         │
│  1. CORS Middleware       → Verifica origen permitido   │
│  2. Rate Limit Middleware → Verifica límite de peticiones│
│  3. Auth Guard            → Extrae y valida JWT (RSA)   │
│  4. Header Injection      → X-User-Id, X-User-Roles     │
│  5. Request Logger        → Registra petición entrante  │
│  6. Proxy / Router        → Redirige a Inventory Service│
│  7. Response Interceptor  → Normaliza formato de respuesta│
│  8. Error Filter          → Normaliza errores si aplica  │
│                                                         │
└─────────────────────────────────────────────────────────┘
     │
     │  HTTP interno  /api/v1/products
     ▼
┌───────────────────────┐
│   INVENTORY SERVICE   │
│     (Spring Boot)     │
└───────────────────────┘
```

---

## 7. Estructura de Rutas del Gateway

El Gateway expone rutas bajo el prefijo `/api/v1/` y las mapea a servicios internos:

| Ruta pública (Gateway)            | Servicio interno          | Auth requerida |
|-----------------------------------|---------------------------|----------------|
| `POST /api/v1/auth/**`            | Security Service          | No             |
| `GET  /api/v1/inventory/**`       | Inventory Service         | Sí             |
| `GET  /api/v1/catalog/**`         | Inventory Service         | Sí / Parcial   |
| `POST /api/v1/orders/**`          | Payment Service (futuro)  | Sí             |
| `GET  /api/v1/logistics/**`       | Logistics Service (futuro)| Sí             |
| `GET  /api/v1/health`             | Gateway (propio)          | No             |
| `GET  /api/v1/health/services`    | Gateway → todos           | No             |

> El detalle completo de cada ruta se define en los contratos OpenAPI de cada
> servicio. Esta tabla es orientativa para la arquitectura del Gateway.

---

## 8. Reglas Derivadas

| # | Regla                                                                                       | Alcance              |
|---|---------------------------------------------------------------------------------------------|----------------------|
| R1 | El Gateway es el único punto de entrada al sistema para clientes externos                  | Arquitectura, red    |
| R2 | El Gateway NO implementa lógica de negocio de ningún dominio                               | Código, PR review    |
| R3 | La validación JWT se realiza localmente con la clave pública RSA (sin llamada HTTP extra)   | Seguridad, código    |
| R4 | Los servicios internos confían en los headers inyectados por el Gateway sin re-validar      | Arquitectura, código |
| R5 | Toda ruta nueva debe tener contrato OpenAPI definido antes de ser implementada              | Proceso, API design  |
| R6 | Los errores de servicios internos siempre se normalizan al formato estándar en el Gateway   | Código, contratos    |
| R7 | La lógica de agregación de múltiples servicios en el Gateway debe ser excepcional y justificada | Arquitectura    |

---

## 9. Condiciones de Revisión Futura

Esta decisión puede revisarse si se cumple alguna de las siguientes condiciones:

1. **Volumen de tráfico que supera las capacidades del Gateway**: se evidencia que
   una instancia del Gateway es un cuello de botella medible bajo carga real de
   producción. En ese caso, se evalúa escalar horizontalmente el Gateway actual
   antes de reemplazarlo.
2. **Crecimiento del equipo y necesidad de gestión avanzada de APIs**: si el sistema
   expone APIs a terceros (partners, integraciones externas) y se requiere portal
   de desarrolladores, gestión de planes y analytics avanzados, se evalúa migrar
   a Kong o AWS API Gateway como capa frente al Gateway NestJS actual.
3. **Cambio de proveedor de infraestructura que justifique un gateway gestionado**:
   si la organización adopta AWS o Azure completamente, sus gateways gestionados
   pueden ser más convenientes desde el punto de vista operacional.

---

## 10. Referencias

- NestJS Official Documentation — Guards, Interceptors, Middleware
- NestJS Throttler — Rate Limiting
- NestJS Terminus — Health Checks
- `http-proxy-middleware` — Node.js HTTP Proxy
- Sam Newman — *Building Microservices*, capítulo API Gateway
- Chris Richardson — *Microservices Patterns*, capítulo API Gateway Pattern
- ADR-001: Shared Database como Estrategia de Persistencia Unificada
- ADR-003: Estrategia JWT con Firma Asimétrica RS256
