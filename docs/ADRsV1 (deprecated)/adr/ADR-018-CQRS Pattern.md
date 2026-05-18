# ADR-018: Implementación del patrón CQRS (Command Query Responsibility Segregation)

## Estado

Aceptado

## Tipo de patrón

Patrón comportamental

## Contexto

En el sistema de e-commerce existen dos tipos principales de operaciones:

- **Operaciones de escritura**: creación de productos, registro de usuarios, creación de órdenes.
- **Operaciones de lectura**: consulta de catálogo, consulta de pedidos, visualización de productos.

Estas operaciones tienen diferentes necesidades de rendimiento y complejidad.

Usar el mismo modelo para ambos tipos de operaciones puede afectar el rendimiento y la escalabilidad del sistema.

## Opciones Consideradas

1. Utilizar el mismo modelo para lectura y escritura.
2. Separar las operaciones de lectura y escritura utilizando CQRS.

## Decisión

Se decidió implementar el patrón **CQRS (Command Query Responsibility Segregation)** para separar las operaciones de lectura y escritura del sistema.

## Justificación

Este patrón permite dividir el sistema en dos tipos de operaciones:

- **Commands**: operaciones que modifican el estado del sistema.
- **Queries**: operaciones que consultan datos sin modificar el estado.

Esta separación permite optimizar cada tipo de operación de forma independiente.

## Consecuencias

### Positivas

- Mejor rendimiento en consultas
- Mayor escalabilidad
- Separación clara de responsabilidades
- Optimización específica para operaciones de lectura

### Negativas

- Mayor complejidad en la arquitectura
- Necesidad de mantener diferentes modelos para lectura y escritura
