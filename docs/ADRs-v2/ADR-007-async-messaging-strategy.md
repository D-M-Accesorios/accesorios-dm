# ADR-007: Estrategia de Mensajería Asíncrona (Fase Futura)

| Campo       | Valor                                         |
|-------------|-----------------------------------------------|
| **ID**      | ADR-007                                       |
| **Título**  | Estrategia de Mensajería Asíncrona (Fase Futura) |
| **Estado**  | Proposed                                      |
| **Fecha**   | 2026-05-10                                    |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)           |
| **Revisión**| Requerida al inicio de Fase 2 (Payment Service) |

---

## 1. Contexto

En la Fase 1 del proyecto, toda la comunicación entre servicios es síncrona
mediante REST/HTTP (ADR-006). Este modelo es adecuado para operaciones de
consulta y CRUD simple, donde el cliente espera una respuesta inmediata y
el flujo involucra un solo servicio.

Sin embargo, al incorporar los servicios de Payment y Logistics en fases
posteriores, el sistema enfrentará flujos transaccionales que cruzan múltiples
servicios:

```
Cliente confirma orden
   → Verificar stock disponible    (Inventory Service)
   → Procesar pago                 (Payment Service)
   → Actualizar stock              (Inventory Service)
   → Crear registro de envío       (Logistics Service)
   → Notificar al cliente          (Notification Service)
```

Implementar este flujo de forma síncrona (encadenando llamadas HTTP) introduce
problemas estructurales:

- **Acoplamiento temporal**: si Payment Service está caído, toda la operación
  falla aunque Inventory esté disponible.
- **Cascada de fallos**: un timeout en cualquier paso cancela toda la cadena.
- **Latencia acumulada**: el cliente espera la suma de todos los tiempos de
  respuesta de cada servicio en la cadena.
- **Sin tolerancia a fallos parciales**: no hay mecanismo de reintento granular
  para un paso específico de la cadena.

Se necesita una estrategia de comunicación asíncrona que desacople los servicios
temporalmente y permita flujos transaccionales resilientes.

> **Nota de estado**: Este ADR está en estado **Proposed**. No se implementa
> en Fase 1. Se activa y finaliza su decisión al iniciar Fase 2.

---

## 2. Decisión Propuesta

**En Fase 2, se introducirá un message broker para comunicación asíncrona entre
servicios en flujos transaccionales complejos. El broker candidato principal
es RabbitMQ. La comunicación REST síncrona se mantiene para operaciones de
consulta y CRUD.**

Esta decisión no es definitiva hasta que sea revisada y aprobada al inicio
de Fase 2. Se documenta ahora para que el equipo diseñe los servicios actuales
con esta evolución en mente.

### Principio de coexistencia

Síncrono y asíncrono conviven en el sistema. No se reemplaza uno por el otro:

| Tipo de operación                  | Patrón recomendado  |
|------------------------------------|---------------------|
| Consultas de datos (GET)           | REST síncrono       |
| CRUD simple de un dominio          | REST síncrono       |
| Flujos que cruzan 2+ servicios     | Mensajería asíncrona|
| Notificaciones y eventos de sistema| Mensajería asíncrona|
| Operaciones de larga duración      | Mensajería asíncrona|

---

## 3. Broker Candidato: RabbitMQ

### 3.1 Por qué RabbitMQ sobre Kafka

| Criterio                   | RabbitMQ                           | Kafka                                    |
|----------------------------|------------------------------------|------------------------------------------|
| Complejidad operacional    | Baja — más simple de operar        | Alta — requiere Zookeeper o KRaft        |
| Caso de uso principal      | Task queues, RPC asíncrono         | Streaming de eventos a gran escala       |
| Volumen de mensajes        | Miles/segundo                      | Millones/segundo                         |
| Retención de mensajes      | Hasta que el consumer los lee      | Log persistente configurable             |
| Curva de aprendizaje       | Moderada                           | Alta                                     |
| Adecuación al sistema      | Alta — flujos de negocio acotados  | Excesivo para el volumen actual          |
| Dead Letter Queue          | Nativa y simple                    | Requiere configuración adicional         |

**Conclusión**: RabbitMQ es la opción apropiada para el volumen y la complejidad
del sistema. Kafka se considerará solo si el sistema requiere procesamiento de
eventos a escala masiva o análisis de streams en tiempo real, lo cual está fuera
del alcance actual.

