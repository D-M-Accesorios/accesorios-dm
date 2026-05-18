# ADR-003: Rate Limiting Diferenciado por Ambiente en el API Gateway

| Campo | Valor |
|---|---|
| **ID** | ADR-003 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | API Gateway |

---

## Contexto

El API Gateway es el único punto de entrada al sistema y debe protegerse contra abuso (ataques DDoS, scraping, fuerza bruta en login). Al mismo tiempo, durante el desarrollo local, los límites estrictos bloquearían el trabajo normal del equipo. QA requiere límites intermedios que permitan pruebas de carga controladas.

---

## Problema

¿Cómo se puede proteger el sistema en producción contra abuso de API sin obstaculizar el desarrollo local y las pruebas de calidad, dado que los ambientes tienen necesidades operacionales completamente distintas?

---

## Decisión

Se implementó un sistema de **rate limiting diferenciado por ambiente** usando `express-rate-limit`, donde la configuración se selecciona dinámicamente según la variable de entorno `NODE_ENV`.

**Evidencia en código:**

```js
// accesorios-dm-api-gateway/src/middleware/rateLimit.js
const getConfig = () => {
    const env = process.env.NODE_ENV || 'development';
    if (env === 'production') return { windowMs: 15 * 60 * 1000, max: 100 };
    if (env === 'qa') return { windowMs: 5 * 60 * 1000, max: 50 };
    return { windowMs: 60 * 1000, max: 1000 }; // development
};
```

Adicionalmente, existe un **rate limiter específico para autenticación**:
```js
const authRateLimit = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10, // máximo 10 intentos de login
    skipSuccessfulRequests: true
});
```

Los endpoints `/health` están exonerados del rate limiting global:
```js
skip: (req) => req.url.includes('/health')
```

---

## Justificación Técnica

| Ambiente | Ventana | Máximo | Razón |
|---|---|---|---|
| Development | 1 min | 1000 | Sin fricción en desarrollo local |
| QA | 5 min | 50 | Permite pruebas funcionales, limita automatización excesiva |
| Production | 15 min | 100 | Protección real contra abuso |
| Auth (todos) | 15 min | 10 | Prevención de fuerza bruta en credenciales |

La omisión de `/health` en el rate limiting garantiza que los health checks de Docker y los monitoreos externos no consuman el cupo ni sean bloqueados.

---

## Consecuencias

### Ventajas
- Protección automática en producción sin configuración manual adicional.
- Desarrollo sin fricciones (1000 req/min es prácticamente ilimitado para uso normal).
- Protección especializada para el endpoint de login (crítico para seguridad).
- Headers estándar incluidos (`RateLimit-*`) para información del cliente.

### Desventajas
- El rate limiting se aplica por IP, no por usuario autenticado. En redes NAT/corporativas, múltiples usuarios pueden compartir IP y ser bloqueados colectivamente.
- No hay rate limiting a nivel de endpoint específico (solo global + auth). Un endpoint costoso podría ser atacado dentro del límite global.
- El `authRateLimit` está definido pero no se encuentra aplicado explícitamente en las rutas de autenticación en el código actual.

### Trade-offs
Simplicidad de implementación vs. granularidad del control. Un sistema más sofisticado requeriría Redis para rate limiting distribuido y por usuario.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Rate limiting único para todos los ambientes | Bloqueaba el trabajo de desarrollo |
| Sin rate limiting | Riesgo de abuso y costos operacionales |
| Rate limiting en cada microservicio | Duplicación de lógica, difícil de mantener |
| Kong/Nginx rate limiting | Overhead de infraestructura no justificado |

---

## Impacto Arquitectónico

**Medio**. Afecta el comportamiento del gateway en todos los ambientes. Determina la capacidad máxima de throughput del sistema.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| `authRateLimit` no aplicado en rutas | Alta | Alto | Aplicar middleware explícitamente en `/security/auth/login` |
| Rate limiting por IP inadecuado en producción | Media | Medio | Migrar a rate limiting por usuario autenticado con Redis |
| Límite de 100 req/15min demasiado restrictivo | Baja | Alto | Monitorear y ajustar según tráfico real |

---

## Deuda Técnica Detectada

El `authRateLimit` está definido en el módulo pero no se importa ni aplica en `routes/index.js`. Esto significa que la protección anti-fuerza-bruta del login **no está activa** actualmente.

---

## Relación con Otros Componentes

- **ADR-001**: El rate limiting es uno de los comportamientos centrales del gateway.
- **ADR-002**: El endpoint de autenticación debería usar `authRateLimit`.
- **ADR-004**: Cada ambiente tiene su puerto y su configuración de rate limiting correspondiente.

---

## Consideraciones Futuras

- Aplicar `authRateLimit` explícitamente en la ruta de proxy hacia `/security/auth/login`.
- Implementar rate limiting distribuido con Redis para entornos con múltiples réplicas del gateway.
- Agregar rate limiting por endpoint (e.g., uploads de imágenes con límite más bajo).
- Implementar alertas automáticas cuando se excedan umbrales de rate limiting en producción.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento del sistema ante volúmenes altos de peticiones: qué respuestas devuelve (429), qué headers incluye, qué endpoints están exonerados, y cómo varía ese comportamiento según el ambiente de ejecución.
