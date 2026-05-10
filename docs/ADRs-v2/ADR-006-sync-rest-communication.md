# ADR-006: Comunicación Síncrona REST/HTTP entre Servicios (Fase 1)

| Campo       | Valor                                         |
|-------------|-----------------------------------------------|
| **ID**      | ADR-006                                       |
| **Título**  | Comunicación Síncrona REST/HTTP entre Servicios (Fase 1) |
| **Estado**  | Accepted                                      |
| **Fecha**   | 2026-05-10                                    |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)           |
| **Revisión**| Revisión requerida al iniciar Fase 2 (Payment/Logistics) |

---

## 1. Contexto

En una arquitectura de microservicios, los servicios necesitan comunicarse entre
sí para completar operaciones de negocio. Existen dos grandes paradigmas:

- **Comunicación síncrona**: el servicio emisor espera una respuesta inmediata
  del servicio receptor antes de continuar (REST/HTTP, gRPC).
- **Comunicación asíncrona**: el emisor publica un mensaje y continúa sin esperar
  respuesta. La respuesta llega eventualmente (RabbitMQ, Kafka, eventos).

El sistema se encuentra en Fase 1, enfocada en los servicios de Inventory y Security
con el API Gateway como orquestador de entrada. Las operaciones actuales son
principalmente de consulta y CRUD simple: obtener productos, autenticar usuarios,
gestionar inventario.

Esta fase no incluye flujos transaccionales complejos que crucen múltiples servicios
(como confirmar un pedido → descontar stock → procesar pago → notificar envío),
que son los casos de uso donde la comunicación asíncrona aporta mayor valor.

---

## 2. Decisión

**En la Fase 1, toda comunicación entre servicios es síncrona mediante REST/HTTP.
El API Gateway actúa como proxy hacia los servicios internos. La comunicación
directa servicio-a-servicio se limita a casos estrictamente necesarios.**

Esta decisión es válida para la Fase 1 y debe revisarse al incorporar servicios
con flujos transaccionales (Payment, Logistics).

---

## 3. Topología de Comunicación

### 3.1 Comunicación externa (cliente → sistema)

```
Cliente Angular / App Móvil
         │
         │ HTTPS — /api/v1/**
         ▼
    API GATEWAY (NestJS)
         │
         ├──────────────────────────────────┐
         │ HTTP interno                     │ HTTP interno
         ▼                                  ▼
  SECURITY SERVICE               INVENTORY SERVICE
  (Spring Boot)                  (Spring Boot)
  :8081                          :8082
```

**Regla**: el cliente solo habla con el Gateway. Nunca con un servicio directamente.

### 3.2 Comunicación interna servicio-a-servicio (Fase 1)

En la Fase 1, la comunicación directa entre servicios internos es mínima. El patrón
principal es:

```
Gateway → Servicio A  (para responder a petición del cliente)
```

Si el Servicio A necesita datos del Servicio B para completar su respuesta:

```
Gateway → Servicio A → Servicio B  (encadenamiento de llamadas)
```

Este patrón debe usarse con moderación. Si se convierte en el caso común, es
señal de que los bounded contexts no están bien definidos.

### 3.3 Descubrimiento de servicios

En Fase 1 (Docker Compose), los servicios se descubren por nombre de contenedor
definido en `docker-compose.yml`:

| Servicio          | Host interno Docker      | Puerto |
|-------------------|--------------------------|--------|
| API Gateway       | `api-gateway`            | 3000   |
| Security Service  | `security-service`       | 8081   |
| Inventory Service | `inventory-service`      | 8082   |
| PostgreSQL        | `postgres`               | 5432   |

Las URLs de los servicios internos se configuran mediante variables de entorno,
nunca hardcodeadas en el código:

```env
# En API Gateway
SECURITY_SERVICE_URL=http://security-service:8081
INVENTORY_SERVICE_URL=http://inventory-service:8082
```

---

## 4. Políticas de Resiliencia