---

## 4. Casos de Uso Específicos

### 4.1 Flujo de confirmación de orden

```
Payment Service
   │  Pago procesado exitosamente
   │  Publica: OrderConfirmed { orderId, userId, items[] }
   ▼
Exchange: orders
   ├──→ Queue: inventory.order-confirmed
   │         └── Inventory Service: descuenta stock
   ├──→ Queue: logistics.order-confirmed
   │         └── Logistics Service: crea registro de envío
   └──→ Queue: notifications.order-confirmed
             └── Notification Service: envía email/push al cliente
```

### 4.2 Actualización de stock tras cancelación

```
Payment Service
   │  Orden cancelada
   │  Publica: OrderCancelled { orderId, items[] }
   ▼
Queue: inventory.order-cancelled
   └── Inventory Service: repone stock
```

### 4.3 Alerta de stock bajo

```
Inventory Service
   │  Movimiento de salida → stock < umbral mínimo
   │  Publica: LowStockAlert { productId, currentStock, threshold }
   ▼
Queue: notifications.low-stock
   └── Notification Service: notifica al administrador
```

---

## 5. Patrón de Consistencia: Saga Coreografiada

Para transacciones que cruzan múltiples servicios sin una transacción ACID
distribuida, se usará el patrón **Saga Coreografiada**:

### Definición

Cada servicio publica un evento cuando completa su trabajo. Los demás
servicios reaccionan a ese evento. No hay un orquestador central.

### Ejemplo: Flujo de compra exitosa

```
[1] Payment Service procesa pago
         │ Publica: PaymentProcessed
         ▼
[2] Inventory Service recibe PaymentProcessed
         │ Descuenta stock
         │ Publica: StockUpdated
         ▼
[3] Logistics Service recibe StockUpdated
         │ Crea envío
         │ Publica: ShipmentCreated
         ▼
[4] Notification Service recibe ShipmentCreated
         │ Envía notificación al cliente
```

### Ejemplo: Flujo de compensación (fallo en paso 2)

```
[1] Payment Service procesa pago
         │ Publica: PaymentProcessed
         ▼
[2] Inventory Service recibe PaymentProcessed
         │ Stock insuficiente — falla
         │ Publica: StockUpdateFailed
         ▼
[3] Payment Service recibe StockUpdateFailed
         │ Revierte el cobro (refund)
         │ Publica: PaymentRefunded
         ▼
[4] Notification Service recibe PaymentRefunded
         │ Notifica al cliente del fallo
```

### Por qué Coreografía sobre Orquestación

| Criterio               | Coreografiada                        | Orquestada (Saga con orquestador)    |
|------------------------|--------------------------------------|--------------------------------------|
| Acoplamiento           | Bajo — servicios no se conocen       | Alto — orquestador conoce a todos    |
| Punto único de falla   | No                                   | Sí (el orquestador)                  |
| Trazabilidad           | Requiere correlationId en eventos    | Centralizada en el orquestador       |
| Complejidad inicial    | Menor                                | Mayor (requiere implementar saga FSM)|
| Adecuación al sistema  | Alta para el tamaño actual           | Excesivo en esta etapa               |

---

## 6. Estructura de Mensajes (Diseño Preliminar)

Todo mensaje en el broker debe incluir un envelope estándar:

```json
{
  "eventId": "uuid-v4",
  "eventType": "OrderConfirmed",
  "version": "1.0",
  "occurredAt": "2026-05-10T14:32:00.000Z",
  "correlationId": "uuid-del-request-original",
  "source": "payment-service",
  "payload": {
    // datos específicos del evento
  }
}
```

| Campo           | Tipo     | Descripción                                              |
|-----------------|----------|----------------------------------------------------------|
| `eventId`       | UUID     | ID único del evento (idempotencia en el consumer)        |
| `eventType`     | String   | Nombre del evento en PascalCase                          |
| `version`       | String   | Versión del contrato del evento                          |
| `occurredAt`    | ISO 8601 | Timestamp de cuando ocurrió el evento                    |
| `correlationId` | UUID     | Vincula el evento al request HTTP original (trazabilidad)|
| `source`        | String   | Servicio que publicó el evento                           |
| `payload`       | Object   | Datos específicos del evento                             |

