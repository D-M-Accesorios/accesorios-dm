\# Backlog del proyecto ACCESORIOS DM - Corte 2



Este backlog consolida las historias de usuario y el alcance funcional del proyecto para el segundo corte, alineado con la arquitectura implementada y los requerimientos funcionales definidos.



\---



\## HU-01. Arquitectura base e integración inicial



\*\*Descripción\*\*  

Como equipo de desarrollo, queremos contar con una arquitectura base distribuida del ecommerce, para permitir la comunicación entre frontend, API Gateway e inventory-service.



\*\*Objetivo\*\*  

Establecer la base técnica del sistema mediante la separación de responsabilidades por servicios y la integración inicial entre los componentes principales.



\*\*Repositorios involucrados\*\*

\- accesorios-dm-frontend

\- accesorios-dm-api-gateway

\- accesorios-dm-inventory-service



**\*\*Estado\*\***

**Implementada**



\*\*Entregables asociados\*\*

\- Frontend base funcional

\- API Gateway configurado

\- Inventory Service conectado

\- Integración inicial entre servicios

\- Configuración base con Docker



\---



\## HU-02. Catálogo e inventario



\*\*Descripción\*\*  

Como usuario, quiero visualizar el catálogo de productos desde el frontend consumiendo el API Gateway, para consultar la información del ecommerce de forma centralizada.



\*\*Requerimientos funcionales asociados\*\*

\- RF-07: El sistema debe permitir crear productos.

\- RF-08: El sistema debe permitir actualizar productos.

\- RF-09: El sistema debe permitir eliminar productos.

\- RF-10: El sistema debe listar los productos disponibles.

\- RF-11: El sistema debe permitir gestionar categorías de productos.

\- RF-12: El sistema debe gestionar el stock de cada producto.

\- RF-13: El sistema debe validar disponibilidad de stock antes de agregar productos al carrito.

\- RF-24: El sistema debe mostrar el catálogo de productos.

\- RF-26: El sistema debe permitir la administración de productos desde la interfaz (parcial).



\*\*Objetivo\*\*  

Permitir la exposición y consulta del catálogo de productos integrando frontend, gateway e inventario.



\*\*Repositorios involucrados\*\*

\- accesorios-dm-frontend

\- accesorios-dm-api-gateway

\- accesorios-dm-inventory-service



**\*\*Estado\*\***

**En desarrollo / implementada en ramas feature**



\*\*Entregables asociados\*\*

\- Consumo de catálogo desde frontend

\- Rutas de catálogo en API Gateway

\- Lógica de inventario en backend

\- Configuración de despliegue de los servicios involucrados



\---



\## HU-03. Base del servicio de carrito y pagos



\*\*Descripción\*\*  

Como equipo de desarrollo, queremos construir la base del servicio de carrito y pagos, para soportar el futuro flujo de compra del ecommerce.



\*\*Requerimientos funcionales asociados\*\*

\- RF-14: El sistema debe permitir agregar productos al carrito de compra.

\- RF-15: El sistema debe permitir modificar la cantidad de productos en el carrito.

\- RF-16: El sistema debe permitir eliminar productos del carrito.

\- RF-17: El sistema debe calcular automáticamente el total del carrito.

\- RF-18: El sistema debe persistir el carrito asociado a un usuario autenticado.

\- RF-19: El sistema debe permitir configurar los métodos de pago disponibles.

\- RF-20: El sistema debe permitir registrar una orden de compra.

\- RF-21: El sistema debe registrar el estado del pago asociado a una orden.

\- RF-22: El sistema debe actualizar el estado de la orden.

\- RF-23: El sistema debe permitir parametrizar impuestos o recargos aplicables.

\- RF-27: El sistema debe mostrar un resumen de compra antes de confirmar el pago.



\*\*Objetivo\*\*  

Implementar la base funcional y técnica del flujo de carrito, órdenes y pagos.



\*\*Repositorios involucrados\*\*

\- accesorios-dm-payment-service

\- accesorios-dm-frontend



\*\*Estado\*\*

Implementada



\---



\## HU-04. Seguridad y autenticación



\*\*Descripción\*\*  

Como usuario, quiero registrarme e iniciar sesión con autenticación basada en JWT y roles, para acceder de forma segura al sistema.



\*\*Requerimientos funcionales asociados\*\*

\- RF-01: El sistema debe permitir el registro de usuarios.

\- RF-02: El sistema debe permitir el inicio de sesión mediante usuario y contraseña.

\- RF-03: El sistema debe generar y validar tokens JWT para autenticación.

\- RF-04: El sistema debe manejar roles de usuario (ADMIN y CLIENTE).

\- RF-05: El sistema debe permitir la asignación de roles a usuarios.

\- RF-06: El sistema debe restringir el acceso a endpoints según el rol del usuario.

\- RF-25: El sistema debe permitir autenticación desde la interfaz web.

\- RF-28: El sistema debe permitir cerrar sesión.



\*\*Objetivo\*\*  

Definir e implementar el módulo de autenticación y autorización del sistema.



\*\*Repositorios involucrados\*\*

\- accesorios-dm-security-service

\- accesorios-dm-frontend



\*\*Estado\*\*

Pendiente



\---



\## Observaciones de planificación



\- La \*\*HU-01\*\* corresponde a la base arquitectónica inicial ya implementada.

\- La \*\*HU-02\*\* agrupa el trabajo funcional de catálogo e inventario actualmente integrado entre frontend, gateway e inventory-service.

\- La \*\*HU-03\*\* y la \*\*HU-04\*\* quedan definidas como siguientes iteraciones del proyecto.

\- La estrategia de ramas adoptada para el proyecto es:



`feature/\* -> develop -> qa -> release -> main`

