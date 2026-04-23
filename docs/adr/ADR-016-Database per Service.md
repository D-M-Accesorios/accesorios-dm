# ADR-016: Implementación del patrón Database per Service

## Estado

Aceptado

## Tipo de patrón

Patrón estructural

## Contexto

El sistema de e-commerce **Accesorios D&M** se está desarrollando bajo una arquitectura basada en microservicios.
Cada microservicio representa un dominio funcional del sistema, como:

- Security Service
- Inventory Service
- Cart Service
- Order Service

Una decisión clave en este tipo de arquitectura es definir cómo se gestionará el almacenamiento de datos.

Una alternativa es utilizar una base de datos compartida entre todos los servicios, lo que simplifica algunas consultas, pero genera alto acoplamiento entre los microservicios.

## Opciones Consideradas

1. Utilizar una base de datos compartida para todos los microservicios.
2. Implementar una base de datos independiente por cada microservicio.

## Decisión

Se decidió implementar el patrón **Database per Service**, donde cada microservicio es responsable de su propio almacenamiento de datos.

## Justificación

Este patrón permite:

- Desacoplar los microservicios
- Permitir evolución independiente del modelo de datos
- Mejorar la escalabilidad del sistema
- Facilitar el despliegue independiente de cada servicio

Cada microservicio accederá únicamente a su propia base de datos o esquema.

## Consecuencias

### Positivas

- Menor acoplamiento entre microservicios
- Mayor independencia entre equipos de desarrollo
- Escalabilidad del sistema
- Mejor mantenimiento del modelo de datos

### Negativas

- Mayor complejidad en consultas entre servicios
- Necesidad de comunicación mediante APIs o eventos
