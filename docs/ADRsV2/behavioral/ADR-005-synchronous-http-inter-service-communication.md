# ADR-005: Comunicación Sincrónica HTTP entre Servicios vía Proxy

| Campo | Valor |
|---|---|
| **ID** | ADR-005 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | API Gateway, Payment Service, Security Service |

---

## Contexto

En una arquitectura de microservicios, los servicios necesitan comunicarse entre sí. Existen dos paradigmas principales: comunicación sincrónica (HTTP/gRPC) y asincrónica (mensajería con RabbitMQ/Kafka). El sistema Accesorios DM tiene un flujo de checkout que involucra múltiples servicios: el Payment Service necesita consultar o crear clientes en el Security Service, y el API Gateway necesita enrutar hacia todos los servicios downstream.

---

## Problema

¿Qué patrón de comunicación inter-servicio debe adoptarse para el MVP: sincrónico o asincrónico? ¿Cómo gestionar los casos donde un servicio downstream no está disponible?

---

## Decisión

Se adoptó **comunicación sincrónica HTTP** en todos los casos. El API Gateway usa `http-proxy-middleware` como proxy reverso. El Payment Service hace llamadas HTTP directas al Security Service usando `fetch` nativo para el flujo de checkout.

**Evidencia en código:**

```js
// accesorios-dm-payment-service/src/controllers/pedidoController.js
// Checkout: Payment → Security Service (HTTP directo)
const clienteExistenteResponse = await fetch(
    `${process.env.SECURITY_SERVICE_URL}/clientes/correo/${encodeURIComponent(cliente.correo)}`
);
if (!clienteExistenteResponse.ok) {
    const crearClienteResponse = await fetch(
        `${process.env.SECURITY_SERVICE_URL}/clientes/`,
        { method: 'POST', ... }
    );
}
```

```js
// accesorios-dm-api-gateway/src/routes/index.js
// Gateway → Servicios downstream (proxy con timeout)
const proxyOptions = {
    proxyTimeout: 60000,
    timeout: 60000,
    onError: (err, req, res) => {
        res.status(503).json({ error: 'Servicio no disponible' });
    }
};
```

---

## Justificación Técnica

- **Simplicidad**: HTTP REST es el paradigma más simple para el equipo y compatible con todas las tecnologías del stack (Java, Python, Node.js).
- **Debugging directo**: Las llamadas HTTP síncronas son triviales de debuggear con logs y herramientas como Postman/curl.
- **Adecuado para MVP**: La comunicación sincrónica es suficiente para los flujos de negocio actuales que no tienen requisitos de alta concurrencia ni procesamiento en segundo plano.
- **Manejo de errores claro**: El código HTTP de respuesta define el estado de la operación sin ambigüedad.

---

## Consecuencias

### Ventajas
- Implementación simple y directa.
- Trazabilidad inmediata: cada operación es un request/response observable.
- Sin infraestructura adicional (message brokers).
- Consistencia inmediata de datos.

### Desventajas
- **Acoplamiento temporal**: Si el Security Service está caído, el checkout completo falla aunque el Payment Service esté operativo.
- **Cascading failures**: Un servicio lento puede hacer que toda la cadena de llamadas sea lenta.
- **Sin retry automático**: No hay mecanismo de reintentos configurado. Un error de red transitorio resulta en fallo del request.
- **Sin circuit breaker**: No hay protección contra servicios que responden lentamente saturando el pool de conexiones.
- **Acoplamiento de red**: Payment Service tiene una dependencia hardcodeada a `SECURITY_SERVICE_URL`.

### Trade-offs
Consistencia inmediata y simplicidad vs. resiliencia y disponibilidad. Para el volumen actual de transacciones, sincrónico es correcto. Con escalabilidad, el flujo de checkout se beneficiaría de patrón Saga asincrónico.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| RabbitMQ/Kafka para eventos | Complejidad operacional y de desarrollo excesiva para MVP |
| gRPC | Requiere definición de contratos Protobuf, curva de aprendizaje alta |
| GraphQL Federation | Sobre-ingeniería para el modelo de datos actual |
| Saga Pattern asincrónico | Justificado solo con transacciones distribuidas complejas |

---

## Impacto Arquitectónico

**Medio-Alto**. Define el contrato de comunicación entre servicios. Un cambio a mensajería asíncrona requeriría refactorización significativa.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Fallo en cascada por servicio caído | Media | Alto | Implementar circuit breaker, timeouts agresivos |
| Payment → Security sin retry | Alta | Medio | Implementar retry con backoff exponencial |
| Timeout de 60s demasiado permisivo | Baja | Medio | Reducir a 10-15s para evitar bloqueos largos |
| `SECURITY_SERVICE_URL` no definido | Baja | Alto | Validar variables de entorno al startup |

---

## Relación con Otros Componentes

- **ADR-001**: El gateway es el proxy HTTP central.
- **ADR-008**: Los health checks validan la disponibilidad de servicios antes de enrutar.
- **ADR-010**: La heterogeneidad tecnológica hace HTTP la única opción práctica de comunicación.

---

## Consideraciones Futuras

- Implementar circuit breaker (Resilience4j en Java, tenacity en Python).
- Agregar retry con backoff exponencial en el Payment Service para llamadas al Security Service.
- Evaluar mensajería asíncrona para el flujo de creación de pedido (Saga Pattern).
- Reducir timeouts de proxy de 60s a valores más conservadores.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento del sistema en tiempo de ejecución: cómo se propagan los requests entre servicios, cómo responde el sistema ante errores de comunicación, y qué ocurre cuando un servicio downstream no está disponible.