En comunicación síncrona, si el servicio destino falla, el emisor falla también.
Para mitigar esto se definen las siguientes políticas mínimas:

### 4.1 Timeouts

Todo cliente HTTP debe tener timeouts configurados. Sin timeout, una llamada a
un servicio colgado puede bloquear un thread indefinidamente.

| Tipo de timeout       | Valor recomendado | Descripción                                  |
|-----------------------|-------------------|----------------------------------------------|
| Connection timeout    | 3 segundos        | Tiempo máximo para establecer la conexión    |
| Request timeout       | 10 segundos       | Tiempo máximo para recibir la respuesta      |

Si se supera el timeout, el Gateway devuelve `504 Gateway Timeout` con el
formato de error estándar (ADR-009).

### 4.2 Reintentos

Los reintentos solo aplican para errores de red y errores 5xx en operaciones
**idempotentes** (GET, PUT, DELETE). Nunca en POST (crear recursos).

| Condición de reintento | Máximo de intentos | Backoff          |
|------------------------|--------------------|------------------|
| Timeout de conexión    | 2 reintentos       | Fijo — 500ms     |
| 502 Bad Gateway        | 2 reintentos       | Fijo — 500ms     |
| 503 Service Unavailable| 2 reintentos       | Exponencial 1s   |
| 500 Internal Error     | 0 reintentos       | No reintentar    |
| 4xx Client Error       | 0 reintentos       | No reintentar    |

### 4.3 Circuit Breaker (preparación para Fase 2)

En Fase 1 no se implementa circuit breaker por simplicidad. Sin embargo, el Gateway
debe estar preparado para incorporarlo en Fase 2. Se documenta el patrón para guiar
la implementación futura:

```
Estado CLOSED (normal)
   │  Peticiones fluyen normalmente
   │  Si falla X% de peticiones en Y segundos
   ▼
Estado OPEN (cortocircuito)
   │  Peticiones al servicio fallan inmediatamente (sin intentar la llamada)
   │  Se devuelve 503 al cliente
   │  Después de Z segundos
   ▼
Estado HALF-OPEN (prueba)
   │  Se permite UNA petición de prueba
   │  Si tiene éxito → vuelve a CLOSED
   │  Si falla → vuelve a OPEN
```

En NestJS se usará `nestjs-circuit-breaker` u `opossum` cuando se active en Fase 2.

---

## 5. Contratos de Comunicación Interna

Las llamadas HTTP internas entre Gateway y servicios usan los mismos contratos
REST que se exponen externamente, con las siguientes diferencias:

| Aspecto              | Comunicación externa       | Comunicación interna          |
|----------------------|----------------------------|-------------------------------|
| Autenticación        | JWT Bearer token           | Headers inyectados por Gateway|
| URL base             | `https://api.accesorios-dm.com` | `http://service-name:port` |
| TLS                  | Sí (HTTPS)                 | No (red privada Docker)       |
| Rate limiting        | Sí (aplicado en Gateway)   | No                            |

El Gateway, al hacer proxy de una petición, inyecta los headers de identidad
extraídos del JWT del cliente:

