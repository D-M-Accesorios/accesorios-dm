# ADR-017: Arquitectura en Capas en el Inventory Service (Controller → Service → Repository → Entity)

| Campo | Valor |
|---|---|
| **ID** | ADR-017 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Design |
| **Servicios afectados** | Inventory Service |

---

## Contexto

El Inventory Service es el componente más complejo del sistema, gestionando catálogo de productos, categorías, materiales, promociones e imágenes. Necesita una organización interna que sea mantenible, testeable y que separe claramente las responsabilidades.

---

## Problema

¿Cómo organizar el código interno del Inventory Service para maximizar la mantenibilidad, facilitar el testing y respetar el principio de separación de responsabilidades?

---

## Decisión

Se implementó la **Arquitectura en Capas** estándar de Spring Boot, con responsabilidades claramente definidas por capa:

```
controller/    ← HTTP: recibe requests, valida input, devuelve responses
service/       ← Lógica de negocio, transacciones, coordinación
repository/    ← Acceso a datos via Spring Data JPA
entity/        ← Mapeo ORM a tablas de BD
dto/           ← Contratos de entrada/salida de la API
exception/     ← Manejo centralizado de errores
config/        ← Configuración (CORS, archivos, recursos estáticos)
storage/       ← Abstracción de almacenamiento de archivos
```

**Evidencia en código:**

```java
// Controller: solo HTTP
@RestController @RequestMapping("/productos")
public class ProductoController {
    private final ProductoService productoService;
    
    @GetMapping public ResponseEntity<List<ProductoResumenDTO>> getAllProductos() {
        return ResponseEntity.ok(productoService.getAllProductos());
    }
}

// Service: lógica de negocio + transacciones
@Service @Transactional
public class ProductoService {
    @Transactional(readOnly = true)
    public ProductoDTO getProductoById(Integer id) {
        Producto producto = productoRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Producto no encontrado"));
        return convertToFullDTO(producto);
    }
}

// Repository: solo acceso a datos
@Repository
public interface ProductoRepository extends JpaRepository<Producto, Integer> {
    @Query("SELECT p FROM Producto p WHERE p.estado = true AND p.stock > 0")
    List<Producto> findProductosDisponibles();
}

// Entity: mapeo a BD
@Entity @Table(name = "producto", schema = "catalogo")
public class Producto {
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_categoria", nullable = false)
    private Categoria categoria;
}
```

---

## Justificación Técnica

- **Separación de responsabilidades (SRP)**: Cada capa tiene una única razón para cambiar. Si el endpoint cambia, solo el Controller se modifica. Si la lógica de negocio cambia, solo el Service.
- **Testabilidad**: Cada capa es testeable independientemente con mocks de la capa inferior.
- **@Transactional en Service**: Las transacciones se gestionan en la capa de servicio, garantizando atomicidad de operaciones compuestas.
- **`readOnly = true`**: Todas las operaciones de lectura usan transacciones de solo lectura, optimizando el uso del pool de conexiones Hibernate.
- **Inyección por constructor**: `@RequiredArgsConstructor` (Lombok) garantiza que las dependencias son finales e inmutables, cumpliendo el principio de inversión de dependencias.

---

## Consecuencias

### Ventajas
- Código organizado y predecible para cualquier desarrollador Spring Boot.
- Testing unitario de la capa Service sin necesidad de arrancar el contexto Spring.
- Cambios en la API no afectan la lógica de negocio y viceversa.
- `@RestControllerAdvice` centraliza el manejo de errores fuera de los controllers.
- Spring Data JPA elimina el boilerplate de SQL para queries estándar.

### Desventajas
- **Acoplamiento entre capas**: El Controller depende del Service, que depende del Repository. No hay interfaces entre capas (no hay puertos/adaptadores).
- **DTOs mapeados manualmente**: No se usa MapStruct ni ModelMapper. El mapeo `Entity → DTO` se hace manualmente en el Service, generando código repetitivo.
- **Service muy acoplado a infraestructura**: `ProductoService` depende de 6 repositorios directamente, lo que podría indicar que necesita descomposición.
- **Sin interfaces de servicio**: Los controllers dependen directamente de la implementación concreta del Service, dificultando el mocking en tests.
- **Lógica duplicada**: `uploadImagenProducto` y `addImagenToProducto` hacen cosas similares.

### Trade-offs
Simplicidad y productividad Spring Boot vs. pureza de Clean Architecture. La arquitectura en capas es correcta para este tamaño; Hexagonal/Ports&Adapters sería sobre-ingeniería.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Hexagonal Architecture (Ports & Adapters) | Overhead de interfaces y adaptadores para el tamaño actual |
| CQRS dentro del servicio | Complejidad prematura |
| Arquitectura anémica (sin Service layer) | Lógica de negocio en controllers, no testeable |
| Domain-Driven Design completo | Requiere más contexto de dominio y equipo DDD |

---

## Impacto Arquitectónico

**Alto**. Define la organización interna del servicio más complejo del sistema y establece el patrón de referencia para futuros servicios.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Service layer creciendo demasiado | Media | Medio | Descomponer en servicios más pequeños por subdomain |
| Sin tests unitarios activos | Alta | Alto | Implementar tests con Mockito para la capa Service |
| N+1 queries por LAZY loading | Media | Medio | Usar @EntityGraph o JOIN FETCH donde sea necesario |

---

## Relación con Otros Componentes

- **ADR-018**: El patrón DTO es parte de la arquitectura en capas.
- **ADR-021**: JPA/Hibernate es el ORM de la capa Repository.
- **ADR-023**: Los índices de BD complementan las queries de la capa Repository.

---

## Consideraciones Futuras

- Introducir interfaces para la capa Service para facilitar el testing con mocks.
- Agregar MapStruct para eliminar el mapeo manual de Entity → DTO.
- Implementar tests unitarios con `@ExtendWith(MockitoExtension.class)`.
- Descomponer `ProductoService` si continúa creciendo en responsabilidades.

---

## Por qué es Design

Es **Design** porque define los patrones de diseño internos del servicio: cómo se organizan las clases, cómo se relacionan entre sí, y qué patrones arquitectónicos internos rigen la implementación.
