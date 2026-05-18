# ADR-007: Integración de WhatsApp como Canal de Confirmación de Pago

| Campo | Valor |
|---|---|
| **ID** | ADR-007 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Payment Service |

---

## Contexto

Accesorios DM es un emprendimiento que **actualmente comercializa por Instagram y WhatsApp**, gestionando pedidos de forma manual. La digitalización del sistema no elimina inmediatamente WhatsApp como canal de comunicación, ya que la pasarela de pagos formal (tarjeta de crédito, PSE) no está implementada en el MVP.

El sistema necesita un mecanismo de cierre del ciclo de compra: el cliente hace el pedido en el sistema, pero la confirmación del pago sigue siendo manual vía WhatsApp.

---

## Problema

¿Cómo integrar el nuevo sistema digital con el proceso de pago manual existente (transferencia bancaria/pago contra entrega) sin implementar una pasarela de pagos completa en el MVP?

---

## Decisión

Al crear un pedido exitosamente, el Payment Service genera un **link de WhatsApp pre-construido** con el número del negocio, el número de pedido y el total, que el cliente puede usar para confirmar el pago.

**Evidencia en código:**

```js
// accesorios-dm-payment-service/src/controllers/pedidoController.js
res.status(201).json({
    message: 'Pedido creado exitosamente',
    pedido: { id_pedido, total, ... },
    cliente: { ... },
    whatsapp_link: `https://wa.me/573166751065?text=Hola,%20quiero%20realizar%20el%20pago%20del%20pedido%20%23${pedido.id_pedido}%20por%20un%20total%20de%20$${total}`
});
```

---

## Justificación Técnica

- **Continuidad operacional**: Permite digitalizar el catálogo y los pedidos sin interrumpir el proceso de pago que ya funciona para el negocio.
- **Cero costo de infraestructura**: No requiere integración con pasarelas de pago (Wompi, PayU, Stripe), que tienen costos de integración, certificaciones y comisiones por transacción.
- **Contexto del mercado colombiano**: WhatsApp Business es el canal de ventas dominante para micro y pequeñas empresas colombianas.
- **Implementación inmediata**: Un link de wa.me se genera con string interpolation, sin APIs externas.
- **Información pre-cargada**: El cliente no necesita recordar el número ni escribir el pedido manualmente; el mensaje está pre-redactado.

---

## Consecuencias

### Ventajas
- Implementación en menos de 5 líneas de código.
- Sin costos de integración ni comisiones.
- Familiar para los clientes del negocio (ya usan WhatsApp para comprar).
- El número del negocio (`573166751065`) está en el código, siendo inmutable sin redeploy.
- Genera continuidad en el proceso de negocio durante la transición digital.

### Desventajas
- **Número de teléfono hardcodeado**: Si cambia el número de WhatsApp del negocio, requiere un redeploy.
- **Sin confirmación automatizada**: El estado del pedido (`PENDIENTE`) debe ser actualizado manualmente por el vendedor una vez confirmado el pago.
- **Sin integración bidireccional**: El sistema no sabe si el cliente envió el mensaje ni si el pago fue confirmado.
- **No escalable**: Con volumen alto de pedidos, la gestión manual de WhatsApp se convierte en cuello de botella.
- **Sin registro de pagos**: No hay tabla de pagos en el modelo de datos; el pago es un proceso externo al sistema.

### Trade-offs
Velocidad de implementación y adecuación al contexto del negocio vs. automatización y escalabilidad del proceso de pago.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Wompi/PayU (Colombia) | Requiere NIT, cuenta bancaria empresarial, integración compleja |
| Stripe | No recomendado para Colombia en MVP; fees en USD |
| Nequi/Daviplata API | APIs no públicas o con proceso de aprobación largo |
| PayPal | No común para el mercado de destino |

---

## Impacto Arquitectónico

**Bajo-Medio**. Es un feature puntual pero revela que el flujo de pagos no está completamente digitalizado. El modelo de datos no tiene tabla de pagos.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Número hardcodeado expuesto | Certero | Bajo | Mover a variable de entorno `WHATSAPP_NUMBER` |
| Pedidos `PENDIENTE` sin resolución | Alta | Medio | Implementar notificaciones y alertas de pedidos sin actualizar |
| No escalable en crecimiento | Media | Alto | Planificar integración con pasarela en próxima fase |

---

## Relación con Otros Componentes

- **ADR-019**: Prisma registra el pedido pero sin estado de pago.
- **ADR-025**: El modelo de datos no tiene schema de pagos (ausencia deliberada en MVP).

---

## Consideraciones Futuras

- Externalizar `573166751065` a variable de entorno `WHATSAPP_NUMBER`.
- Crear tabla `pagos` en el schema `ventas` para registrar confirmaciones.
- Integrar Wompi (pasarela colombiana) en la segunda fase del proyecto.
- Implementar webhook de WhatsApp Business API para automatizar la confirmación.

---

## Por qué es Behavioral

Es **Behavioral** porque define el comportamiento del sistema al finalizar una transacción de compra: qué información devuelve, cómo facilita el siguiente paso del proceso, y cómo se integra con el canal de comunicación externo del negocio.
