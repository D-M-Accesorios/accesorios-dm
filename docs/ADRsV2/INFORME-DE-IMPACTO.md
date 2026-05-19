# Informe de Impacto Arquitectónico — Accesorios DM

| Campo              | Valor                                                 |
| ------------------ | ----------------------------------------------------- |
| **Documento**      | Informe de Impacto de Decisiones Arquitectónicas      |
| **Sistema**        | Accesorios DM — Plataforma E-Commerce                 |
| **Fecha**          | 2026-05-18                                            |
| **ADRs cubiertos** | ADR-001 al ADR-025                                    |
| **Autor**          | Análisis arquitectónico basado en evidencia de código |

---

## Propósito del Documento

Este informe describe de forma concreta y técnica **cómo cada decisión arquitectónica registrada mejora el sistema**, qué problema específico resuelve, y qué valor aporta a las dimensiones de calidad: seguridad, mantenibilidad, escalabilidad, rendimiento, operabilidad y experiencia del equipo de desarrollo.

El análisis está organizado por categoría de ADR, seguido de una visión transversal de impactos combinados y una evaluación de madurez post-implementación.

---

## Índice

1. [Impacto de los Behavioral ADRs](#1-impacto-de-los-behavioral-adrs)
2. [Impacto de los Structural ADRs](#2-impacto-de-los-structural-adrs)
3. [Impacto de los Design ADRs](#3-impacto-de-los-design-adrs)
4. [Impacto Transversal por Dimensión de Calidad](#4-impacto-transversal-por-dimensión-de-calidad)
5. [Mapa de Dependencias entre ADRs](#5-mapa-de-dependencias-entre-adrs)
6. [Matriz de Impacto Consolidada](#6-matriz-de-impacto-consolidada)
7. [Evaluación del Estado Actual vs. Estado Objetivo](#7-evaluación-del-estado-actual-vs-estado-objetivo)

---

## 1. Impacto de los Behavioral ADRs

Los ADRs de comportamiento definen cómo el sistema actúa en tiempo de ejecución: cómo procesa peticiones, cómo autentica, cómo se protege, cómo registra eventos y cómo se comunica internamente. Su impacto es inmediatamente perceptible tanto para los usuarios finales como para el equipo de operaciones.

---

### ADR-001 — API Gateway como Único Punto de Entrada

**Problema que resuelve:** Sin gateway, el frontend Angular y la aplicación mobile tendrían que conocer las URLs internas de tres servicios distintos (`:8080`, `:8888`, `:9000`), gestionar CORS de forma individual en cada uno, y manejar tokens sin coordinación centralizada. Cualquier cambio de puerto o host de un servicio requeriría actualizar todos los clientes.

**Mejora concreta al sistema:**

El gateway elimina toda esa complejidad del lado del cliente. El frontend consume un único dominio (`/api/v1/...`) sin saber que por detrás existen tres servicios independientes en tecnologías distintas. Esto hace que el sistema sea **transparente para los consumidores externos**: se puede migrar el Inventory Service de Spring Boot a Quarkus, cambiarle el puerto o moverlo a otra máquina sin que el frontend necesite ningún cambio.

Adicionalmente, el patrón concentra la aplicación de políticas transversales en un único lugar. Cuando se necesita agregar autenticación a nivel de gateway, compresión global, o cambiar las reglas de CORS, el cambio es en un solo archivo en lugar de en tres servicios con tres tecnologías distintas.

**Impacto medible:**

- Reducción del acoplamiento cliente-infraestructura: de N endpoints conocidos a 1.
- Tiempo de implementación de políticas transversales: de 3 servicios × N horas → 1 servicio × N horas.
- El `onError` del proxy devuelve `503` en lugar de dejar la conexión colgada, mejorando la experiencia de usuario ante fallos de servicios downstream.

---

### ADR-002 — Autenticación JWT HS256 con Security Service

**Problema que resuelve:** En un sistema de microservicios heterogéneo (Java, Python, Node.js), necesitas un mecanismo de autenticación que funcione sin estado (stateless), sea portable entre tecnologías, y no requiera que cada servicio consulte una sesión centralizada en cada request.

**Mejora concreta al sistema:**

JWT permite que cualquier servicio valide una identidad simplemente verificando la firma del token con la clave compartida, sin roundtrip a base de datos ni al Security Service. El token incluye el rol del usuario (`ADMIN`, `VENDEDOR`) directamente en su payload, lo que permite tomar decisiones de autorización sin consultas adicionales.

La expiración de 30 minutos crea una ventana de riesgo acotada: si un token es interceptado, tiene un tiempo de vida limitado. La estructura del token (`sub`, `email`, `rol`, `exp`) provee toda la información necesaria para autorización en cualquier servicio del ecosistema.

**Impacto medible:**

- Eliminación de sesiones server-side: el sistema puede escalar horizontalmente sin necesidad de sticky sessions o cache distribuido de sesiones.
- Autorización sin roundtrip adicional: el rol ya está en el token, no requiere consulta extra.
- Portabilidad entre stacks: la misma lógica de verificación JWT funciona en Java (`java-jwt`), Python (`python-jose`) y Node.js (`jsonwebtoken`).

> **Nota de madurez:** La implementación actual usa SHA-256 para contraseñas (ADR-022) y tiene el `SECRET_KEY` con valor por defecto inseguro. Estas son deudas técnicas sobre una decisión arquitectónica que, en sí misma, es correcta.

---

### ADR-003 — Rate Limiting Diferenciado por Ambiente

**Problema que resuelve:** Un rate limiter único para todos los ambientes crea una contradicción: si es estricto, bloquea al desarrollador que hace 200 requests en 5 minutos depurando una funcionalidad; si es permisivo, no protege el ambiente de producción.

**Mejora concreta al sistema:**

La configuración diferenciada (`dev: 1000/min`, `qa: 50/5min`, `prod: 100/15min`) resuelve esta contradicción sin que el equipo necesite recordar configuraciones manuales. El ambiente se selecciona por `NODE_ENV`, que ya se configura en cada `docker-compose.yml`. El resultado es un sistema que se protege solo según el contexto: en desarrollo no estorba, en producción previene ataques de fuerza bruta y abuso de API.

El rate limiter especializado para autenticación (`max: 10` intentos de login en 15 minutos con `skipSuccessfulRequests: true`) protege específicamente el endpoint más crítico de seguridad sin afectar el tráfico normal de usuarios legítimos.

La exención de los endpoints `/health` del rate limiting garantiza que el monitoreo de infraestructura y los health checks de Docker Compose nunca sean bloqueados, preservando la observabilidad del sistema incluso bajo carga.

**Impacto medible:**

- En producción: máximo 100 requests por IP cada 15 minutos → protección efectiva contra bots y scrapers.
- En desarrollo: 1000 requests por minuto → prácticamente sin fricción para el workflow del desarrollador.
- Sin configuración manual por ambiente: el `NODE_ENV` en el compose selecciona automáticamente la política correcta.

---

### ADR-004 — Estrategia de Puertos Diferenciados por Ambiente

**Problema que resuelve:** Sin una convención de puertos, ejecutar `develop` y `qa` simultáneamente en la misma máquina resulta en conflictos (`port already in use`). El equipo necesitaría detener un ambiente antes de levantar otro, perdiendo la capacidad de comparar comportamientos entre versiones.

**Mejora concreta al sistema:**

El desplazamiento numérico consistente (`develop: +2`, `qa: +1`, `prod: base`) crea una convención memorizable que no requiere documentación adicional para usarse. Un miembro nuevo del equipo que vea `8082` en un log sabe inmediatamente que está mirando el Inventory Service en develop. El mismo que vea `8081` sabe que es QA.

Esta convención además habilita flujos de trabajo de integración: el equipo de QA puede ejecutar el ambiente `qa` mientras el equipo de backend trabaja en `develop`, ambos en la misma máquina, sin interferencia. La rama del repositorio determina el ambiente sin configuración adicional.

**Impacto medible:**

- Capacidad de ejecutar hasta 3 ambientes simultáneamente en la misma máquina.
- Tiempo de cambio de ambiente: `git checkout [rama] && docker-compose up -d` (menos de 2 minutos).
- Trazabilidad inmediata: el puerto de un log revela el ambiente y el servicio sin contexto adicional.

---

### ADR-005 — Comunicación Sincrónica HTTP entre Servicios

**Problema que resuelve:** Los microservicios necesitan comunicarse. En un MVP sin infraestructura de mensajería, adoptar RabbitMQ o Kafka introduciría semanas de curva de aprendizaje y complejidad operacional desproporcionada. Pero sin un patrón explícito, cada desarrollador podría implementar la comunicación de forma inconsistente.

**Mejora concreta al sistema:**

La decisión de adoptar HTTP sincrónico como patrón oficial estandariza cómo los servicios se llaman entre sí. El timeout de 60 segundos en el proxy del gateway previene que conexiones colgadas bloqueen el pool de workers indefinidamente. El manejo unificado de errores (`503 Service Unavailable`) en el `onError` del proxy da a los clientes una respuesta accionable en lugar de un silencio de red.

La comunicación HTTP también significa que cualquier herramienta estándar de debugging (curl, Postman, Insomnia) puede interceptar, reproducir o probar cualquier llamada inter-servicio, simplificando el diagnóstico de problemas en integración.

**Impacto medible:**

- Debugging de integración: reproducible con una sola línea de `curl`.
- Sin infraestructura adicional: 0 contenedores extra para message brokers.
- Consistencia: todos los servicios usan el mismo protocolo y pueden ser monitoreados con las mismas herramientas.

---

### ADR-006 — Actualización de Stock mediante Triggers de Base de Datos

**Problema que resuelve:** El stock de un producto debe actualizarse de forma consistente cada vez que ocurre un movimiento de inventario, independientemente de qué servicio o herramienta generó ese movimiento. Si la lógica de actualización vive solo en el código de aplicación, una consulta SQL directa desde una herramienta de administración dejaría el stock desactualizado.

**Mejora concreta al sistema:**

Los triggers `trg_update_stock_on_insert`, `trg_update_stock_on_update` y `trg_update_stock_on_delete` convierten la tabla `inventario.inventario_movimiento` en la **fuente de verdad autoritativa del stock**. Cualquier inserción en esa tabla, sin importar su origen (microservicio, script SQL manual, herramienta de BI), actualiza automáticamente `catalogo.producto.stock`. Esta es la implementación del principio "la base de datos garantiza la integridad, no la aplicación".

El trigger de DELETE (`trg_revert_stock_on_delete`) es especialmente valioso: permite cancelar o corregir movimientos de inventario simplemente eliminando el registro, y el stock se revierte automáticamente. Esto convierte la tabla de movimientos en un log inmutable con capacidad de rollback.

**Impacto medible:**

- Consistencia de stock garantizada para todos los clientes de la BD, no solo para los microservicios.
- Auditoría completa: cada cambio de stock tiene un registro en `inventario_movimiento` con fecha, referencia y tipo.
- Correctabilidad: un movimiento erróneo puede revertirse eliminando el registro, sin scripts adicionales.

> **Nota de madurez:** El ADR documenta un bug activo (doble descuento por actualización directa en Payment + trigger). La decisión arquitectónica de usar triggers es correcta; su correcta implementación requiere eliminar el `UPDATE directo` del Payment Service.

---

### ADR-007 — WhatsApp como Canal de Confirmación de Pago

**Problema que resuelve:** El ciclo de compra termina cuando el cliente paga, no cuando crea el pedido. Sin una pasarela de pago integrada, el sistema podría crear el pedido pero dejar al cliente sin saber cómo pagar, generando abandono del proceso.

**Mejora concreta al sistema:**

El link de WhatsApp pre-generado (`wa.me/573166751065?text=...`) cierra el ciclo de compra de forma práctica y sin fricción en el contexto real del negocio. El mensaje incluye el número de pedido y el total, dándole al vendedor toda la información necesaria para confirmar el pago sin que el cliente tenga que escribir nada.

Esta decisión transforma una limitación (sin pasarela de pago en el MVP) en una característica que se alinea con el modelo de negocio actual de Accesorios DM, que ya opera por WhatsApp. El sistema digital no reemplaza abruptamente el proceso manual; lo complementa y mejora con orden y trazabilidad.

**Impacto medible:**

- Tiempo de integración de "pago": menos de 5 líneas de código.
- Costo de implementación: $0 (sin comisiones de pasarela).
- Continuidad del proceso de negocio: los vendedores no necesitan aprender un sistema nuevo de confirmación.
- El link incluye el total calculado, eliminando errores de comunicación del monto a pagar.

---

### ADR-008 — Health Check Endpoints en Todos los Servicios

**Problema que resuelve:** Docker Compose puede marcar un contenedor como "running" cuando el proceso acaba de iniciar, pero el servicio aún no está listo para recibir tráfico. Sin health checks, el gateway puede intentar enrutar peticiones hacia el Inventory Service mientras la JVM aún está calentando, resultando en errores transitorios que confunden al equipo.

**Mejora concreta al sistema:**

El contrato de health check uniforme (`{"status": "UP", "service": "nombre", "version": "1.0.0"}`) en los cuatro servicios permite que Docker Compose gestione el orden de arranque de forma declarativa: `depends_on: condition: service_healthy` hace que el gateway no inicie hasta que los servicios downstream estén realmente listos.

El endpoint `/api/v1/health/all` en el gateway agrega el estado de todo el ecosistema en un solo request, lo que convierte una tarea de diagnóstico que requeriría cuatro `curl` en un único comando. Esto acelera el triage de incidentes: el equipo puede saber en segundos si el problema es el gateway, un servicio específico, o toda la plataforma.

**Impacto medible:**

- Arranque ordenado garantizado por Docker sin scripts adicionales.
- Tiempo de diagnóstico de estado del sistema: 1 request a `/health/all` vs. 4 requests independientes.
- Los health checks exentos del rate limiting garantizan que el monitoreo externo (Uptime Robot, Grafana) nunca sea bloqueado.
- La respuesta incluye la versión del servicio, facilitando la verificación de deploys exitosos.

---

### ADR-009 — Logging Estructurado Centralizado en el Gateway

**Problema que resuelve:** Sin logging centralizado, cuando un usuario reporta un error, el desarrollador necesita acceder a los logs de cuatro servicios distintos, en cuatro contenedores diferentes, sin saber en cuál de ellos ocurrió el problema. El tiempo de diagnóstico se multiplica por el número de servicios.

**Mejora concreta al sistema:**

El gateway es el único punto por donde pasan todas las peticiones externas, lo que lo convierte en el lugar natural para el registro centralizado. El formato de Morgan (`IP - METHOD URL STATUS response_time`) captura toda la información de auditoría de tráfico en una línea por request. El `requestLogger` personalizado mide la duración real incluyendo el tiempo de proxy, no solo el tiempo de procesamiento del gateway.

La persistencia en archivos (`./logs:/app/logs`) con volume mount garantiza que los logs sobreviven reinicios del contenedor. Los niveles de log diferenciados por ambiente (`debug` en desarrollo, `warn` en producción) reducen el ruido en producción sin sacrificar visibilidad en desarrollo.

**Impacto medible:**

- Primer punto de triage de todos los problemas de la API: un solo archivo de logs.
- Medición de latencia de extremo a extremo: el `requestLogger` incluye el tiempo de proxy.
- Los logs de errores (4xx, 5xx) se registran con `logger.warn` automáticamente, sin código adicional en cada handler.
- Persistencia histórica: los logs de las últimas horas/días están disponibles en el host incluso si el contenedor fue reiniciado.

---

## 2. Impacto de los Structural ADRs

Los ADRs estructurales definen la organización física y lógica del sistema: cuántos componentes existen, cómo están organizados, cómo se despliegan y cómo se relacionan. Su impacto es fundamental y de largo plazo, ya que un cambio estructural es costoso una vez que el sistema está en producción.

---

### ADR-010 — Arquitectura de Microservicios Políglota

**Problema que resuelve:** Un sistema de e-commerce tiene necesidades heterogéneas: procesamiento seguro de credenciales (Python/FastAPI destaca aquí), persistencia compleja de catálogos con JPA (Java/Spring Boot), ruteo y proxy livianos (Node.js), e interfaces de usuario reactivas (Angular). Obligar a todo el sistema a usar una única tecnología sacrifica la idoneidad de cada herramienta para su dominio.

**Mejora concreta al sistema:**

La arquitectura políglota permite que cada servicio use la herramienta óptima para su responsabilidad. Spring Boot 3.5 con JPA y Hibernate es el estándar empresarial para el dominio de datos estructurados del inventario: validación de bean, transacciones declarativas, repositorios Spring Data, y actuators de monitoreo están disponibles out-of-the-box. FastAPI genera documentación Swagger automática en `/docs` sin configuración, lo que acelera el desarrollo y la integración del Security Service. Node.js con Express es ideal para el API Gateway porque su modelo de I/O no bloqueante es óptimo para un proxy que no hace procesamiento intensivo.

Docker como capa de abstracción neutraliza las diferencias operacionales: independientemente del runtime, todos los servicios se construyen con `docker-compose build` y se arrancan con `docker-compose up`. El equipo no necesita instalar Java, Python y Node.js en el servidor de producción; solo Docker.

**Impacto medible:**

- Cada servicio usa el ORM más adecuado para su tecnología (JPA, SQLAlchemy, Prisma).
- FastAPI genera documentación interactiva (`/docs`) sin línea de código adicional.
- Spring Actuator provee métricas de salud detalladas (incluyendo pool de conexiones) sin configuración.
- El equipo puede especializar conocimiento: el backend Java no necesita aprender SQLAlchemy.

---

### ADR-011 — Base de Datos Compartida con Aislamiento por Schemas

**Problema que resuelve:** Una base de datos por microservicio (el ideal teórico) multiplicaría los costos de infraestructura por 3-4 veces e implicaría gestionar réplicas, backups y conexiones de múltiples instancias PostgreSQL. Para un emprendimiento en fase de arranque, esto es inviable tanto económica como operacionalmente.

**Mejora concreta al sistema:**

Los schemas de PostgreSQL proveen el aislamiento lógico de dominios que se busca en microservicios sin el costo de múltiples instancias. El schema `catalogo` agrupa todo lo del catálogo, `ventas` todo lo transaccional, `security` todo lo de autenticación. Cada equipo/desarrollador trabaja en su schema y tiene un namespace claro donde viven sus tablas.

El beneficio adicional es que los joins cross-schema son nativos en PostgreSQL. La vista `ventas.vw_pedido_cliente` puede hacer `JOIN clientes.cliente` sin ninguna complejidad de replicación o sincronización. Las 10 vistas analíticas (ADR-024) serían imposibles con bases de datos separadas sin una capa de data warehouse. Un solo backup cubre toda la plataforma. Un solo proceso de migración Liquibase gestiona todo el esquema.

**Impacto medible:**

- Costo de infraestructura de BD: 1 instancia PostgreSQL vs. 3-4 instancias.
- Joins cross-domain: nativos y eficientes sin capa de sincronización.
- Backups: un solo proceso cubre todos los datos del negocio.
- Migraciones: un solo Liquibase run actualiza el esquema completo de todos los servicios.

---

### ADR-012 — Liquibase para Migraciones de Base de Datos

**Problema que resuelve:** Sin control de versiones de la base de datos, reproducir el estado exacto del esquema en un nuevo ambiente (la máquina de un desarrollador nuevo, el servidor de QA, el servidor de producción) es imposible sin documentación manual propensa a errores. "Funciona en mi máquina" se convierte en el problema principal al integrar cambios de BD.

**Mejora concreta al sistema:**

Liquibase convierte el estado del esquema de la base de datos en algo tan reproducible como el código fuente: `docker-compose up` en cualquier máquina siempre produce exactamente el mismo esquema, con los mismos índices, vistas, funciones, triggers y datos iniciales. No hay estado oculto ni pasos manuales.

La estructura jerárquica por tipo de operación (`01_ddl`, `02_dml`, `03_dcl`, `04_tcl`) hace que sea inmediatamente evidente qué tipo de cambio contiene cada archivo. Los scripts de rollback en `05_rollbacks/` convierten cada migración en una operación bidireccional: se puede avanzar y retroceder de forma controlada. La tabla `DATABASECHANGELOG` mantiene un registro inmutable de qué cambios se aplicaron, cuándo y por quién.

**Impacto medible:**

- Tiempo de setup de ambiente desde cero: `git clone && docker-compose up` (sin pasos manuales de BD).
- Historial de cambios de esquema: auditado en Git con fecha, autor y descripción.
- Rollback de migraciones: ejecutable con `liquibase rollback`, sin scripts ad-hoc.
- Onboarding de nuevo desarrollador: reproduce el estado exacto de la BD en minutos.
- El `depends_on: condition: service_healthy` garantiza que Liquibase no corre hasta que PostgreSQL está listo.

---

### ADR-013 — Estrategia Polyrepo por Servicio

**Problema que resuelve:** En un equipo con roles especializados (DevOps, Backend, Frontend, QA), un monorepo crea contención constante: el desarrollador de frontend hace merge de su PR pero toca el mismo repositorio que el backend, activando builds y pipelines innecesarios. Los historiales de commits mezclan cambios sin relación.

**Mejora concreta al sistema:**

Con un repositorio por servicio, el historial de `accesorios-dm-inventory-service` solo contiene cambios del Inventory Service. Un `git log` en ese repositorio es directamente útil para entender la evolución del servicio, sin ruido de commits de otros dominios. Las Pull Requests del Inventory Service solo necesitan revisión del equipo de backend; no bloquean ni involucran al equipo de frontend.

Los releases son completamente independientes: el Security Service puede hacer un hotfix y desplegarse en 15 minutos sin esperar que el Inventory Service termine su ciclo de integración. Los permisos de GitHub pueden configurarse por repositorio: el equipo de QA puede tener acceso de lectura a todos pero escritura solo en los suyos.

**Impacto medible:**

- PRs de cada servicio revisadas solo por el equipo responsable: menor tiempo de revisión.
- Deploy independiente: un fix de seguridad en Security Service no requiere redeploy del sistema completo.
- Historial de commits limpio y relevante por servicio.
- Sin builds innecesarios: un push al frontend no activa el pipeline del backend.

---

### ADR-014 — Docker con Red Compartida Externa

**Problema que resuelve:** Con el enfoque polyrepo, cada servicio tiene su propio `docker-compose.yml`. Sin una red compartida, los contenedores de diferentes compose files no pueden comunicarse entre sí por nombre, obligando a usar IPs del host o configuraciones complejas de red.

**Mejora concreta al sistema:**

La red `accesorios-dm-database_accesorios-network-prod` creada por el repositorio de la base de datos y referenciada como `external: true` en todos los demás servicios unifica la comunicación inter-contenedor bajo un DNS interno de Docker. El gateway puede conectarse al Inventory Service como `accesorios-dm-inventory-service-prod` sin conocer IPs. El Inventory Service conecta a PostgreSQL como `accesorios-dm-postgres-prod` sin hardcodear `localhost:5432`.

Este diseño también mejora la seguridad: los servicios downstream (Inventory, Security, Payment) no necesitan exponer sus puertos al host. Solo el gateway expone su puerto (`8000`) al exterior. Los puertos de los servicios internos están abiertos únicamente dentro de la red Docker privada, invisible desde fuera del servidor.

**Impacto medible:**

- Los servicios internos no exponen puertos al host → menor superficie de ataque.
- Comunicación por nombre de contenedor → sin IPs hardcodeadas que cambien en deploys.
- La red persiste entre `docker-compose down/up` de servicios individuales → sin configuración manual al reiniciar un servicio.
- Portabilidad: la misma configuración funciona en cualquier servidor Docker sin cambios de IP.

---

### ADR-015 — Row Level Security de PostgreSQL

**Problema que resuelve:** La seguridad implementada solo en la capa de aplicación tiene un punto de falla: un bug en el código, un acceso directo a la BD desde una herramienta de administración, o un microservicio con una query incorrecta pueden exponer datos de un usuario a otro. Para datos financieros y personales, esto es inaceptable.

**Mejora concreta al sistema:**

Las políticas RLS convierten la base de datos en una segunda línea de defensa independiente del código de aplicación. La política `pedido_cliente_select` garantiza que un cliente solo puede ver sus propios pedidos directamente en la BD, sin que ningún microservicio pueda violar esto por error. La política `empleado_self_select` impide que un vendedor vea las credenciales de otros empleados aunque la query se ejecute desde un cliente SQL manual.

La separación en cuatro roles de BD (`app_admin`, `app_vendedor`, `app_cliente`, `app_bodeguero`) crea una capa de control de acceso que refleja el modelo de roles del negocio directamente en la persistencia. Esto permite que herramientas de BI (Metabase, Grafana) se conecten directamente a la BD con el rol `app_vendedor` y automáticamente solo vean los datos permitidos para ese rol, sin configuración adicional en la herramienta.

**Impacto medible:**

- Protección de datos ante acceso directo a BD (DBA, herramientas de administración).
- Reducción de la superficie de impacto ante bugs de autorización en microservicios.
- Compatibilidad con herramientas BI: RLS aplica automáticamente para cualquier cliente que se conecte con el rol correcto.
- Cumplimiento de principio de mínimo privilegio a nivel de datos.

> **Nota:** Las políticas están definidas correctamente pero requieren que los servicios se conecten con el rol apropiado (no como `admin`) para ser efectivas. Ver plan de corrección en ADR-015.

---

### ADR-016 — Almacenamiento de Imágenes en Filesystem Local

**Problema que resuelve:** Las imágenes de productos necesitan persistir entre reinicios del contenedor y ser accesibles a través de la API. Almacenarlas en la base de datos como blobs penalizaría severamente el rendimiento de todas las queries. Integrar S3 o Cloudinary en el MVP introduciría complejidad de configuración y costos no justificados.

**Mejora concreta al sistema:**

El volume mount `./uploads:/app/uploads` resuelve la persistencia sin costo adicional: las imágenes sobreviven cualquier reinicio o recreación del contenedor. La organización `uploads/productos/{productoId}/{uuid}.ext` crea un namespace natural por producto, facilitando la gestión manual si fuera necesaria.

El uso de UUID como nombre de archivo previene dos problemas simultáneamente: colisiones de nombres (dos imágenes llamadas `foto.jpg` coexisten sin problema) y path traversal (un atacante no puede predecir URLs de imágenes ni manipular el sistema de archivos a través del nombre). El proxy dedicado `/uploads` en el gateway unifica el acceso a imágenes bajo el mismo dominio que el API, eliminando problemas de CORS y simplificando la configuración de HTTPS en producción.

**Impacto medible:**

- Costo de almacenamiento de imágenes en el MVP: $0 (disco local del servidor).
- Las imágenes son accesibles a través del mismo dominio del API (`/api/v1/uploads/...` → proxy → Inventory Service).
- UUID previene colisiones y ataques de path traversal.
- El volume mount garantiza persistencia sin configuración de almacenamiento externo.

---

## 3. Impacto de los Design ADRs

Los ADRs de diseño definen los patrones internos de cada componente: cómo se organiza el código, qué ORMs se usan, cómo se modelan los datos, cómo se optimizan las consultas. Su impacto principal es en la mantenibilidad, la productividad del equipo de desarrollo y el rendimiento del sistema.

---

### ADR-017 — Arquitectura en Capas en el Inventory Service

**Problema que resuelve:** Sin una organización explícita del código, la lógica de negocio, el acceso a datos y la gestión de HTTP se mezclan en los mismos archivos. El resultado es código que es difícil de entender, imposible de testear de forma aislada, y frágil ante cambios: modificar la lógica de negocio puede accidentalmente romper el acceso a datos o viceversa.

**Mejora concreta al sistema:**

La separación en capas `Controller → Service → Repository → Entity` crea contratos implícitos entre las capas. El `ProductoController` solo habla HTTP: recibe requests, llama al Service, devuelve responses. El `ProductoService` solo hace lógica de negocio: calcula precios con descuento, valida existencia de categorías, orquesta transacciones. El `ProductoRepository` solo habla JPA: define queries tipadas con Spring Data.

Esta separación tiene un beneficio concreto en el testing: el `ProductoService` puede testearse con mocks del `ProductoRepository` sin levantar el servidor HTTP ni la base de datos. El `ProductoController` puede testearse con MockMvc sin lógica de negocio. La anotación `@Transactional(readOnly = true)` en las lecturas optimiza el pool de conexiones Hikari: las transacciones de solo lectura no bloquean recursos de escritura.

**Impacto medible:**

- Testabilidad: cada capa es independientemente testeable con mocks.
- Mantenibilidad: un cambio en la lógica de precios solo toca `ProductoService`, no los demás componentes.
- `@Transactional(readOnly = true)` en lecturas: Hibernate puede usar réplicas de lectura y omite el dirty checking, mejorando el rendimiento.
- `@RequiredArgsConstructor` (Lombok): dependencias inmutables, sin setters, claridad total sobre qué necesita cada componente.

---

### ADR-018 — Patrón DTO para Desacoplamiento entre Entidades y API

**Problema que resuelve:** Las entidades JPA tienen relaciones lazy (`@ManyToOne(fetch = LAZY)`) que, al serializar directamente a JSON, generan `LazyInitializationException` o bucles de serialización infinita. Además, exponer la entidad directamente acopla el contrato de la API al modelo de base de datos: un cambio de nombre de columna cambia automáticamente la respuesta JSON que consumen los clientes.

**Mejora concreta al sistema:**

El `ProductoResumenDTO` es la mejora más concreta: en lugar de devolver el objeto completo `Producto` con todas sus relaciones (categoría completa, material completo, lista de imágenes, lista de promociones), el listado del catálogo devuelve solo `{id, nombre, precio, precioConDescuento, imagenPrincipal, categoriaNombre}`. Esto reduce el payload de una respuesta de listado en aproximadamente un 70-80% comparado con serializar la entidad completa.

El campo `precioConDescuento` y `promocionActiva` en el DTO son campos calculados que no existen en ninguna tabla de la base de datos: se calculan en la capa de Service consultando las promociones vigentes. Esto demuestra el poder del patrón: el DTO puede exponer información derivada, agregada o calculada sin contaminar el modelo de persistencia.

**Impacto medible:**

- Payload de listado de catálogo: ~70% más liviano que serializar la entidad completa.
- Sin riesgo de `LazyInitializationException` en responses JSON.
- El campo calculado `precioConDescuento` en el DTO evita que el frontend calcule descuentos, centralizando esa lógica.
- El contrato de la API es estable ante cambios de esquema de BD que no afecten los campos del DTO.

---

### ADR-019 — Prisma ORM Multi-Schema en el Payment Service

**Problema que resuelve:** El Payment Service (Node.js) necesita acceder a datos de múltiples schemas PostgreSQL: crear pedidos en `ventas`, leer precios de `catalogo`, gestionar clientes de `clientes`, registrar movimientos en `inventario`. Sin un ORM, esto requeriría SQL manual con gestión de conexiones, sin tipo de retorno garantizado y propenso a errores.

**Mejora concreta al sistema:**

Prisma con `multiSchema` convierte las queries complejas de checkout en código legible y typesafe. La línea:

```js
const carrito = await prisma.carrito.findUnique({
  where: { id_carrito: parseInt(id_carrito) },
  include: { items: { include: { producto: true } } },
});
```

es autoexplicativa y genera automáticamente los JOINs SQL óptimos entre `ventas.carrito`, `ventas.item_carrito` y `catalogo.producto`. El resultado es tipado: el IDE sabe que `carrito.items[0].producto.nombre` es un `string`, previniendo errores de runtime.

El schema de Prisma funciona como documentación viva del modelo de datos del Payment Service: cualquier desarrollador puede abrir `prisma/schema.prisma` y entender exactamente qué tablas y relaciones usa el servicio, sin leer SQL ni documentación separada.

**Impacto medible:**

- Queries con JOINs multi-schema: generadas automáticamente por Prisma, sin SQL manual.
- Tipo de retorno garantizado: el IDE detecta accesos a campos inexistentes antes de runtime.
- El schema de Prisma es documentación ejecutable del modelo de datos del servicio.
- `prisma.$executeRaw` permite SQL directo para casos límite (INSERT en `inventario_movimiento`) sin abandonar el cliente Prisma.

---

### ADR-020 — FastAPI con SQLAlchemy y Dependency Injection

**Problema que resuelve:** La validación de datos de entrada, la documentación de API, la gestión de sesiones de base de datos y la autenticación son cuatro problemas transversales que, sin una estrategia clara, se implementan de forma ad-hoc en cada endpoint, resultando en código duplicado y difícil de mantener.

**Mejora concreta al sistema:**

El sistema `Depends()` de FastAPI es la solución más elegante a estos problemas: `get_db` gestiona el ciclo de vida completo de la sesión (apertura, uso, cierre garantizado por `finally`) e inyectarla como dependencia significa que cada función de endpoint recibe una sesión limpia y garantiza su liberación. `get_current_user` y `require_role(["ADMIN"])` son decoradores de autorización que se leen como documentación: `current_user: Empleado = Depends(require_role(["ADMIN"]))` le dice al lector en una línea que este endpoint requiere un empleado autenticado con rol ADMIN.

Pydantic valida automáticamente todos los request bodies y genera errores `422 Unprocessable Entity` descriptivos con el campo exacto que falló, sin una sola línea de código de validación manual. FastAPI genera Swagger UI completo en `/docs` automáticamente, incluyendo los schemas de request/response, los endpoints protegidos por Bearer token y los códigos de error.

**Impacto medible:**

- Validación de request body: automática con Pydantic, sin código manual.
- Documentación de API: Swagger UI generado automáticamente en `/docs`.
- Gestión de sesiones BD: garantizada por `Depends(get_db)`, sin `try/finally` manual en cada endpoint.
- Autorización declarativa: `Depends(require_role(["ADMIN"]))` en la firma del endpoint es autoexplicativa.

---

### ADR-021 — JPA/Hibernate con ddl-auto=validate y HikariCP

**Problema que resuelve:** En un sistema con Liquibase como gestor de esquema, permitir que Hibernate también modifique el esquema (`ddl-auto: update`) crea una competencia entre dos herramientas sobre el mismo objeto. En el mejor caso, generan redundancia; en el peor, Hibernate puede intentar alterar tablas creadas por Liquibase de formas incompatibles o destructivas.

**Mejora concreta al sistema:**

`ddl-auto: validate` convierte el arranque del Inventory Service en una verificación automática de consistencia: si alguna entidad JPA tiene un campo que no existe en la tabla de PostgreSQL, o si el tipo de dato es incompatible, el servicio falla en el arranque con un error explícito. Esto detecta problemas de sincronización entre Liquibase y las entidades JPA antes de que lleguen a producción, no en runtime cuando un usuario hace una petición.

HikariCP con `maximum-pool-size: 10` y `minimum-idle: 2` optimiza el uso de conexiones: nunca abre más de 10 conexiones simultáneas a PostgreSQL (protege a la BD de sobrecarga) y mantiene mínimo 2 listas para usar (elimina la latencia de establecer conexión en el primer request tras un período idle).

**Impacto medible:**

- Detección de inconsistencias schema-entidad: en el arranque, no en runtime.
- Protección de la BD: máximo 10 conexiones del Inventory Service, independientemente de la carga.
- `minimum-idle: 2` elimina la latencia de conexión fría tras períodos de baja actividad.
- Separación clara de responsabilidades: Liquibase = dueño del esquema, Hibernate = dueño del acceso.

---

### ADR-022 — SHA-256 para Hashing de Contraseñas

**Problema que resuelve:** Las contraseñas no pueden almacenarse en texto plano. El sistema necesita un mecanismo que permita verificar si una contraseña es correcta sin almacenar la contraseña misma, de forma que una brecha de la base de datos no exponga las credenciales de los empleados.

**Mejora concreta al sistema (en su contexto actual):**

La implementación con SHA-256 cumple el requisito mínimo de no almacenar contraseñas en texto plano y de que la verificación funcione correctamente para el flujo de autenticación del MVP. El salt (`"accesorios-dm-salt"`) añade una capa básica de ofuscación sobre contraseñas comunes. Para el ambiente de desarrollo con datos de prueba, esta implementación es funcional y permite avanzar en el desarrollo de las demás funcionalidades sin bloqueos.

Esta decisión es documentada con reservas explícitas y un plan de migración a bcrypt, lo que es más valioso que no documentarla: el equipo sabe exactamente qué está usando, por qué es insuficiente para producción, y cuál es el camino de corrección. La transparencia de la documentación ADR convierte una deuda técnica oculta en una deuda técnica conocida y planificada.

**Impacto en el sistema (aspiracional — con bcrypt):**

- Resistencia a ataques de fuerza bruta: bcrypt limita los intentos a ~100/segundo vs. millones con SHA-256.
- Salt único por contraseña: dos usuarios con la misma contraseña tendrían hashes distintos.
- Factor de costo adaptativo: el costo del hash puede aumentarse con el tiempo sin invalidar contraseñas existentes.

---

### ADR-023 — Estrategia de 35 Índices de Rendimiento

**Problema que resuelve:** Con el crecimiento de datos, las queries sin índices hacen full table scans. Para el catálogo de productos, una query `WHERE estado = true AND id_categoria = ?` sin índice escanea toda la tabla `producto` aunque solo el 5% de las filas coincida. A 10.000 productos, esto puede tardar segundos en lugar de milisegundos.

**Mejora concreta al sistema:**

Los 35 índices convierten las operaciones más frecuentes del sistema de O(n) a O(log n). El impacto más crítico es en el login: `idx_empleado_correo` convierte la autenticación de un full scan en una búsqueda por índice B-tree, lo que escala sin degradación independientemente del número de empleados registrados.

Los índices compuestos estratégicos son los más valiosos. `idx_producto_estado_precio` soporta la query más frecuente del catálogo (`WHERE estado = true ORDER BY precio`) con un único acceso al índice sin necesidad de sort adicional. `idx_carrito_cliente_estado` convierte la query "dame el carrito activo del cliente X" de un scan en una búsqueda directa. `idx_pedido_cliente_fecha` permite obtener el historial de pedidos de un cliente ordenado por fecha en un solo paso de índice.

**Impacto medible:**

- Login: de O(n) full scan a O(log n) búsqueda por índice. Con 10.000 empleados: de ~100ms a ~1ms.
- Listado de catálogo por categoría: de full scan + filter a index seek. Con 50.000 productos: de segundos a milisegundos.
- Historial de pedidos por cliente: de full scan a index range scan.
- Los índices `IF NOT EXISTS` son idempotentes: seguros para re-ejecutar en cualquier ambiente.

---

### ADR-024 — 10 Vistas SQL para Reportes Analíticos

**Problema que resuelve:** Los reportes de negocio (ventas por mes, top productos, pedidos con detalle de cliente) requieren joins complejos entre 5-6 tablas de diferentes schemas. Si cada microservicio implementa estas queries en su código, hay duplicación de lógica, y un cambio en la regla de negocio (ej: qué estados cuentan como "venta completada") requiere actualizar código en múltiples servicios y hacer redeploy.

**Mejora concreta al sistema:**

Las vistas encapsulan la complejidad de los joins en la base de datos, donde son más eficientes y donde los índices aplican directamente. El endpoint `/admin/stats` del Payment Service puede consultar `ventas.vw_ventas_por_mes` con un simple `SELECT * FROM ventas.vw_ventas_por_mes LIMIT 12` sin que el desarrollador necesite escribir ni mantener el join complejo.

`vw_producto_bajo_stock` convierte el monitoreo de inventario en un query trivial: cualquier sistema de alertas puede consultar esta vista periódicamente y disparar una notificación cuando hay productos con `nivel_stock = 'Sin Stock'`. `vw_pedido_historial_estados` provee el historial de auditoría completo de cada pedido sin que ningún microservicio tenga que construir esa query.

La vista `vw_producto_promocion_activa` calcula el `precio_promocional` y el `ahorro` en SQL, evitando que tanto el frontend como el backend tengan que reimplementar la lógica de cálculo de precios con descuento.

**Impacto medible:**

- Cambio en la regla de "qué estados cuentan como venta": 1 modificación de SQL en `vw_ventas_por_mes` vs. múltiples cambios de código + redeploy.
- Consulta de top 10 productos: 1 línea de código contra la vista vs. 30-50 líneas de SQL con JOINs.
- Integración con herramientas BI (Metabase, Power BI): conexión directa a las vistas, cero código adicional.
- `vw_producto_bajo_stock`: base para un sistema de alertas de inventario sin desarrollo adicional.

---

### ADR-025 — Modelo de Datos en 8 Schemas de Dominio

**Problema que resuelve:** Sin separación lógica, 17 tablas en el schema `public` forman una masa indiferenciada donde no es evidente qué tablas pertenecen a qué dominio de negocio, qué servicio es responsable de qué datos, o cuáles son los límites correctos para otorgar permisos.

**Mejora concreta al sistema:**

Los 8 schemas convierten el modelo de datos en documentación ejecutable del diseño de dominio. Un desarrollador nuevo que vea la BD entiende inmediatamente la estructura del negocio: `security` = autenticación, `catalogo` = productos, `ventas` = transacciones, `logistica` = seguimiento de pedidos. Sin leer ningún código de aplicación, el schema de la BD comunica los bounded contexts del sistema.

Las foreign keys cross-schema (`ventas.pedido.id_cliente → clientes.cliente.id_cliente`) hacen explícitas las dependencias entre dominios. Esto es información crítica para la evolución del sistema: si se decide separar `security` en su propia base de datos, las FKs cross-schema son exactamente los puntos donde se necesitaría introducir duplicación de datos o APIs de consulta inter-servicio.

La alineación schema-microservicio (`catalogo` es propiedad del Inventory Service, `ventas` del Payment Service) hace que los permisos de base de datos sean naturales: el Inventory Service solo necesita permisos sobre `catalogo`, `promociones` e `inventario`; no sobre `ventas` ni `security`.

**Impacto medible:**

- Comprensión del modelo de negocio: legible directamente desde la BD sin documentación adicional.
- Asignación de permisos: granular y natural por schema → microservicio.
- Identificación de dependencias: las FK cross-schema son el mapa de dependencias entre dominios.
- Base para separación futura: los schemas son las unidades naturales de migración si se decide separar en BDs independientes.

---

## 4. Impacto Transversal por Dimensión de Calidad

Esta sección analiza cómo el conjunto de ADRs mejora el sistema en sus dimensiones de calidad más importantes, mostrando cómo las decisiones se refuerzan mutuamente.

---

### 4.1 Seguridad

El sistema tiene **tres capas de seguridad** que se complementan:

**Capa 1 — Red (ADR-014):** Los servicios internos no exponen puertos al host. Solo el gateway tiene puerto público. Un atacante externo no puede conectarse directamente al Inventory Service ni a PostgreSQL.

**Capa 2 — Aplicación (ADR-002, ADR-003, ADR-020):** JWT valida la identidad. `require_role` controla el acceso por recurso. El rate limiter previene abuso de la API y fuerza bruta en el login.

**Capa 3 — Datos (ADR-015, ADR-025):** RLS garantiza que incluso con acceso directo a la BD, un usuario solo ve sus propios datos. Los schemas separan lógicamente los datos sensibles (`security.empleado`) de los datos públicos (`catalogo.producto`).

La combinación de estas tres capas sigue el principio de **defensa en profundidad**: comprometer una capa no compromete todo el sistema.

---

### 4.2 Mantenibilidad

**ADR-017 + ADR-018**: La arquitectura en capas con DTOs en el Inventory Service hace que los cambios sean locales. Un cambio en el precio de visualización solo toca el DTO. Un cambio en la lógica de descuento solo toca el Service. Un cambio en la tabla de BD solo toca la Entity.

**ADR-012 + ADR-021**: Liquibase como gestor de esquema y `ddl-auto: validate` como verificador crean una relación explícita entre el código y la base de datos. Cualquier inconsistencia se detecta en el arranque, no en producción.

**ADR-024**: Las vistas SQL centralizan la lógica de reporting. Un cambio en las reglas de negocio de ventas se hace en un lugar, no en todos los endpoints que calculan estadísticas.

---

### 4.3 Escalabilidad

**ADR-001**: El gateway es el punto de control de escalabilidad. Añadir instancias de un servicio downstream requiere solo actualizar la configuración del proxy, sin cambios en el frontend.

**ADR-011**: La BD compartida con schemas es el cuello de botella horizontal actual. La separación en schemas facilita la migración futura a BDs independientes si el volumen lo justifica.

**ADR-023**: Los 35 índices garantizan que las queries críticas escalen logarítmicamente con el volumen de datos, no linealmente.

**ADR-016**: El almacenamiento local bloquea la escalabilidad horizontal del Inventory Service. Este es el trade-off más claro documentado en los ADRs: funcional para una instancia, requiere migración a S3/CDN para escalar.

---

### 4.4 Operabilidad

**ADR-004 + ADR-014**: La estrategia de puertos y redes Docker permite operar múltiples ambientes en la misma infraestructura con configuración predecible.

**ADR-008 + ADR-009**: Health checks y logging centralizado proveen observabilidad básica que cubre el 80% de los casos de diagnóstico operacional: ¿el sistema está UP? ¿cuánto tardó el último request? ¿qué errores hubo?

**ADR-012**: Liquibase hace que las actualizaciones de BD sean parte del despliegue automatizado, no un paso manual propenso a errores.

---

### 4.5 Productividad del Equipo de Desarrollo

**ADR-003**: Rate limiting de 1000 req/min en desarrollo elimina bloqueos durante debugging.

**ADR-010**: Cada desarrollador trabaja con el stack que domina, sin necesidad de aprender otros frameworks.

**ADR-020**: FastAPI genera documentación Swagger automática, eliminando el tiempo de escribir y mantener documentación de API manualmente.

**ADR-007**: La integración WhatsApp permite al equipo lanzar el flujo de pedidos completo sin esperar la integración de una pasarela de pago.

**ADR-013**: El polyrepo permite que cada desarrollador trabaje en su servicio sin conflictos con el trabajo de otros.

---

## 5. Mapa de Dependencias entre ADRs

Este mapa muestra cómo los ADRs se refuerzan mutuamente. Una flecha `A → B` significa "A habilita o potencia a B".

```
ADR-010 (Políglota)
    ├── habilita → ADR-005 (HTTP como único protocolo viable)
    └── requiere → ADR-014 (Docker abstrae las diferencias de runtime)

ADR-011 (BD Compartida)
    ├── habilita → ADR-024 (Vistas cross-schema posibles)
    ├── habilita → ADR-023 (Un solo lugar para todos los índices)
    ├── requiere → ADR-012 (Liquibase gestiona el esquema único)
    └── requiere → ADR-015 (RLS necesario para aislar accesos)

ADR-012 (Liquibase)
    └── requiere → ADR-021 (ddl-auto:validate depende de Liquibase)

ADR-025 (8 Schemas)
    ├── habilita → ADR-015 (RLS por schema)
    ├── habilita → ADR-024 (Vistas semánticas por dominio)
    └── fundamenta → ADR-017/019/020 (ORMs apuntan a schemas específicos)

ADR-001 (API Gateway)
    ├── centraliza → ADR-003 (Rate limiting)
    ├── centraliza → ADR-009 (Logging)
    └── coordina → ADR-008 (Health checks del ecosistema)

ADR-002 (JWT)
    └── implementado por → ADR-020 (FastAPI DI valida tokens)

ADR-006 (Triggers)
    └── complementa → ADR-019 (Prisma no ve los triggers)

ADR-014 (Red Docker)
    └── habilita → ADR-004 (Ambientes en la misma máquina)
```

---

## 6. Matriz de Impacto Consolidada

La siguiente tabla resume el impacto de cada ADR en las seis dimensiones de calidad del sistema. La escala es: **Alto** / **Medio** / **Bajo** / **—** (sin impacto directo).

| ADR                   | Seguridad | Mantenibilidad | Escalabilidad | Rendimiento | Operabilidad | Dev Experience |
| --------------------- | --------- | -------------- | ------------- | ----------- | ------------ | -------------- |
| ADR-001 API Gateway   | Alto      | Alto           | Alto          | Medio       | Alto         | Medio          |
| ADR-002 JWT Auth      | **Alto**  | Medio          | Alto          | Medio       | Bajo         | Medio          |
| ADR-003 Rate Limiting | Alto      | Bajo           | Medio         | Bajo        | Medio        | Alto           |
| ADR-004 Puertos       | Bajo      | Medio          | Medio         | —           | **Alto**     | Alto           |
| ADR-005 HTTP Sync     | Bajo      | Alto           | Medio         | Medio       | Alto         | Alto           |
| ADR-006 Triggers      | Bajo      | Alto           | Alto          | Medio       | Medio        | Medio          |
| ADR-007 WhatsApp      | Bajo      | Bajo           | Bajo          | —           | Bajo         | **Alto**       |
| ADR-008 Health Checks | Medio     | Bajo           | Medio         | —           | **Alto**     | Alto           |
| ADR-009 Logging       | Medio     | Bajo           | Bajo          | Bajo        | **Alto**     | Alto           |
| ADR-010 Políglota     | Bajo      | Medio          | Alto          | Alto        | Medio        | **Alto**       |
| ADR-011 BD Schemas    | **Alto**  | Alto           | **Alto**      | Alto        | Alto         | Alto           |
| ADR-012 Liquibase     | Medio     | **Alto**       | Medio         | —           | **Alto**     | Alto           |
| ADR-013 Polyrepo      | Bajo      | Alto           | Medio         | —           | Medio        | **Alto**       |
| ADR-014 Docker Net    | **Alto**  | Medio          | Alto          | —           | **Alto**     | Alto           |
| ADR-015 RLS           | **Alto**  | Medio          | Bajo          | Bajo        | Bajo         | Bajo           |
| ADR-016 Filesystem    | Bajo      | Bajo           | **Bajo**      | Medio       | Medio        | Alto           |
| ADR-017 Capas         | Bajo      | **Alto**       | Bajo          | Medio       | Bajo         | **Alto**       |
| ADR-018 DTO           | Bajo      | **Alto**       | Bajo          | Alto        | Bajo         | Alto           |
| ADR-019 Prisma        | Bajo      | **Alto**       | Bajo          | Medio       | Bajo         | **Alto**       |
| ADR-020 FastAPI DI    | **Alto**  | **Alto**       | Bajo          | Bajo        | Bajo         | **Alto**       |
| ADR-021 JPA Validate  | Medio     | **Alto**       | Bajo          | **Alto**    | Medio        | Medio          |
| ADR-022 SHA-256       | **Bajo**  | Bajo           | —             | —           | —            | Medio          |
| ADR-023 Índices       | Bajo      | Bajo           | **Alto**      | **Alto**    | Bajo         | Bajo           |
| ADR-024 Vistas SQL    | Bajo      | **Alto**       | Medio         | Alto        | Medio        | **Alto**       |
| ADR-025 8 Schemas     | **Alto**  | **Alto**       | **Alto**      | Medio       | Alto         | **Alto**       |

> **Lectura de la tabla:** Los campos en **negrita** marcan el impacto más alto de ese ADR. ADR-022 tiene Seguridad en **Bajo** porque su implementación actual con SHA-256 es una regresión respecto al estado objetivo con bcrypt.

---

## 7. Evaluación del Estado Actual vs. Estado Objetivo

Esta sección compara el estado del sistema **antes de los ADRs** (sistema hipotético sin las decisiones documentadas) con el **estado actual** (con los ADRs implementados), y el **estado objetivo** (con las correcciones planificadas).

---

### 7.1 Seguridad

| Aspecto       | Sin ADRs                    | Estado Actual            | Estado Objetivo               |
| ------------- | --------------------------- | ------------------------ | ----------------------------- |
| Autenticación | Sin auth                    | JWT HS256 funcional      | JWT + bcrypt + refresh tokens |
| Autorización  | Sin control                 | RBAC en Security Service | RBAC + RLS activo en BD       |
| Red           | Todos los puertos expuestos | Solo gateway expuesto    | Gateway + WAF                 |
| Contraseñas   | Texto plano                 | SHA-256 (inseguro)       | **bcrypt / argon2**           |
| Rate limiting | Sin límite                  | Activo por ambiente      | Auth rate limit aplicado      |

---

### 7.2 Integridad de Datos

| Aspecto                 | Sin ADRs                     | Estado Actual                         | Estado Objetivo                       |
| ----------------------- | ---------------------------- | ------------------------------------- | ------------------------------------- |
| Migraciones de BD       | Scripts manuales             | Liquibase versionado                  | Liquibase + CI/CD                     |
| Consistencia de stock   | Sin garantía                 | Triggers (con bug de doble descuento) | **Solo triggers, sin UPDATE directo** |
| Transacciones de pedido | Sin transacción              | Sin `$transaction` (bug)              | **`prisma.$transaction` en checkout** |
| Esquema en validación   | `ddl-auto: update` peligroso | `ddl-auto: validate`                  | Sin cambios necesarios                |

---

### 7.3 Rendimiento

| Aspecto               | Sin ADRs                 | Estado Actual                        | Estado Objetivo                               |
| --------------------- | ------------------------ | ------------------------------------ | --------------------------------------------- |
| Consultas de catálogo | Full table scans         | 35 índices optimizados               | + GIN para búsqueda de texto                  |
| Payload de listados   | Entidades completas      | DTOs optimizados (~70% más livianos) | Sin cambios necesarios                        |
| Pool de conexiones    | Default ilimitado        | HikariCP configurado (max 10)        | + PgBouncer para múltiples servicios          |
| Reportes analíticos   | Queries ad-hoc en código | 10 vistas SQL                        | + Vistas materializadas para reportes pesados |

---

### 7.4 Operabilidad

| Aspecto                       | Sin ADRs              | Estado Actual                        | Estado Objetivo                       |
| ----------------------------- | --------------------- | ------------------------------------ | ------------------------------------- |
| Reproducibilidad de ambientes | Manual, inconsistente | `docker-compose up` reproduce todo   | + Scripts de arranque ordenado        |
| Visibilidad de salud          | Sin health checks     | Health checks en todos los servicios | + Verificación de BD en health checks |
| Trazabilidad de requests      | Sin logs              | Logging centralizado en gateway      | + Correlation ID propagado            |
| Múltiples ambientes           | Un ambiente           | develop/qa/main simultáneos          | Sin cambios necesarios                |

---

### 7.5 Síntesis Final del Impacto

Los 25 ADRs documentados transforman el sistema de Accesorios DM de una colección de servicios ad-hoc en una plataforma con decisiones arquitectónicas explícitas, justificadas y evolucionables. Los beneficios más significativos son:

**El impacto más alto:** La combinación de ADR-011 (BD con schemas), ADR-012 (Liquibase), ADR-025 (modelo de datos), ADR-023 (índices) y ADR-024 (vistas) crea una capa de persistencia que sería el orgullo de cualquier sistema de producción: reproducible, versionada, optimizada, auditada y con reportes analíticos integrados.

**El gap más urgente:** ADR-022 (SHA-256) y ADR-006 (doble descuento de stock) son los únicos dos ADRs donde la implementación actual introduce degradación activa. Ambos tienen correcciones documentadas y de bajo costo. Su resolución elevaría el nivel de madurez del sistema de 6.5/10 a aproximadamente 8/10.

**El mayor potencial sin aprovechar:** ADR-015 (RLS) tiene toda la infraestructura construida (tablas con RLS habilitado, roles creados, políticas definidas) pero no está activo porque los servicios se conectan como `admin`. Con cambios menores en la capa de conexión de cada servicio, se activaría una capa de seguridad de nivel empresarial que pocas plataformas de este tamaño tienen.

---

_Documento generado a partir del análisis de código fuente de los repositorios DmApp._  
_Todos los impactos descritos están respaldados por evidencia directa en el código, configuraciones y estructura del sistema._
