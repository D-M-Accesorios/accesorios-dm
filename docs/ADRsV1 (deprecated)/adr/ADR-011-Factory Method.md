# ADR-001: Uso del patrón Factory Method

## Estado
Aceptado

## Contexto
En el frontend del e-commerce de accesorios (collares, pulseras, anillos),
los productos se estaban creando directamente en los componentes,
lo que generaba acoplamiento y dificultaba la escalabilidad.

## Decisión
Se implementará el patrón Factory Method para centralizar la creación
de productos mediante una clase ProductFactory.

## Alternativas consideradas
1. Crear objetos directamente en los componentes
2. Usar una fábrica centralizada (Factory Method)

## Consecuencias
Positivas:
- Bajo acoplamiento
- Escalabilidad
- Código más limpio

## Negativas:
- Mayor complejidad inicial
