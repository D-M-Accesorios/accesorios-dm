# ADR-008: Health Check Endpoints en todos los Microservicios

| Campo | Valor |
|---|---|
| **ID** | ADR-008 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Todos los microservicios, API Gateway, Docker Compose |

---

## Contexto

En una arquitectura de microservicios containerizada con Docker Compose, los contenedores pueden iniciar sin que el servicio interno esté completamente listo (la JVM de Spring Boot puede tardar varios segundos en arrancar). Otros servicios o el gateway pueden intentar conectarse antes de que el servicio esté disponible, causando fallos de arranque en cascada.

---

## Problema

¿Cómo sabe Docker Compose, el API Gateway y los sistemas de monitoreo externos que un servicio está operativo y listo para recibir tráfico? ¿Cómo orquestar el arranque ordenado de servicios interdependientes?

---

## Decisión

Se implementaron **endpoints de health check en todos los microservicios** con respuesta estandarizada, y se configuraron **healthchecks en Docker Compose** que verifican dichos endpoints antes de marcar el contenedor como saludable.

**Evidencia en código:**

```java
// Inventory Service (Spring Boot) - Spring Actuator
// application.yml:
management:
  endpoints:
    web.exposure.include: health,info
  endpoint:
    health.show-details: always
// Endpoint: GET /api/v1/health → {"service":"inventory-service","version":"1.0.0","status":"UP"}
```

```python
# Security Service (FastAPI)
@app.get("/api/v1/health")
def health():
    return {"status": "UP", "service": "security-service", "version": "1.0.0"}
```

```js
// Payment Service (Express)
app.get('/api/v1/health', (req, res) => {
    res.json({ status: 'UP', service: 'payment-service', version: '1.0.0' });
});

// API Gateway (Express)
app.get('/api/v1/gateway/health', (req, res) => {
    res.json({ status: 'UP', service: 'api-gateway', version: '1.0.0',
               environment: config.env, services: { inventory: ..., security: ..., payment: ... } });
});
```

```yml
# docker-compose.yml del API Gateway
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/gateway/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

El API Gateway también agrega los health checks de todos los servicios en `/api/v1/health/all`, haciendo llamadas HTTP a cada downstream:

```js
// routes/index.js
router.get('/health/all', async (req, res) => {
    for (const service of ['inventory', 'security', 'payment']) {
        const url = `http://${config.services[service].host}:${port}/api/v1/health`;
        results[service] = await response.json(); // o { status: 'DOWN', error: ... }
    }
});
```

---

## Justificación Técnica

- **Consistencia de contrato**: Todos los servicios usan el mismo schema de respuesta (`status`, `service`, `version`), facilitando el monitoreo uniforme.
- **Integración con Docker**: `depends_on: condition: service_healthy` permite arranque ordenado.
- **Visibilidad del ecosistema**: `/api/v1/health/all` en el gateway permite verificar el estado de toda la plataforma con un solo request.
- **Exención de rate limiting**: Los endpoints `/health` están exonerados del rate limiter para garantizar que el monitoreo siempre funcione.

---

## Consecuencias

### Ventajas
- Arranque ordenado y confiable de contenedores Docker.
- Un único endpoint para verificar el estado de toda la plataforma.
- Base para integración con herramientas de monitoreo (Prometheus, Datadog, Uptime Robot).
- Rápida detección de servicios caídos por el equipo de operaciones.

### Desventajas
- **Health check superficial**: Los endpoints devuelven `UP` si el proceso está corriendo, pero no verifican la conectividad con la base de datos ni la salud real del servicio. El Inventory Service usa Spring Actuator que sí puede verificar la BD, pero los demás no.
- **`/health/all` es secuencial**: Las llamadas se hacen en un loop `for`, no en paralelo. Con servicios lentos, puede demorar la respuesta.
- **Sin métricas de detalle**: El response no incluye latencia, uptime, versión de BD, etc.
- **Healthcheck de BD solo en producción**: Solo `docker-compose.prod.yml` tiene healthcheck en el contenedor de PostgreSQL.

### Trade-offs
Simplicidad de implementación vs. profundidad del diagnóstico. Los health checks actuales son suficientes para detectar si el proceso está vivo, no para diagnosticar problemas de performance.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Sin health checks | Imposible orquestar arranque y detectar fallos |
| Health checks solo en Docker, no en API | Sin visibilidad desde el exterior |
| Prometheus + Grafana desde el inicio | Complejidad operacional; los health checks son el mínimo viable |

---

## Impacto Arquitectónico

**Medio**. Es la base de la observabilidad del sistema y condición necesaria para el despliegue confiable con Docker Compose.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Health check reporta UP cuando BD está caída | Media | Alto | Agregar verificación de BD en cada endpoint |
| `/health/all` lento por llamadas secuenciales | Baja | Medio | Paralelizar con `Promise.all` |
| Healthcheck faltante en DB develop/qa | Alta | Bajo | Agregar healthcheck en todos los docker-compose |

---

## Mejora Recomendada

```js
// /health/all mejorado con llamadas paralelas:
const results = await Promise.all(
    services.map(async (service) => {
        try {
            const response = await fetch(url, { signal: AbortSignal.timeout(3000) });
            return [service, await response.json()];
        } catch (error) {
            return [service, { status: 'DOWN', error: error.message }];
        }
    })
);
```

---

## Relación con Otros Componentes

- **ADR-001**: El gateway orquesta los health checks del ecosistema.
- **ADR-003**: Los endpoints `/health` están exentos del rate limiting.
- **ADR-014**: Docker Compose usa los health checks para gestionar dependencias entre contenedores.

---

## Consideraciones Futuras

- Enriquecer los health checks con verificación de conectividad de BD y latencia.
- Paralelizar el `/health/all` con `Promise.all`.
- Integrar con Uptime Robot o Prometheus para alertas automáticas.
- Implementar liveness vs. readiness endpoints diferenciados.

---

## Por qué es Behavioral

Es **Behavioral** porque define cómo responde cada servicio a las consultas de estado, qué información devuelve, y cómo el sistema orquesta su arranque basándose en esos comportamientos.
