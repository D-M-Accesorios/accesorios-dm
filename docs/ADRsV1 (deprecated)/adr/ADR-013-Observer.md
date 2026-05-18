# ADR-003: Uso del patrón Observer

## Estado
Aceptado

## Contexto
El carrito de compras debe actualizar la interfaz automáticamente
cuando se agregan o eliminan productos.

Sin reactividad, se requieren actualizaciones manuales en la UI.

## Decisión
Se implementará el patrón Observer utilizando RxJS (Observable y BehaviorSubject)
para manejar la actualización reactiva del carrito.

## Alternativas consideradas
1. Actualización manual de la interfaz
2. Uso de observables (Observer)

## Consecuencias
Positivas:
- Actualización automática de la UI
- Bajo acoplamiento
- Mejor experiencia de usuario

## Negativas:
- Mayor complejidad en el manejo de RxJS
