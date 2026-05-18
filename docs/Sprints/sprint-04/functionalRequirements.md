# 1. Seguridad (Security Service)

- **_RF-01:_** El sistema debe permitir el registro de usuarios.
- **_RF-02:_** El sistema debe permitir el inicio de sesión mediante usuario y contraseña.
- **_RF-03:_** El sistema debe generar y validar tokens JWT para autenticación.
- **_RF-04:_** El sistema debe manejar roles de usuario (ADMIN y CLIENTE).
- **_RF-05:_** El sistema debe permitir la asignación de roles a usuarios.
- **_RF-06:_** El sistema debe restringir el acceso a endpoints según el rol del usuario.

# 2. Inventario (Inventory Service)

- **_RF-07:_** El sistema debe permitir crear productos.
- **_RF-08:_** El sistema debe permitir actualizar productos.
- **_RF-09:_** El sistema debe permitir eliminar productos.
- **_RF-10:_** El sistema debe listar los productos disponibles.
- **_RF-11:_** El sistema debe permitir gestionar categorías de productos.
- **_RF-12:_** El sistema debe gestionar el stock de cada producto.
- **_RF-13:_** El sistema debe validar disponibilidad de stock antes de agregar productos al carrito.

# 3. Carrito de Compras

- **_RF-14_** El sistema debe permitir agregar productos al carrito de compra.
- **_RF-15_** El sistema debe permitir modificar la cantidad de productos en el carrito.
- **_RF-16_** El sistema debe permitir eliminar productos del carrito.
- **_RF-17_** El sistema debe calcular automáticamente el total del carrito.
- **_RF-18_** El sistema debe persistir el carrito asociado a un usuario autenticado.

# 4. Pago y Parametrización (Payment Service)

- **_RF-19_** El sistema debe permitir configurar los métodos de pago disponibles.
- **_RF-20_** El sistema debe permitir registrar una orden de compra.
- **_RF-21_** El sistema debe registrar el estado del pago asociado a una orden.
- **_RF-22_** El sistema debe actualizar el estado de la orden (CREATED, PAID, CANCELLED).
- **_RF-23_** El sistema debe permitir parametrizar impuestos o recargos aplicables.

# 5. Frontend (Angular)

- **_RF-24_** El sistema debe mostrar el catálogo de productos.
- **_RF-25_** El sistema debe permitir autenticación desde la interfaz web.
- **_RF-26_** El sistema debe permitir la administración de productos desde la interfaz (rol ADMIN).
- **_RF-27_** El sistema debe mostrar un resumen de compra antes de confirmar el pago.
- **_RF-28_** El sistema debe permitir cerrar sesión.
