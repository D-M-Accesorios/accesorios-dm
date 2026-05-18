# ADR-021: JPA/Hibernate con ddl-auto=validate y Conexión Pool HikariCP

| Campo | Valor |
|---|---|
| **ID** | ADR-021 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Inventory Service |

---

## Contexto

El Inventory Service usa Spring Data JPA con Hibernate como ORM. En desarrollo temprano, es común usar `ddl-auto: update` o `create` para que Hibernate gestione automáticamente el esquema. Sin embargo, en un sistema con múltiples microservicios y un gestor de migraciones central (Liquibase), esta práctica es peligrosa.

---

## Problema

¿Qué estrategia de gestión del esquema de base de datos debe usar Hibernate en el Inventory Service? ¿Debe Hibernate crear/modificar el esquema, o simplemente validar que el esquema existente es compatible con las entidades mapeadas?

---

## Decisión

Se configuró `ddl-auto: validate` para que Hibernate **solo valide** que el esquema de BD es compatible con las entidades JPA, sin crear ni modificar ninguna tabla. La creación y modificación del esquema es responsabilidad exclusiva de Liquibase.

**Evidencia en código:**

```yaml
# accesorios-dm-inventory-service/src/main/resources/application.yml
spring:
  jpa:
    hibernate:
      ddl-auto: validate  # Solo valida, nunca modifica
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
    show-sql: true  # Visible en desarrollo para debugging

  datasource:
    hikari:
      connection-timeout: 30000
      maximum-pool-size: 10
      minimum-idle: 2
```

```java
// La entidad debe coincidir exactamente con la tabla de Liquibase
@Entity
@Table(name = "producto", schema = "catalogo")
public class Producto {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_producto")
    private Integer idProducto;
    // Si esta columna no existe en BD, el arranque falla con validación de Hibernate
}
```

---

## Justificación Técnica

- **Seguridad en producción**: `ddl-auto: validate` previene que Hibernate modifique el esquema en producción, lo que podría causar pérdida de datos o downtime.
- **Responsabilidad única**: Liquibase es el dueño del esquema; Hibernate es el dueño de la lógica de acceso. Esta separación evita conflictos.
- **Detección temprana de incompatibilidades**: Si hay un mismatch entre la entidad JPA y la tabla de BD, el servicio falla al arrancar con un error claro, no silenciosamente en runtime.
- **HikariCP configurado**: Pool de conexiones con `max=10, min-idle=2` evita abrir conexiones innecesarias y proporciona límite explícito de carga sobre PostgreSQL.
- **`show-sql: true`**: Visible en desarrollo para identificar queries N+1 y optimizaciones necesarias. Debe desactivarse en producción.

---

## Consecuencias

### Ventajas
- Cero riesgo de que Hibernate modifique o destruya datos en producción.
- Detección inmediata de incompatibilidades entre entidades y esquema.
- Pool de conexiones configurado explícitamente, sin usar defaults que podrían ser problemáticos.
- Las transacciones `@Transactional(readOnly = true)` se benefician de la configuración de HikariCP.

### Desventajas
- **Dependencia de orden de arranque**: El Inventory Service fallará al iniciar si Liquibase no ha ejecutado las migraciones primero. No hay `depends_on` entre contenedores de diferentes `docker-compose.yml`.
- **`show-sql: true` en producción**: La configuración actual muestra SQL en producción, lo que puede exponer información sensible en logs y degradar el performance.
- **SQL de Hibernate verboso en logs**: Los logs incluyen SQL completo y parámetros bind, aumentando el volumen de logs innecesariamente.
- **Pool de 10 conexiones máximas**: Con múltiples microservicios conectando a la misma BD, el total de conexiones puede superar los límites de PostgreSQL (default: 100).

### Trade-offs
Seguridad del esquema vs. friction en desarrollo. Con `validate`, cualquier cambio en Liquibase que no se refleje en la entidad JPA rompe el arranque. Esto es un contrato explícito y deseable.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| `ddl-auto: update` | Hibernate puede alterar tablas peligrosamente; conflicto con Liquibase |
| `ddl-auto: create` | Borra y recrea tablas en cada arranque; inaceptable en producción |
| `ddl-auto: create-drop` | Solo para testing; borra BD al apagar |
| `ddl-auto: none` | Sin validación; errores en runtime en lugar de startup |

---

## Impacto Arquitectónico

**Alto**. Define la relación entre Hibernate y Liquibase, y garantiza la integridad del esquema en todos los ambientes.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Inventory Service arranca antes que Liquibase | Alta | Alto | Script de arranque ordenado; retry en startup |
| `show-sql: true` en producción | Certero | Bajo | Mover a perfil `dev` solamente |
| Pool de 10 conexiones insuficiente bajo carga | Media | Medio | Ajustar según métricas reales de carga |

---

## Relación con Otros Componentes

- **ADR-012**: Liquibase es el complemento necesario para `ddl-auto: validate`.
- **ADR-011**: HikariCP comparte el pool de conexiones de la BD compartida.
- **ADR-014**: El orden de arranque de contenedores es crítico.

---

## Consideraciones Futuras

- Configurar perfiles Spring (`dev`, `prod`) para activar `show-sql` solo en dev.
- Implementar retry en el startup del Inventory Service para tolerar retrasos de Liquibase.
- Evaluar PgBouncer para reducir el número total de conexiones a PostgreSQL cuando se escale.

---

## Por qué es Design

Es **Design** porque define la estrategia de acceso a datos del Inventory Service: cómo Hibernate interactúa con la BD, qué nivel de control tiene sobre el esquema, y cómo se configura el pool de conexiones.
