# ADR-009: Logging Estructurado Centralizado en el API Gateway

| Campo | Valor |
|---|---|
| **ID** | ADR-009 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | API Gateway |

---

## Contexto

En un sistema distribuido, la trazabilidad de requests es crítica para el debugging y la operación. Cada microservicio puede tener su propio sistema de logging, pero el API Gateway es el único punto por donde pasan todas las peticiones externas, lo que lo convierte en el lugar ideal para un registro unificado.

---

## Problema

¿Dónde y cómo registrar las peticiones HTTP en un sistema de microservicios para facilitar el debugging, auditoría y análisis de comportamiento del sistema?

---

## Decisión

Se implementó **logging estructurado en el API Gateway** usando dos capas complementarias:
1. **Winston**: Logging estructurado por niveles con persistencia a archivos.
2. **Morgan**: Logging HTTP en formato estándar, redirigido a Winston.

**Evidencia en código:**

```js
// accesorios-dm-api-gateway/src/middleware/logging.js
const morganFormat = ':remote-addr - :method :url :status :response-time ms - :res[content-length]';
const morganMiddleware = morgan(morganFormat, {
    stream: { write: (message) => logger.info(message.trim()) }
});

const requestLogger = (req, res, next) => {
    const start = Date.now();
    logger.debug(`[REQUEST] ${req.method} ${req.url} - IP: ${req.ip}`);
    
    const originalSend = res.send;
    res.send = function(data) {
        const duration = Date.now() - start;
        logger.info(`[RESPONSE] ${req.method} ${req.url} - ${res.statusCode} - ${duration}ms`);
        if (res.statusCode >= 400) {
            logger.warn(`[ERROR] ${req.method} ${req.url} - ${res.statusCode}`);
        }
        originalSend.call(this, data);
    };
    next();
};
```

```yml
# docker-compose.yml del gateway
volumes:
  - ./logs:/app/logs  # Persistencia de logs en el host
environment:
  - LOG_LEVEL=warn  # Producción: solo warn y error
```

---

## Justificación Técnica

- **Winston como base**: Logging estructurado con niveles (error, warn, info, debug), soporte de transports (consola + archivos), y formato JSON compatible con agregadores de logs.
- **Morgan para HTTP**: Formato estándar de access log incluye IP, método, URL, status y tiempo de respuesta, suficiente para análisis de tráfico.
- **Medición de duración**: El `requestLogger` personalizado mide el tiempo real de respuesta incluyendo el proxy, no solo el procesamiento del gateway.
- **Logs persistidos en host**: Volume mount `./logs:/app/logs` permite acceder a logs históricos incluso si el contenedor se reinicia.
- **Nivel por ambiente**: `LOG_LEVEL=warn` en producción reduce el ruido; `LOG_LEVEL=debug` en desarrollo proporciona máxima verbosidad.

---

## Consecuencias

### Ventajas
- Un único lugar para ver todos los requests al sistema.
- Medición de latencia de extremo a extremo (gateway incluyendo tiempo de proxy).
- Logs persistidos en archivo para análisis offline.
- Separación de logs por nivel permite filtrado eficiente.

### Desventajas
- **Sin correlation ID**: No se genera un request ID único que permita trazar una petición a través de múltiples servicios downstream.
- **Logging solo en gateway**: Los servicios downstream (Inventory, Security, Payment) tienen logging independiente y no coordinado. No hay forma de correlacionar un log del gateway con un log del Inventory Service.
- **Sin agregación central**: Los logs de archivos (`error.log`, `combined.log`) están en el host del gateway, no en un sistema centralizado (ELK, Grafana Loki).
- **Payment Service sin logging estructurado**: Usa `console.error` y `console.log`, perdiendo los beneficios de Winston.

### Trade-offs
Observabilidad básica con cero infraestructura adicional vs. observabilidad avanzada con correlación de trazas. Para MVP es correcto; para producción con múltiples replicas sería insuficiente.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| ELK Stack (Elasticsearch + Logstash + Kibana) | Overhead de infraestructura excesivo para MVP |
| Datadog / New Relic | Costo mensual no justificado en etapa actual |
| Sin logging centralizado (cada servicio independiente) | Debugging fragmentado, imposible correlacionar |
| OpenTelemetry + Jaeger | Trazabilidad distribuida completa pero complejidad alta |

---

## Impacto Arquitectónico

**Medio**. Provee observabilidad básica suficiente para desarrollo. Insuficiente para producción con múltiples instancias o con SLOs definidos.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Sin correlation ID | Certero | Alto | Implementar middleware que genere X-Request-ID |
| Logs crecen sin límite en archivos | Media | Medio | Configurar log rotation en Winston |
| Logs sensibles (tokens) registrados | Baja | Alto | Revisar que URLs con tokens no se logueen completas |

---

## Mejora de Alto Impacto (Bajo Costo)

```js
// Agregar X-Request-ID a cada request
app.use((req, res, next) => {
    req.requestId = crypto.randomUUID();
    res.setHeader('X-Request-ID', req.requestId);
    next();
});
```

---

## Relación con Otros Componentes

- **ADR-001**: El gateway es el punto donde se concentra el logging de entrada.
- **ADR-003**: Los health checks excluidos del rate limiting también pueden excluirse del logging de detalle.

---

## Consideraciones Futuras

- Implementar correlation ID (X-Request-ID) propagado a servicios downstream.
- Integrar con Grafana Loki o ELK como siguiente paso de madurez.
- Agregar logging estructurado en Payment Service (reemplazar console.log con Winston).
- Configurar log rotation para prevenir llenado del disco.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento de observabilidad del sistema: qué eventos se registran, con qué nivel de detalle, cómo se almacenan y cómo varían según el ambiente de ejecución.
