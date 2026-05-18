# ADR-010: Arquitectura de Microservicios Políglota (Java / Python / Node.js)

| Campo | Valor |
|---|---|
| **ID** | ADR-010 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Todo el sistema |

---

## Contexto

El equipo de desarrollo de Accesorios DM está compuesto por integrantes con diferentes especializaciones. El proyecto es académico/profesional con fines de digitalización de un negocio real. Cada dominio funcional tiene características y necesidades tecnológicas diferentes, y el equipo tiene miembros con experiencias en distintos ecosistemas.

---

## Problema

¿Debe el sistema adoptar un stack tecnológico uniforme (mismo lenguaje y framework para todos los servicios) o permitir heterogeneidad tecnológica (tecnología óptima por dominio)?

---

## Decisión

Se adoptó una **arquitectura de microservicios políglota**, donde cada servicio usa la tecnología mejor adaptada a su dominio:

| Servicio | Tecnología | Justificación |
|---|---|---|
| Inventory Service | Java 17 + Spring Boot 3.5 | Ecosistema empresarial maduro para dominio de datos complejos |
| Security Service | Python 3.11 + FastAPI | Framework moderno para APIs seguras con validación automática |
| Payment Service | Node.js 18 + Express + Prisma | Rápido para I/O intensivo; Prisma para modelado multi-schema |
| API Gateway | Node.js 18 + Express | Ideal para proxy/routing sin lógica de negocio pesada |
| Frontend | Angular (en desarrollo) | Framework estructurado para SPA empresarial |
| Base de Datos | PostgreSQL 16 | Única base de datos centralizada con schemas separados |

---

## Justificación Técnica

- **Especialización por dominio**: Spring Boot es el estándar de facto para servicios empresariales Java con JPA. FastAPI provee documentación automática (Swagger), validación de tipos con Pydantic, y async nativo para el Security Service. Node.js es óptimo para el gateway de proxy que no hace procesamiento pesado.
- **Curva de aprendizaje del equipo**: Cada miembro trabaja con el stack que domina, maximizando la productividad.
- **Aislamiento de riesgo tecnológico**: Un bug crítico en una dependencia de Python no afecta los servicios Java o Node.
- **Docker como abstracción**: Todos los servicios se containerizanm homogeneizando el despliegue independientemente del runtime.

---

## Consecuencias

### Ventajas
- Cada servicio usa la herramienta óptima para su dominio.
- Independencia de ciclos de actualización de dependencias.
- Equipos especializados pueden evolucionar sus servicios sin coordinación con otros equipos.
- Spring Boot Actuator para Inventory, Swagger UI para Security, Express para gateway.

### Desventajas
- **Overhead operacional**: Tres runtimes distintos (JVM, Python, Node.js) requieren conocimiento en tres ecosistemas para operar.
- **Duplicación de patrones**: Validación de tokens JWT, logging, manejo de errores HTTP se implementan de forma diferente en cada servicio.
- **Sin shared libraries**: No existe código compartido entre servicios. Si se cambia el schema de respuesta de error, debe actualizarse en tres lugares.
- **CI/CD más complejo**: Los pipelines necesitan manejar `mvn`, `pip`, `npm` y sus respectivos procesos de build.
- **Dockerfiles más grandes**: Cada runtime tiene su imagen base diferente (openjdk, python, node), aumentando el tamaño total de imágenes.

### Trade-offs
Optimización por dominio vs. uniformidad operacional. Para un equipo académico/startup, el tradeoff es aceptable. Para un equipo de operaciones pequeño en producción real, podría ser problemático.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Stack uniforme Node.js | Perdería los beneficios de Spring Boot para el dominio complejo de inventario |
| Stack uniforme Java | Menos adecuado para el gateway liviano y FastAPI para seguridad |
| Monolito modular | No permite despliegue independiente ni especialización por dominio |

---

## Impacto Arquitectónico

**Fundamental**. Define la naturaleza del sistema y determina todas las decisiones subsecuentes de infraestructura, CI/CD, y operación.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Inconsistencias de API entre servicios | Media | Alto | Definir contrato OpenAPI para cada servicio |
| Dificultad de onboarding para nuevos devs | Alta | Medio | Documentar el stack completo en CLAUDE.md |
| Divergencia de versiones de dependencias | Media | Bajo | Lock files en cada servicio (pom.xml, requirements.txt, package-lock.json) |

---

## Relación con Otros Componentes

- **ADR-005**: HTTP es el único protocolo de comunicación viable entre stacks heterogéneos.
- **ADR-014**: Docker abstrae las diferencias de runtime para el despliegue.
- **ADR-011**: La BD única compensa la heterogeneidad con un modelo de datos centralizado.

---

## Consideraciones Futuras

- Definir contratos OpenAPI/Swagger para todos los servicios.
- Evaluar si el equipo puede mantener tres runtimes a largo plazo.
- Considerar consolidar gateway + payment en un único servicio Node.js cuando el Payment Service madure.

---

## Por qué es Structural

Es **Structural** porque define la estructura fundamental del sistema: cuántos componentes existen, cuáles son sus responsabilidades, qué tecnología usa cada uno, y cómo se relacionan entre sí en términos de despliegue y operación.
