# ADR-001: API Gateway como Único Punto de Entrada al Sistema

| Campo | Valor |
|---|---|
| **ID** | ADR-001 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Todos los microservicios |

---

## Contexto

El sistema Accesorios DM está compuesto por múltiples microservicios independientes: Inventory Service (Java/Spring Boot), Security Service (Python/FastAPI) y Payment Service (Node.js/Prisma). Cada servicio expone sus propios endpoints REST en puertos diferentes. El frontend Angular y una aplicación móvil futura necesitan consumir estas APIs de forma unificada y segura.

Sin un punto de entrada centralizado, cada cliente necesitaría conocer las URLs internas de cada microservicio, manejar CORS individualmente, gestionar rate limiting por separado y no existiría un lugar único para aplicar políticas transversales.

---

## Problema

¿Cómo deben los clientes (frontend web, mobile) comunicarse con un ecosistema de microservicios heterogéneo expuesto en distintos puertos y tecnologías, manteniendo seguridad, observabilidad y simplicidad de consumo?

---

## Decisión

Se implementó un **API Gateway centralizado** basado en **Node.js + Express** que actúa como único punto de entrada para todas las peticiones externas. El gateway enruta las solicitudes hacia los microservicios downstream usando `http-proxy-middleware` con reescritura de paths.

**Evidencia en código:**

```js
// accesorios-dm-api-gateway/src/routes/index.js
router.use('/inventory', inventoryProxy);   // → :8080/api/v1/...
router.use('/security', securityProxy);     // → :8888/api/v1/...
router.use('/payment', paymentProxy);       // → :9000/api/v1/...

// pathRewrite: { '^/api/v1/inventory': '/api/v1' }
```

El gateway opera en el puerto `8000` (producción), `8001` (QA) y `8002` (develop), siendo el único servicio con puertos expuestos al exterior.

---

## Justificación Técnica

- **Separación de concerns**: Los microservicios solo exponen APIs internas dentro de la red Docker compartida. Solo el gateway está en la red pública.
- **Políticas transversales centralizadas**: CORS, rate limiting, logging estructurado, compresión GZIP y headers de seguridad (Helmet) se implementan una sola vez en el gateway.
- **Abstracción de topología interna**: El frontend consume `/api/v1/inventory/...` sin conocer que el servicio está en un host diferente.
- **Health orchestration**: El gateway agrega health checks de todos los servicios en `/api/v1/health/all`, proveyendo visibilidad del estado global del sistema.

---

## Consecuencias

### Ventajas
- Punto único de aplicación de políticas de seguridad transversales.
- Simplificación del cliente: una sola URL base para todos los servicios.
- Capacidad de routing inteligente sin modificar los microservicios.
- Logs centralizados de todas las peticiones entrantes.

### Desventajas
- **Single Point of Failure**: Si el gateway cae, el sistema completo es inaccesible. No hay redundancia configurada.
- **Latencia adicional**: Cada petición agrega un hop de red extra.
- **Gateway como cuello de botella**: Sin load balancing horizontal, el throughput está limitado a una sola instancia.

### Trade-offs
El trade-off principal es la simplicidad operacional vs. disponibilidad. Para el tamaño actual del proyecto (startup), la centralización es la decisión correcta. Con crecimiento, se requeriría alta disponibilidad con múltiples instancias del gateway detrás de un load balancer.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Acceso directo a microservicios desde el cliente | Exposición de topología interna, CORS complejo, sin políticas transversales |
| Service Mesh (Istio, Envoy) | Complejidad operacional excesiva para el tamaño del proyecto |
| AWS API Gateway / Kong | Costo y curva de aprendizaje no justificada para el MVP |
| BFF (Backend for Frontend) por canal | Overhead de desarrollo, complejidad prematura |

---

## Impacto Arquitectónico

**Alto**. Define el patrón de comunicación de todo el sistema. Todos los clientes externos se acoplan a la interfaz del gateway.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Gateway como SPOF | Media | Crítico | Agregar restart policy, healthcheck, múltiples instancias en producción |
| Payload size limitations | Baja | Alto | `express.json({ limit: '10mb' })` ya configurado |
| Timeout en uploads multipart | Media | Medio | `proxyTimeout: 60000` configurado; `/multipart/form-data` no re-serializado |

---

## Relación con Otros Componentes

- **ADR-003**: Rate limiting configurado en el gateway.
- **ADR-002**: El gateway no valida JWT, lo delega al Security Service.
- **ADR-009**: Logging centralizado implementado en el gateway.
- **ADR-014**: Red Docker compartida permite comunicación interna segura.

---

## Consideraciones Futuras

- Implementar múltiples réplicas del gateway con un load balancer (nginx/HAProxy).
- Agregar circuit breaker pattern (resilience4j o similar) para tolerancia a fallos.
- Considerar migración a NestJS (mencionado en arquitectura del README principal) para aprovechar el ecosistema TypeScript y módulos más estructurados.
- Implementar validación de JWT en el gateway para reducir latencia y carga en el Security Service.

---

## Por qué es Behavioral

Este ADR es **Behavioral** porque define el comportamiento en tiempo de ejecución del sistema: cómo se enrutan las peticiones, qué políticas se aplican en cada request, y cómo responde el sistema ante errores de downstream (503 Service Unavailable).
