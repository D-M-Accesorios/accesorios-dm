# ADR-005: Uso de Inyección de Dependencias

## Estado
Propuesto

## Contexto
Los componentes necesitan acceder a servicios como el carrito
sin crear instancias manualmente.

## Decisión
Se utilizará la inyección de dependencias de Angular
para gestionar servicios como CartService.

## Alternativas consideradas
1. Crear instancias manualmente
2. Usar inyección de dependencias

## Consecuencias
Positivas:
- Bajo acoplamiento
- Facilita pruebas
- Reutilización de servicios

## Negativas:
- Puede ser difícil de entender al inicio
