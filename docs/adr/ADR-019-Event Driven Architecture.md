# ADR-019: Uso de arquitectura basada en eventos para comunicación entre microservicios

## Estado

Propuesto

## Tipo de patrón

Patrón comportamental

## Contexto

En una arquitectura de microservicios es común que diferentes servicios necesiten reaccionar a cambios realizados en otros servicios.

Por ejemplo:

- Cuando se crea una orden, el servicio de inventario debe actualizar el stock.
- Cuando se registra un usuario, el sistema puede generar eventos de auditoría.

La comunicación directa entre microservicios puede generar dependencias fuertes.

## Opciones Consideradas

1. Comunicación directa mediante llamadas HTTP entre microservicios.
2. Comunicación basada en eventos.

## Decisión

Se propone utilizar una **arquitectura basada en eventos (Event Driven Architecture)** para la comunicación entre microservicios.

## Justificación

Este enfoque permite:

- Reducir el acoplamiento entre servicios
- Permitir que múltiples servicios reaccionen a un mismo evento
- Facilitar la escalabilidad del sistema

## Consecuencias

### Positivas

- Desacoplamiento entre microservicios
- Mayor flexibilidad en la evolución del sistema
- Escalabilidad en la comunicación

### Negativas

- Mayor complejidad en la infraestructura
- Necesidad de manejar consistencia eventual
