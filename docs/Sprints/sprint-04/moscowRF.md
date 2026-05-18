## Priorización MoSCoW

| Prioridad              | ID    | Requerimiento                             | Justificación                           |
| ---------------------- | ----- | ----------------------------------------- | --------------------------------------- |
| Must Have              | RF-02 | Inicio de sesión                          | Base de la seguridad del sistema        |
| Must Have              | RF-03 | Generación y validación de JWT            | Necesario para arquitectura distribuida |
| Must Have              | RF-04 | Manejo de roles                           | Separación de responsabilidades         |
| Must Have              | RF-07 | Crear productos                           | Base del catálogo                       |
| Must Have              | RF-10 | Listar productos                          | Funcionalidad esencial                  |
| Must Have              | RF-12 | Gestionar stock                           | Control de inventario                   |
| Must Have              | RF-14 | Agregar al carrito                        | Flujo principal de compra               |
| Must Have              | RF-17 | Calcular total del carrito                | Necesario para proceso de pago          |
| Must Have              | RF-20 | Registrar orden de compra                 | Cierre del flujo de negocio             |
| Must Have              | RF-22 | Actualizar estado de orden                | Control del ciclo de vida               |
| Must Have              | RF-24 | Mostrar catálogo en frontend              | Interfaz principal del sistema          |
| Should Have            | RF-01 | Registro de usuario                       | Mejora experiencia del cliente          |
| Should Have            | RF-11 | Gestión de categorías                     | Mejora organización del catálogo        |
| Should Have            | RF-15 | Modificar cantidad en carrito             | Mejora usabilidad                       |
| Should Have            | RF-16 | Eliminar producto del carrito             | Mejora experiencia                      |
| Should Have            | RF-21 | Registrar estado de pago                  | Seguimiento del proceso                 |
| Should Have            | RF-26 | Administración desde frontend             | Facilita gestión                        |
| Could Have             | RF-19 | Configuración dinámica de métodos de pago | Puede simularse inicialmente            |
| Could Have             | RF-23 | Parametrización de impuestos              | Puede definirse como valor fijo         |
| Could Have             | RF-18 | Persistencia avanzada del carrito         | No bloquea el MVP                       |
| Could Have             | RF-27 | Resumen detallado antes de pagar          | Mejora visual                           |
| Won't Have (por ahora) | RF-05 | Asignación dinámica avanzada de roles     | Puede preconfigurarse                   |
| Won't Have (por ahora) | RF-06 | Políticas complejas de acceso             | JWT básico es suficiente                |
| Won't Have (por ahora) | RF-28 | Invalidación avanzada de tokens en logout | No crítico en MVP                       |