---

## 7. Estrategia de Manejo de Fallos

### 7.1 Dead Letter Queue (DLQ)

Todo mensaje que falla N veces consecutivas se mueve automáticamente a
una Dead Letter Queue específica por servicio. Un proceso de monitoreo
o intervención manual analiza y reintenta o descarta los mensajes en DLQ.

### 7.2 Idempotencia en consumers

Los consumers deben ser idempotentes: procesar el mismo mensaje dos veces
produce el mismo resultado que procesarlo una sola vez. Esto es crítico para
el manejo de reintentos.

Implementación: verificar si el `eventId` ya fue procesado antes de ejecutar
la lógica de negocio (tabla de eventos procesados por consumer).

### 7.3 At-Least-Once Delivery

RabbitMQ garantiza entrega "al menos una vez". Combinado con idempotencia
en el consumer, se obtiene el comportamiento efectivo de "exactamente una vez".

---

## 8. Impacto en los Servicios Actuales (Fase 1)

Los servicios en Fase 1 (API Gateway, Inventory Service, Security Service)
deben diseñarse con estas consideraciones para facilitar la integración futura:

| Servicio          | Consideración para Fase 2                                     |
|-------------------|---------------------------------------------------------------|
| Inventory Service | Exponer eventos internos cuando el stock cambia significativamente |
| Security Service  | Sin cambios previstos — no participa en flujos transaccionales |
| API Gateway       | Sin cambios — no interactúa con el broker directamente        |

No se requiere ninguna preparación técnica en Fase 1 para la mensajería
asíncrona, más allá de no crear acoplamiento directo que dificulte añadirla.

---

## 9. Consecuencias Proyectadas

### 9.1 Consecuencias Positivas (cuando se implemente)

- Desacoplamiento temporal entre servicios: cada uno puede fallar y recuperarse
  de forma independiente.
- Resiliencia: los mensajes se persisten en el broker hasta que el consumer
  los procesa, tolerando caídas transitorias.
- Escalabilidad: los consumers pueden escalar horizontalmente de forma
  independiente según la carga de su cola.
- Flujos de larga duración sin mantener conexiones HTTP abiertas.

### 9.2 Consecuencias Negativas (cuando se implemente)

- Complejidad operacional adicional: RabbitMQ es otra pieza de infraestructura
  que administrar, monitorear y asegurar.
- Consistencia eventual: el sistema acepta que los datos pueden estar
  temporalmente inconsistentes entre servicios.
- Debugging más complejo: trazar un flujo asíncrono entre múltiples servicios
  requiere correlationId y herramientas de observabilidad distribuida.
- El equipo debe aprender los patrones de mensajería y sus implicaciones.

---

## 10. Reglas Derivadas (Para Cuando se Active)

| # | Regla                                                                                          |
|---|------------------------------------------------------------------------------------------------|
| R1 | Todo consumer de eventos debe ser idempotente                                                 |
| R2 | Todo mensaje incluye el envelope estándar con `eventId`, `correlationId` y `source`          |
| R3 | Los flujos de compensación (rollback de Saga) deben estar documentados para cada flujo       |
| R4 | Cada cola de producción tiene una Dead Letter Queue asociada                                  |
| R5 | Los contratos de eventos (schemas) se versionan igual que los contratos REST (ADR-008)       |
| R6 | El broker no es un bus de datos compartido — solo transporta eventos de negocio              |

---

## 11. Condiciones de Activación

Este ADR pasa de **Proposed** a **Accepted** cuando se cumpla alguna de estas
condiciones:

1. Inicio del desarrollo del Payment Service (Fase 2).
2. Identificación de un flujo transaccional real que cruce 2+ servicios en producción.
3. Fallas en cascada recurrentes por comunicación síncrona entre servicios.

Al activarse, se revisará la elección de broker (RabbitMQ vs. Kafka) con
los datos de volumen real del sistema antes de implementar.

---

## 12. Referencias

- Chris Richardson — *Microservices Patterns*, capítulo Saga Pattern
- Martin Fowler — *Event-Driven Architecture*
- RabbitMQ Official Documentation
- Apache Kafka Documentation
- ADR-006: Comunicación Síncrona REST (estrategia actual, Fase 1)
- ADR-004: Enfoque Políglota Controlado (Spring Boot para servicios de negocio)
