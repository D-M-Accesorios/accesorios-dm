# ADR-017: Implementación del patrón Repository para acceso a datos

## Estado

Aceptado

## Tipo de patrón

Patrón estructural

## Contexto

En aplicaciones con arquitectura en capas, permitir que la lógica de negocio acceda directamente a la base de datos genera un alto acoplamiento entre componentes.

Esto dificulta:

- el mantenimiento del sistema
- la reutilización de código
- las pruebas unitarias

Para evitar este problema se requiere una capa que abstraiga el acceso a los datos.

## Opciones Consideradas

1. Acceso directo a la base de datos desde los servicios de negocio.
2. Implementar una capa de repositorios que gestione la persistencia.

## Decisión

Se decidió implementar el **Repository Pattern** para manejar el acceso a los datos del sistema.

## Justificación

El patrón Repository permite:

- Separar la lógica de negocio del acceso a datos
- Centralizar las consultas a la base de datos
- Facilitar el mantenimiento del código
- Mejorar la testabilidad del sistema

Los repositorios actuarán como intermediarios entre la lógica de negocio y la capa de persistencia.

## Consecuencias

### Positivas

- Código más limpio y organizado
- Separación clara de responsabilidades
- Mayor facilidad para pruebas unitarias
- Reutilización de consultas

### Negativas

- Incremento en el número de clases dentro del proyecto
- Mayor complejidad inicial en la arquitectura
