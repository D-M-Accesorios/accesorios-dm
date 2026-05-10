# ADR-008: Estrategia de Versionamiento de APIs

| Campo       | Valor                                |
|-------------|--------------------------------------|
| **ID**      | ADR-008                              |
| **Título**  | Estrategia de Versionamiento de APIs |
| **Estado**  | Accepted                             |
| **Fecha**   | 2026-05-10                           |
| **Autor**   | Sergio Andrés Losada Bahamón (SALB)  |
| **Revisión**| —                                    |

---

## 1. Contexto

El sistema expone APIs REST consumidas por múltiples clientes (portal Angular y
app móvil). A medida que el sistema evoluciona, los contratos de API cambiarán:
se añadirán campos, se modificarán estructuras o se eliminarán endpoints.

Sin una estrategia de versionamiento, cualquier cambio en la API puede romper
silenciosamente los clientes activos, generando errores en producción difíciles
de rastrear y forzando deployments coordinados y riesgosos entre frontend y
backend.

Se necesita una estrategia que:

- Permita evolucionar la API sin romper clientes existentes.
- Sea simple de implementar y entender por el equipo.
- Sea consistente en todos los servicios del sistema.
- Facilite la deprecación ordenada de versiones antiguas.

---

## 2. Decisión

**Se adopta versionamiento por URI (URL path versioning) con el prefijo `/api/vN/`
como parte de la ruta de todos los endpoints del sistema.**

```
https://api.accesorios-dm.com/api/v1/inventory/products
https://api.accesorios-dm.com/api/v1/auth/login
https://api.accesorios-dm.com/api/v1/catalog/categories
```

La versión actual del sistema es **v1**. Esta es la única versión activa.

---

## 3. Justificación de URL Path Versioning

### Alternativas evaluadas y razones de elección

| Estrategia               | Ejemplo                                  | Descartada por                                        |
|--------------------------|------------------------------------------|-------------------------------------------------------|
| **URI Versioning** ✅    | `/api/v1/products`                       | **Elegida** — simple, visible, cacheable              |
| Header Versioning        | `Accept: application/vnd.dm.v1+json`     | Invisible en URL, complica el uso desde herramientas  |
| Query Param Versioning   | `/products?version=1`                    | Mezcla parámetros de negocio con parámetros de API    |
| Content Negotiation      | `Accept-Version: v1`                     | Soporte limitado en frameworks, menos estándar        |

**URL path versioning** es la opción más explícita, fácil de entender, compatible
con todos los clientes, cacheable por proxies y soportada nativamente por NestJS
y Spring Boot sin configuración adicional.

---

## 4. Estructura de URLs del Sistema

### 4.1 Patrón general

```
/api/{versión}/{servicio}/{recurso}/{identificador?}/{sub-recurso?}
```

### 4.2 Convenciones de nomenclatura de rutas

| Regla | Correcto | Incorrecto |
|---|---|---|
| Sustantivos en plural para colecciones | `/products` | `/getProducts`, `/product` |
| Kebab-case para rutas con múltiples palabras | `/product-images` | `/productImages`, `/product_images` |
| Identificadores en la ruta para recursos específicos | `/products/{id}` | `/products?id={id}` |
| Acciones de negocio como sub-recursos | `/products/{id}/activate` | `/activateProduct/{id}` |
| Sin trailing slash | `/products` | `/products/` |

### 4.3 Mapa de rutas por servicio (v1)

**Security Service (via Gateway)**
```
POST   /api/v1/auth/login
POST   /api/v1/auth/register
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
GET    /api/v1/auth/me
PUT    /api/v1/auth/me/password

GET    /api/v1/users                    (ADMIN)
GET    /api/v1/users/{id}              (ADMIN)
PUT    /api/v1/users/{id}/roles        (ADMIN)
PATCH  /api/v1/users/{id}/status      (ADMIN)

GET    /api/v1/roles                   (ADMIN)
POST   /api/v1/roles                   (ADMIN)
```

**Inventory Service (via Gateway)**
```
GET    /api/v1/catalog/categories
GET    /api/v1/catalog/categories/{id}
POST   /api/v1/catalog/categories       (ADMIN)
PUT    /api/v1/catalog/categories/{id}  (ADMIN)
DELETE /api/v1/catalog/categories/{id}  (ADMIN)

GET    /api/v1/catalog/products
GET    /api/v1/catalog/products/{id}
POST   /api/v1/catalog/products         (ADMIN)
PUT    /api/v1/catalog/products/{id}    (ADMIN)
DELETE /api/v1/catalog/products/{id}    (ADMIN)
GET    /api/v1/catalog/products/{id}/images

GET    /api/v1/inventory/movements
POST   /api/v1/inventory/movements      (ADMIN/VENDEDOR)
GET    /api/v1/inventory/stock
GET    /api/v1/inventory/stock/{productId}
```

