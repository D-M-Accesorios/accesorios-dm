# ADR-002: Uso del patrón Facade

## Estado
Aceptado

## Contexto
La gestión del carrito de compras implica múltiples operaciones
(agregar productos, obtener listado, actualizar datos).

Sin una abstracción, los componentes tendrían que manejar lógica compleja.

## Decisión
Se implementará un servicio (CartService) como fachada para
centralizar la lógica del carrito.

## Alternativas consideradas
1. Manejar la lógica directamente en los componentes
2. Usar un servicio como fachada (Facade)

## Consecuencias
Positivas:
- Simplificación del código
- Mejor organización
- Separación de responsabilidades

## Negativas:
- Puede ocultar lógica interna