```
X-User-Id: 550e8400-e29b-41d4-a716-446655440000
X-User-Email: usuario@accesorios-dm.com
X-User-Roles: ROLE_ADMIN,ROLE_VENDEDOR
X-Trace-Id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

Los servicios internos leen estos headers para aplicar lógica de autorización
a nivel de recurso si es necesario.

---

## 6. Comparación con Comunicación Asíncrona

Se documenta esta comparación para justificar la decisión actual y guiar la
transición futura:

| Criterio                  | Síncrono REST (Fase 1)       | Asíncrono Eventos (Fase 2+)        |
|---------------------------|------------------------------|-------------------------------------|
| Simplicidad               | Alta — fácil de implementar  | Media — requiere broker de mensajes |
| Acoplamiento temporal     | Alto — ambos deben estar up  | Bajo — emisor no depende del receptor |
| Latencia                  | Baja para operaciones simples| Variable — depende del consumer     |
| Trazabilidad              | Simple — request/response    | Compleja — requiere correlación IDs |
| Idoneidad en Fase 1       | Alta                         | Baja — overhead sin beneficio       |
| Idoneidad para pagos/envíos| Baja — fragilidad en cascada | Alta — desacoplamiento necesario    |
| Consistencia               | Inmediata (ACID posible)     | Eventual                            |

---

## 7. Consecuencias

### 7.1 Consecuencias Positivas

- Implementación simple y directa con herramientas nativas de NestJS y Spring Boot.
- Trazabilidad inmediata: el flujo request-response es fácil de seguir en logs.
- Sin infraestructura adicional (no requiere RabbitMQ, Kafka ni broker externo).
- Los contratos REST ya están definidos y son reutilizables.

### 7.2 Consecuencias Negativas

- Acoplamiento temporal: si Inventory Service cae, las peticiones del Gateway
  fallan. Mitigado por timeouts y política de errores estándar.
- Cascada de fallos posible: un servicio lento puede agotar el pool de conexiones
  del Gateway. Mitigado con timeouts agresivos en Fase 1 y circuit breaker en Fase 2.
- No adecuado para flujos de larga duración (procesamiento de pagos, notificaciones
  de envío), que se abordarán con mensajería asíncrona en Fase 2.

---

## 8. Reglas Derivadas

| # | Regla                                                                                            | Alcance         |
|---|--------------------------------------------------------------------------------------------------|-----------------|
| R1 | Los servicios internos no son accesibles directamente desde el exterior (solo vía Gateway)      | Red, Docker     |
| R2 | Las URLs de servicios internos se configuran por variable de entorno, nunca hardcodeadas        | Código, DevOps  |
| R3 | Todo cliente HTTP debe tener connection timeout de 3s y request timeout de 10s como máximo      | Código          |
| R4 | Los reintentos solo aplican en operaciones idempotentes (GET, PUT, DELETE)                      | Código          |
| R5 | El Gateway inyecta headers de identidad en toda petición a servicios internos                   | Gateway, código |
| R6 | La comunicación directa servicio-a-servicio debe ser excepcional y justificada                  | Arquitectura    |
| R7 | Al incorporar Payment Service, se evalúa mensajería asíncrona para flujos transaccionales       | Proceso, ADR    |

---

## 9. Condiciones de Revisión Futura

Esta decisión debe revisarse en los siguientes escenarios:

1. **Inicio de Fase 2 (Payment Service)**: los flujos de pago, confirmación de
   orden y actualización de stock requieren consistencia distribuida. Se evalúa
   introducir un message broker (RabbitMQ o Kafka) para estas operaciones,
   manteniendo REST para operaciones de consulta.
2. **Latencia inaceptable por llamadas encadenadas**: si el encadenamiento
   Gateway → Servicio A → Servicio B introduce latencia medible que afecta la
   experiencia de usuario, se evalúa agregación en el Gateway o caching
   estratégico.
3. **Fallas en cascada recurrentes**: si los timeouts y reintentos no son
   suficientes para garantizar estabilidad, se activa el circuit breaker y se
   evalúa mensajería asíncrona como solución estructural.

---

## 10. Referencias

- Sam Newman — *Building Microservices*, capítulos Inter-Service Communication y Resiliency
- Chris Richardson — *Microservices Patterns*, capítulo Communication Patterns
- Martin Fowler — *Circuit Breaker* pattern
- NestJS `HttpModule` — Cliente HTTP con Axios
- Spring Boot `RestTemplate` / `WebClient` — Clientes HTTP reactivos y bloqueantes
- ADR-002: API Gateway Custom con NestJS
- ADR-003: Estrategia JWT RS256 (propagación de identidad via headers)
- ADR-007: Estrategia de Mensajería Asíncrona (Fase futura)