**Gateway — Health & Status**
```
GET    /api/v1/health
GET    /api/v1/health/services
```

> Este mapa es orientativo para la planeación. El detalle completo de cada
> endpoint se especifica en los contratos OpenAPI de cada servicio.

---

## 5. Política de Evolución de la API

### 5.1 Cambios no disruptivos (backward compatible) — sin nueva versión

Estos cambios se pueden hacer en v1 sin crear v2:

- Agregar nuevos campos opcionales en respuestas.
- Agregar nuevos endpoints.
- Agregar nuevos query params opcionales.
- Mejorar mensajes de error sin cambiar el código de error.
- Cambios internos que no afecten el contrato externo.

### 5.2 Cambios disruptivos (breaking changes) — requieren nueva versión

Estos cambios requieren crear `/api/v2/`:

- Eliminar o renombrar campos en respuestas que ya existen.
- Cambiar el tipo de un campo existente.
- Cambiar la estructura de un endpoint existente.
- Eliminar un endpoint existente.
- Cambiar los códigos de error de respuestas existentes.
- Hacer obligatorio un campo que antes era opcional.

### 5.3 Proceso de creación de una nueva versión

Cuando sea necesario crear v2:

1. El endpoint nuevo se implementa bajo `/api/v2/`.
2. El endpoint v1 equivalente se marca como **deprecated** en el contrato OpenAPI.
3. Se comunica al equipo de frontend con al menos **2 semanas de anticipación**.
4. Se define una fecha de **sunset** (fecha máxima en que v1 dejará de funcionar).
5. v1 se mantiene funcional hasta que todos los clientes migren a v2.
6. En la fecha de sunset, v1 devuelve `410 Gone` con un mensaje de migración.

---

## 6. Versionamiento de Contratos OpenAPI

Cada servicio mantiene su especificación OpenAPI versionada:

```
docs/
└── api-contracts/
    ├── inventory-service-v1.yaml
    ├── security-service-v1.yaml
    └── gateway-v1.yaml
```

Los contratos son la fuente de verdad del contrato de API. Todo cambio en la
API debe reflejarse primero en el contrato antes de ser implementado.

---

## 7. Consecuencias

### 7.1 Consecuencias Positivas

- Clientes existentes no se rompen cuando evoluciona la API.
- La versión es explícita, visible y auditable en logs.
- Compatible con herramientas de testing, documentación y API clients.
- El equipo puede iterar rápido en v1 sabiendo que tiene un mecanismo de escape.

### 7.2 Consecuencias Negativas

- Mantener múltiples versiones activas incrementa la deuda de código.
- Requiere disciplina para deprecar y eliminar versiones antiguas a tiempo.
- El prefijo `/api/v1/` añade un segmento fijo a todas las URLs.

---

## 8. Reglas Derivadas

| # | Regla                                                                                          | Alcance          |
|---|------------------------------------------------------------------------------------------------|------------------|
| R1 | Todos los endpoints del sistema usan el prefijo `/api/v1/`                                    | Código, contratos|
| R2 | Las rutas usan sustantivos en plural, kebab-case y sin trailing slash                          | Código, contratos|
| R3 | Los cambios disruptivos requieren nueva versión de API, nunca modifican la versión activa      | Proceso, código  |
| R4 | Todo nuevo endpoint se documenta en el contrato OpenAPI antes de implementarse                 | Proceso, docs    |
| R5 | La deprecación de una versión se comunica al frontend con mínimo 2 semanas de anticipación    | Proceso          |
| R6 | Las URLs de los endpoints no contienen verbos (se usan métodos HTTP para las acciones)        | Código, contratos|

---

## 9. Condiciones de Revisión Futura

1. **Necesidad de v2**: cuando se identifique el primer cambio disruptivo necesario,
   se activa el proceso de versioning definido en la sección 5.3.
2. **Adopción de GraphQL**: si el sistema requiere consultas flexibles para el
   frontend (reducir over-fetching en catálogo con muchos productos), se evalúa
   GraphQL como complemento a la API REST existente, no como reemplazo.

---

## 10. Referencias

- RESTful API Design Best Practices — Microsoft Azure API Guidelines
- OpenAPI Specification 3.1
- NestJS — Versioning
- Spring Boot — Request Mapping y Path Variables
- ADR-002: API Gateway Custom con NestJS
- ADR-009: Formato Estándar de Errores HTTP
