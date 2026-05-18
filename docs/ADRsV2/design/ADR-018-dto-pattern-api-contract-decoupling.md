# ADR-018: Patrón DTO para Desacoplamiento entre Entidades JPA y Contratos de API

| Campo | Valor |
|---|---|
| **ID** | ADR-018 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Inventory Service |

---

## Contexto

El Inventory Service usa entidades JPA (`@Entity`) que mapean directamente a las tablas de base de datos. Si estas entidades se expusieran directamente en los endpoints REST, cualquier cambio en el modelo de datos impactaría inmediatamente el contrato de la API, y viceversa. Además, algunas propiedades de las entidades no deben ser expuestas (como relaciones bidireccionales que causan recursión infinita en la serialización JSON).

---

## Problema

¿Cómo evitar que los cambios en el modelo de datos de la base de datos afecten el contrato de la API, y cómo prevenir problemas de serialización JSON con relaciones JPA complejas?

---

## Decisión

Se adoptó el **Patrón DTO (Data Transfer Object)** con dos niveles de representación para los objetos más complejos: DTO completo para operaciones de escritura y detalle, y DTO de resumen para listados.

**DTOs implementados:**

| DTO | Propósito |
|---|---|
| `ProductoDTO` | Vista completa: CRUD de productos + relaciones (categoria, material, imágenes, promoción activa) |
| `ProductoResumenDTO` | Vista optimizada para listados: id, nombre, precio, precio con descuento, imagen principal, categoría |
| `CategoriaDTO` | Representación de categoría para APIs |
| `MaterialDTO` | Representación de material para APIs |
| `ImagenProductoDTO` | URL e información de imágenes |
| `PromocionDTO` | Datos de promoción para embedding en ProductoDTO |
| `PromocionProductoDTO` | Relación promoción-producto |
| `PrecioPromocionalRequest` | Request body para aplicar precio promocional |

**Evidencia en código:**

```java
// ProductoResumenDTO - optimizado para listados en frontend
public class ProductoResumenDTO {
    private Integer idProducto;
    private String nombre;
    private BigDecimal precio;
    private BigDecimal precioConDescuento;
    private String imagenPrincipal;  // Solo la primera imagen (no la lista completa)
    private String categoriaNombre;  // Solo el nombre (no el objeto Categoria completo)
}

// ProductoDTO - completo para detalle y CRUD
public class ProductoDTO {
    // ...todos los campos + relaciones completas como objetos DTO
    private CategoriaDTO categoria;
    private MaterialDTO material;
    private List<ImagenProductoDTO> imagenes;
    private PromocionDTO promocionActiva;  // Calculada en tiempo real
    private BigDecimal precioConDescuento; // Campo calculado, no en BD
}
```

---

## Justificación Técnica

- **Dos niveles de representación**: `ProductoResumenDTO` para listados (más liviano, para el catálogo del frontend) y `ProductoDTO` para detalle/admin. Esto reduce el payload en operaciones de lectura masiva.
- **Campos calculados en DTO**: `precioConDescuento` y `promocionActiva` no existen en la entidad; se calculan en la capa de Service. El DTO puede exponer datos derivados sin contaminar la entidad.
- **Prevención de serialización infinita**: `@ManyToOne(fetch = FetchType.LAZY)` en la entidad con relaciones bidireccionales causaría `StackOverflowError` al serializar directamente. El DTO solo incluye los campos necesarios.
- **Control sobre la API**: El contrato de la API puede cambiar (renombrar campos, añadir campos calculados) sin modificar la entidad JPA.

---

## Consecuencias

### Ventajas
- Listados de productos retornan solo los datos necesarios para el catálogo (reducción de payload ~60%).
- Cambios en el esquema de BD no impactan automáticamente la API.
- Los campos calculados (`precioConDescuento`) son ciudadanos de primera clase en la respuesta.
- Prevención de exposición de campos internos de la entidad (timestamps de auditoría, lazily-loaded collections).

### Desventajas
- **Mapeo manual repetitivo**: Sin MapStruct, el mapeo `Entity → DTO` se hace manualmente con código como `cat.setNombre(producto.getCategoria().getNombre())`. Es propenso a olvidar campos y requiere mantenimiento constante.
- **Duplicación de campo `precioConDescuento`**: `calcularPrecioConDescuento()` se llama tanto en `convertToResumenDTO()` como en `convertToFullDTO()`, ejecutando la misma query de promociones dos veces.
- **ProductoDTO como Request y Response**: El mismo DTO se usa para crear (`POST`) y obtener (`GET`) productos. Idealmente deberían ser `CreateProductoRequest` y `ProductoResponse` separados.

### Trade-offs
Control granular sobre el contrato vs. overhead de mantenimiento de DTOs. Con MapStruct, el costo se reduciría significativamente.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Exponer entidades JPA directamente | Acoplamiento, recursión de serialización, exposición de internos |
| Jackson `@JsonIgnore` en entidades | Mezcla responsabilidades de serialización con ORM |
| Projections de Spring Data | Limitado a operaciones de lectura; no para escritura |
| GraphQL | Exceso de complejidad para el caso de uso |

---

## Impacto Arquitectónico

**Medio-Alto**. El patrón DTO es el contrato visible de la API del servicio. Define qué datos viajan entre el cliente y el servidor.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Mapeo incompleto de campos | Media | Medio | Usar MapStruct para generación automática |
| Query N+1 por mapeo manual | Alta | Medio | Usar JOIN FETCH en queries de listado |
| Doble cálculo de precio promocional | Certero | Bajo | Extraer a variable local y reusar |

---

## Optimización Recomendada

```java
// En lugar de calcular dos veces:
private ProductoResumenDTO convertToResumenDTO(Producto producto) {
    BigDecimal precioFinal = calcularPrecioConDescuento(producto); // 1 query
    dto.setPrecioConDescuento(precioFinal);
}

private ProductoDTO convertToFullDTO(Producto producto) {
    BigDecimal precioFinal = calcularPrecioConDescuento(producto); // 2da query innecesaria
    dto.setPrecioConDescuento(precioFinal);
    // Además, si la promo se embebe en el DTO, es una 3ra query
    List<Promocion> promociones = promocionRepository.findPromocionesVigentesByProducto(...);
}
```

---

## Relación con Otros Componentes

- **ADR-017**: El DTO es parte de la arquitectura en capas; vive en la capa de contrato de API.
- **ADR-021**: Las entidades JPA son el modelo de datos; los DTOs son el modelo de vista.

---

## Consideraciones Futuras

- Introducir MapStruct para eliminar el mapeo manual.
- Separar `CreateProductoRequest` de `ProductoResponse`.
- Eliminar la doble consulta de precio promocional en el proceso de conversión.

---

## Por qué es Design

Es **Design** porque define el patrón de diseño para el flujo de datos entre la persistencia y la API, estableciendo cómo se estructuran y transforman los datos entre capas.
