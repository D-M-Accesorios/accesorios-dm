# ADR-014: Containerización Docker con Red Compartida Externa entre Servicios

| Campo | Valor |
|---|---|
| **ID** | ADR-014 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Todos los servicios, Base de Datos |

---

## Contexto

En una arquitectura de microservicios con múltiples servicios desplegados en contenedores Docker, cada servicio está en su propio repositorio y tiene su propio `docker-compose.yml`. Los servicios necesitan comunicarse entre sí (gateway → servicios, servicios → PostgreSQL) dentro de la red Docker sin exponer puertos internos al host.

---

## Problema

¿Cómo lograr que múltiples contenedores Docker definidos en `docker-compose.yml` independientes puedan comunicarse entre sí de forma segura, usando nombres de servicio DNS en lugar de IPs?

---

## Decisión

Se adoptó el patrón de **red Docker externa compartida** creada por el repositorio `accesorios-dm-database` y referenciada por todos los demás servicios como `external: true`.

**Evidencia en código:**

```yml
# accesorios-dm-database/docker-compose.prod.yml - CREA la red
networks:
  accesorios-network-prod:
    name: accesorios-dm-database_accesorios-network-prod
    driver: bridge

# accesorios-dm-api-gateway/docker-compose.yml - REFERENCIA la red
networks:
  accesorios-dm-net-prod:
    external: true
    name: accesorios-dm-database_accesorios-network-prod

# accesorios-dm-inventory-service/docker-compose.yml - REFERENCIA la red
networks:
  accesorios-dm-net-prod:
    external: true
    name: accesorios-dm-database_accesorios-network-prod
```

Los servicios se comunican usando nombres de contenedor como hostnames DNS:

```yml
# Inventory Service - conecta a BD por nombre de contenedor
SPRING_DATASOURCE_URL: jdbc:postgresql://accesorios-dm-postgres-prod:5432/accesorios_dm_db
# Gateway - conecta a servicios por nombre de contenedor
INVENTORY_HOST: accesorios-dm-inventory-service-prod
SECURITY_HOST: accesorios-dm-security-prod
```

---

## Justificación Técnica

- **DNS interno Docker**: Los contenedores en la misma red Docker Bridge se resuelven por nombre, eliminando la necesidad de IPs hardcodeadas.
- **Aislamiento de red**: Los servicios downstream (Inventory, Security, Payment) no exponen puertos internos al host; solo el gateway expone su puerto.
- **Separación de concerns**: Cada repositorio gestiona su propio `docker-compose.yml` pero todos comparten la misma red creada por la BD.
- **Orden de arranque implícito**: La BD debe levantarse primero (crea la red), luego los microservicios, luego el gateway. Esto refleja la dependencia real.

---

## Consecuencias

### Ventajas
- Comunicación segura entre servicios sin exposición de puertos internos al host.
- DNS automático por nombre de contenedor, sin gestión de IPs.
- Aislamiento de red: los servicios no son accesibles desde fuera de la red Docker.
- Arquitectura de red que puede trasladarse a Docker Swarm con cambios mínimos.

### Desventajas
- **Dependencia de orden de arranque**: Si los servicios se levantan antes que la BD (que crea la red), fallan con `network not found`. No hay `depends_on` cross-compose.
- **Nombre de red acoplado**: El nombre `accesorios-dm-database_accesorios-network-prod` incluye el nombre del proyecto de Docker Compose, lo que puede cambiar.
- **Sin health check cross-compose**: No existe mecanismo estándar para que el gateway espere a que los servicios downstream estén saludables.
- **Credenciales en texto plano**: `admin123` está hardcodeado en los `docker-compose.yml` de los microservicios para conectarse a la BD.
- **El gateway expone puertos a todos los servicios**: No hay restricciones de qué contenedor puede conectarse a cuál.

### Trade-offs
Simplicidad de configuración vs. control granular de seguridad de red. Para el contexto del proyecto, la red compartida simple es la solución correcta.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| `docker-compose.yml` maestro único | Contradice la estrategia polyrepo |
| Redes separadas por servicio | Mayor complejidad de configuración, sin beneficio para este tamaño |
| Kubernetes con namespaces | Overhead operacional excesivo para el equipo |
| Comunicación por host network | Pérdida de aislamiento de red |

---

## Impacto Arquitectónico

**Alto**. Define cómo los servicios se descubren y comunican entre sí en tiempo de ejecución.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Servicios levantan antes que BD (red no existe) | Alta | Alto | Script de arranque ordenado; documentar el orden |
| Credenciales BD en texto plano en compose | Certero | Alto | Usar `.env` para `DB_PASSWORD` (ya implementado en prod.yml) |
| Nombre de red cambia entre versiones | Baja | Medio | Hardcodear nombre de red explícito en todos los composes |

---

## Orden de Arranque Requerido

```bash
# 1. Base de datos (crea la red)
cd accesorios-dm-database && docker-compose up -d
# 2. Microservicios (se unen a la red)
cd accesorios-dm-inventory-service && docker-compose up -d
cd accesorios-dm-security-service && docker-compose up -d
cd accesorios-dm-payment-service && docker-compose up -d
# 3. Gateway (requiere que microservicios estén listos)
cd accesorios-dm-api-gateway && docker-compose up -d
```

---

## Relación con Otros Componentes

- **ADR-011**: La BD como creadora de la red refleja que es la dependencia base.
- **ADR-004**: Cada ambiente tiene su propia red nombrada con el sufijo del ambiente.
- **ADR-008**: Los healthchecks de Docker dependen de la conectividad de red.

---

## Consideraciones Futuras

- Crear un `docker-compose.yml` maestro en `dm-deployment` que gestione todos los servicios.
- Implementar scripts de arranque ordenado con verificación de health.
- Migrar credenciales de BD a secrets de Docker o variables de entorno en todos los ambientes.

---

## Por qué es Structural

Es **Structural** porque define la estructura de red y despliegue de todos los componentes del sistema: cómo se organizan en contenedores, cómo se comunican, y cómo se despliegan de forma coordinada.
