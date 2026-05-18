# ADR-004: Estrategia de Puertos Diferenciados por Ambiente (develop/qa/main)

| Campo | Valor |
|---|---|
| **ID** | ADR-004 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Behavioral |
| **Servicios afectados** | Todos los microservicios, Base de Datos |

---

## Contexto

El equipo de desarrollo necesita ejecutar simultáneamente los ambientes `develop`, `qa` y `main` en la misma máquina host (o en el mismo servidor) para pruebas de integración y comparación de comportamiento entre ramas. Los servicios Docker exponen puertos en el host, lo que genera conflictos si todos los ambientes usan los mismos puertos.

---

## Problema

¿Cómo ejecutar múltiples ambientes del mismo servicio simultáneamente en el mismo host sin conflictos de puertos, manteniendo la configuración clara y predecible para el equipo?

---

## Decisión

Se adoptó una estrategia de **asignación de puertos por capa de servicio y por ambiente**, con desplazamiento numérico consistente.

**Mapeo completo:**

| Servicio | develop | qa | main (prod) |
|---|---|---|---|
| API Gateway | 8002 | 8001 | 8000 |
| Inventory Service | 8082 | 8081 | 8080 |
| Security Service | 8890 | 8889 | 8888 |
| Payment Service | 9002 | 9001 | 9000 |
| PostgreSQL | 5432 (dev) | 5433 (qa) | 5434 (prod) |

**Evidencia en código:**

```yml
# docker-compose.yml de cada servicio muestra el ambiente correspondiente
# El ambiente se selecciona haciendo checkout de la rama correspondiente:
# git checkout develop → usa puertos *2
# git checkout qa      → usa puertos *1
# git checkout main    → usa puertos *0 (producción)
```

**Nota especial de PostgreSQL**: La base de datos invierte el orden (`develop:5432`, `main:5434`) porque `develop` se ejecuta con más frecuencia y merece el puerto estándar.

---

## Justificación Técnica

- **Convención sobre configuración**: El patrón `{base_port + offset}` es fácil de recordar y predecible.
- **Aislamiento de ambientes**: QA y develop pueden ejecutarse simultáneamente sin interferir con producción.
- **Integración con Docker Compose**: Cada rama del repositorio tiene su propio `docker-compose.yml` con los puertos correspondientes. Cambiar de ambiente es tan simple como `git checkout`.
- **CI/CD compatible**: Los pipelines pueden apuntar a puertos específicos según la rama siendo construida.

---

## Consecuencias

### Ventajas
- Posibilidad de ejecutar todos los ambientes en paralelo en la misma máquina.
- Patrón numérico consistente y memorizable.
- Sin necesidad de herramientas adicionales de gestión de ambientes.
- El checkout de rama determina automáticamente el ambiente correcto.

### Desventajas
- **Gestión manual de ramas**: Moverse entre ambientes requiere `git checkout`, lo que puede causar conflictos con trabajo en progreso.
- **Merge de docker-compose.yml**: Al mergear `develop → qa`, se debe hacer checkout explícito del `docker-compose.yml` de QA para no sobreescribir la configuración de puertos. Esto está documentado pero es propenso a errores humanos.
- **No escalable a 4+ ambientes**: Si se agrega un ambiente `hotfix` o `staging`, el patrón numérico se rompe.
- **Credenciales hardcodeadas**: Los `docker-compose.yml` de develop/qa tienen credenciales en texto plano (`admin123`).

### Trade-offs
Simplicidad de uso vs. riesgo operacional. La estrategia es elegante para un equipo pequeño, pero requiere disciplina en el flujo de merges.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Un único conjunto de puertos con variables de entorno | Requiere gestión activa de `.env` por ambiente |
| Kubernetes namespaces por ambiente | Complejidad operacional excesiva para el equipo actual |
| Docker Compose profiles | Disponible pero requiere flags adicionales en cada comando |
| Puertos aleatorios asignados por Docker | Dificulta la configuración del gateway y el frontend |

---

## Impacto Arquitectónico

**Medio**. Afecta la configuración operacional de todos los servicios y la capacidad de ejecutar múltiples ambientes en paralelo.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Sobreescritura de docker-compose.yml en merge | Alta | Alto | CI/CD que preserva el archivo de destino automáticamente |
| Confusión de puertos entre ambientes | Baja | Medio | Documentación clara en README de cada servicio |
| Credenciales en texto plano en non-prod | Alta | Bajo | Aceptable en develop/qa; crítico en main (usar `.env`) |

---

## Relación con Otros Componentes

- **ADR-001**: El gateway usa esta estrategia para sus propios puertos.
- **ADR-014**: La red Docker compartida solo es necesaria dentro del mismo ambiente.
- **ADR-011**: La BD usa el mismo patrón para sus puertos.

---

## Consideraciones Futuras

- Automatizar la preservación de `docker-compose.yml` durante merges en CI/CD.
- Evaluar Docker Compose profiles como alternativa más elegante.
- Implementar un script de `make up-dev`, `make up-qa`, `make up-prod` que gestione el ambiente sin cambio de rama.

---

## Por qué es Behavioral

Es **Behavioral** porque determina el comportamiento de despliegue del sistema: qué puerto escucha cada servicio según el ambiente activo, y cómo el equipo puede cambiar entre ambientes mediante acciones de git.
