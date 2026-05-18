# ADR-020: Uso del patrón Factory para creación de entidades

## Estado

Propuesto

## Tipo de patrón

Patrón de diseño creacional

## Contexto

En el sistema existen múltiples entidades del dominio que deben crearse siguiendo ciertas reglas de negocio, como:

- usuarios
- productos
- órdenes
- carritos

Crear estas entidades directamente desde múltiples partes del sistema puede generar inconsistencias y duplicación de lógica.

## Opciones Consideradas

1. Crear entidades directamente mediante constructores.
2. Utilizar el patrón Factory para centralizar la creación de objetos.

## Decisión

Se propone utilizar el **Factory Pattern** para centralizar la creación de entidades del dominio.

## Justificación

El patrón Factory permite:

- Encapsular la lógica de creación de objetos
- Garantizar que las entidades se creen en un estado válido
- Reducir duplicación de código

## Consecuencias

### Positivas

- Centralización de la lógica de creación
- Mayor consistencia en las entidades
- Mejor mantenimiento del código

### Negativas

- Introduce una capa adicional en la arquitectura
- Puede aumentar la complejidad inicial
