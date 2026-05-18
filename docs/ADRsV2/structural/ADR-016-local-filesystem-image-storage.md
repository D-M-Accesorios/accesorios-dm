# ADR-016: Almacenamiento de Imágenes de Productos en Sistema de Archivos Local

| Campo | Valor |
|---|---|
| **ID** | ADR-016 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Inventory Service |

---

## Contexto

El catálogo de productos requiere almacenar y servir imágenes de cada producto. Las imágenes son archivos binarios que pueden tener tamaños entre 100KB y varios MB. Se necesita una estrategia de almacenamiento que sea simple de implementar en el MVP pero que no comprometa la escalabilidad futura.

---

## Problema

¿Dónde y cómo almacenar los archivos de imagen de productos: en la base de datos (blobs), en el sistema de archivos local del contenedor, o en almacenamiento en nube (S3, GCS)?

---

## Decisión

Se adoptó **almacenamiento en el sistema de archivos local del contenedor con volume mount al host**, sirviendo las imágenes como archivos estáticos a través del mismo Inventory Service. Las imágenes se organizan en una estructura de carpetas `uploads/productos/{productoId}/{uuid}.ext`.

**Evidencia en código:**

```java
// accesorios-dm-inventory-service/src/main/java/com/accesoriosdm/inventory/service/ProductoService.java
Path carpetaProducto = Paths.get(imagesPath, "productos", productoId.toString());
Files.createDirectories(carpetaProducto);
String nombreArchivo = UUID.randomUUID() + extension;
Files.copy(file.getInputStream(), rutaArchivo, StandardCopyOption.REPLACE_EXISTING);
String urlImagen = "/uploads/productos/" + productoId + "/" + nombreArchivo;
```

```yaml
# application.yml
app:
  storage:
    images-path: /app/uploads/productos
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 50MB
```

```yml
# docker-compose.yml del Inventory Service
volumes:
  - ./uploads:/app/uploads  # Persistencia en el host
```

```java
// accesorios-dm-inventory-service/src/main/java/com/accesoriosdm/inventory/config/StaticResourceConfig.java
// Sirve archivos estáticos desde /uploads/* → /app/uploads/
```

El API Gateway también tiene un proxy dedicado para uploads:

```js
// accesorios-dm-api-gateway/src/routes/index.js
const uploadsProxy = createProxyMiddleware({
    target: `http://${config.services.inventory.host}:${config.services.inventory.port}`,
    changeOrigin: true
});
router.use('/uploads', uploadsProxy);
```

---

## Justificación Técnica

- **Cero dependencias externas**: No requiere cuenta en AWS/GCS, sin costos adicionales de infraestructura en el MVP.
- **Implementación inmediata**: `Files.copy()` y `@Value` son suficientes; no hay SDK que aprender.
- **Volume mount para persistencia**: Las imágenes sobreviven reinicios del contenedor gracias al mount `./uploads:/app/uploads`.
- **UUID como nombre de archivo**: Previene colisiones y evita path traversal al no usar el nombre original del archivo.
- **Separación por producto**: `productos/{productoId}/` facilita la gestión y eliminación de imágenes por producto.

---

## Consecuencias

### Ventajas
- Sin costos de almacenamiento externo.
- Implementación simple con APIs estándar de Java NIO.
- Las URLs de imágenes son relativas (`/uploads/productos/...`), facilitando el consumo desde el frontend.
- El proxy del gateway sirve las imágenes con el mismo dominio que el API.

### Desventajas
- **No escalable horizontalmente**: Si el Inventory Service tiene múltiples réplicas, cada una tiene su propio sistema de archivos local. Las imágenes de una réplica no son visibles en otras.
- **Sin CDN**: Cada request de imagen pasa por el Spring Boot → Gateway, sin caching de assets estáticos.
- **Backup manual**: Las imágenes no están incluidas automáticamente en el backup de PostgreSQL.
- **Límite de disco**: El host tiene capacidad limitada; sin alertas de espacio en disco.
- **Sin optimización de imágenes**: No hay resize, compresión o generación de thumbnails.
- **`StorageService` duplicado**: Existe `StorageService.java` y lógica duplicada en `ProductoService.uploadImagenProducto()`.

### Trade-offs
Velocidad de implementación y cero costo vs. escalabilidad y disponibilidad. Para MVP de un emprendimiento pequeño, es la decisión correcta a corto plazo.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| AWS S3 / Google Cloud Storage | Costo mensual + complejidad de integración |
| Cloudinary | API pública simple pero costo y dependencia externa |
| PostgreSQL bytea (imágenes en BD) | Impacto severo en performance de queries |
| MinIO (S3-compatible local) | Complejidad operacional adicional sin beneficio en MVP |

---

## Impacto Arquitectónico

**Medio**. Funciona para una instancia única. Bloquea la escalabilidad horizontal del Inventory Service.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Pérdida de imágenes al recrear contenedor | Media | Alto | Volume mount ya implementado; agregar backup periódico |
| Disco lleno sin alertas | Media | Alto | Configurar alerta de uso de disco |
| Sin escalabilidad horizontal | Baja | Alto | Aceptable para MVP; planificar migración a S3/Cloudinary |

---

## Relación con Otros Componentes

- **ADR-001**: El gateway tiene ruta dedicada `/uploads` para proxy de imágenes.
- **ADR-011**: Las URLs de imágenes se almacenan en la tabla `catalogo.imagen_producto`.

---

## Consideraciones Futuras

- Migrar a Cloudinary o AWS S3 cuando el volumen de imágenes crezca o se requieran múltiples réplicas.
- Implementar compresión y resize de imágenes al upload.
- Consolidar `StorageService.java` y la lógica duplicada en `ProductoService`.
- Agregar validación de tipo de archivo (solo imágenes) y límite de tamaño por producto.

---

## Por qué es Structural

Es **Structural** porque define la estructura de almacenamiento de assets del sistema: dónde se guardan, cómo se organizan en el filesystem, cómo se sirven al cliente, y cuáles son las limitaciones de escala de esa estructura.
