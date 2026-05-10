# HU-DEV-SALB_10 — Configuración base del proyecto Spring Boot (Inventory Service)

| Campo              | Valor                                          |
|--------------------|------------------------------------------------|
| **ID**             | HU-DEV-SALB_10                                 |
| **Servicio**       | Inventory Service                              |
| **Repositorio**    | `accesorios-dm-inventory-service`              |
| **Prioridad**      | Crítica                                        |
| **Estado**         | Pendiente                                      |
| **ADRs**           | ADR-005, ADR-008                               |
| **Rama**           | `HU-DEV-SALB_10`                               |
| **Fecha**          | 2026-05-10                                     |

---

## Historia de Usuario

> **Como** equipo de desarrollo,
> **quiero** tener la estructura base del Inventory Service configurada y lista,
> **para** tener un punto de partida consistente, alineado con los estándares
> del proyecto antes de desarrollar cualquier funcionalidad de negocio.

---

## Criterios de Aceptación

- [ ] Spring Boot 3 configurado con Java 21, Spring Data JPA, Spring Web, Spring Validation y Lombok.
- [ ] La conexión a PostgreSQL usa el usuario `svc_inventory` con permisos **exclusivamente** sobre los schemas `catalogo` e `inventario` (ADR-005).
- [ ] El `search_path` de JPA está configurado para los schemas `catalogo,inventario`.
- [ ] El prefijo base de las rutas es `/api/v1` configurado en `application.yml`.
- [ ] Existe un `Dockerfile` multi-stage para el servicio.
- [ ] El servicio tiene entrada en `docker-compose.yml` con nombre `inventory-service` y puerto `8082`.
- [ ] Todas las variables de entorno requeridas están documentadas en `application.yml` con valores leídos de variables de entorno.
- [ ] El servicio arranca correctamente en el puerto `8082`.
- [ ] El endpoint `GET /api/v1/health` responde `200 OK` (spring-boot-actuator).
- [ ] Existe un `README.md` del servicio con instrucciones de setup local.

---

## Variables de Entorno Requeridas

```
SERVER_PORT=8082
SPRING_PROFILES_ACTIVE=dev

# Base de datos
DB_HOST=postgres
DB_PORT=5432
DB_NAME=accesorios_dm
DB_USERNAME=svc_inventory
DB_PASSWORD=<secret>
DB_SCHEMA=catalogo,inventario
```

---

## Estructura de Paquetes Propuesta

```
com.accesorios.dm.inventory/
├── InventoryServiceApplication.java
├── config/
│   └── JpaConfig.java
├── common/
│   ├── exception/
│   │   ├── GlobalExceptionHandler.java     (HU-DEV-SALB_11)
│   │   ├── ProductNotFoundException.java
│   │   └── InsufficientStockException.java
│   └── dto/
│       └── ErrorResponseDto.java           (ADR-009)
├── catalog/
│   ├── controller/                          (HU-DEV-SALB_12, 13, 14, 15)
│   ├── service/
│   ├── repository/
│   ├── entity/
│   └── dto/
└── inventory/
    ├── controller/                          (HU-DEV-SALB_16, 17, 18)
    ├── service/
    ├── repository/
    ├── entity/
    └── dto/
```

---

## Notas Técnicas

- Usar `spring-boot-starter-actuator` para el health check.
- Configurar `spring.jpa.properties.hibernate.default_schema` y `spring.datasource.hikari.connection-init-sql` para forzar el `search_path` correcto.
- El usuario `svc_inventory` no debe tener permisos en otros schemas. Verificar con un query de prueba al arrancar en modo desarrollo.
- `spring.jpa.hibernate.ddl-auto=validate` en todos los entornos — Liquibase gestiona el schema, no Hibernate.
- Lombock reduce el boilerplate en entidades y DTOs.

---

## Dependencias

| Tipo | HU / Artefacto | Descripción |
|---|---|---|
| Ninguna (primera HU del servicio) | — | Esta HU desbloquea todas las del Inventory Service |
| Externa | PostgreSQL con schemas `catalogo` e `inventario` creados | La BD ya está refactorizada |

---

## Desbloquea

`HU-DEV-SALB_11`, `HU-DEV-SALB_12`, `HU-DEV-SALB_13`, `HU-DEV-SALB_14`, `HU-DEV-SALB_15`, `HU-DEV-SALB_16`, `HU-DEV-SALB_17`, `HU-DEV-SALB_18`

---

## Definición de Done

- [ ] Código revisado y aprobado por al menos 1 reviewer.
- [ ] El servicio levanta con `docker-compose up inventory-service`.
- [ ] `GET /api/v1/health` responde `200`.
- [ ] Verificado que el usuario `svc_inventory` no puede acceder a schemas ajenos.
- [ ] No hay secretos en el repositorio.
- [ ] PR mergeado a `develop`.
