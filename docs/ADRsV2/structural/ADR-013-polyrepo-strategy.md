# ADR-013: Estrategia Polyrepo — Repositorio Git Independiente por Servicio

| Campo | Valor |
|---|---|
| **ID** | ADR-013 |
| **Estado** | Aceptado |
| **Fecha** | 2026-05-18 |
| **Categoría** | Structural |
| **Servicios afectados** | Todo el ecosistema de repositorios |

---

## Contexto

El sistema está compuesto por múltiples componentes: API Gateway, Inventory Service, Security Service, Payment Service, base de datos, frontend y mobile. Cada componente puede ser desarrollado por diferentes integrantes del equipo. Se debe decidir si todos los componentes viven en un único repositorio (monorepo) o en repositorios separados (polyrepo).

---

## Problema

¿Cómo organizar el código fuente del sistema en repositorios de control de versiones para maximizar la independencia de los equipos, facilitar el despliegue independiente y mantener ciclos de releases desacoplados?

---

## Decisión

Se adoptó una estrategia **Polyrepo**: cada servicio vive en su propio repositorio Git independiente bajo la organización `SergioLosadaDev`.

| Repositorio | Responsabilidad |
|---|---|
| `accesorios-dm` | Documentación central del proyecto |
| `accesorios-dm-api-gateway` | API Gateway |
| `accesorios-dm-inventory-service` | Servicio de inventario y catálogo |
| `accesorios-dm-security-service` | Autenticación y usuarios |
| `accesorios-dm-payment-service` | Carrito, pedidos y pagos |
| `accesorios-dm-database` | Migraciones de base de datos |
| `accesorios-dm-frontend` | Portal web Angular |
| `dm-deployment` | Scripts de infraestructura y Docker Compose maestro |

**Evidencia**: Cada directorio en `DmApp/` tiene su propio `.git/` con historial independiente.

---

## Justificación Técnica

- **Independencia de releases**: El Inventory Service puede hacer release sin esperar cambios en Payment o Security.
- **Autonomía de equipos**: Cada desarrollador (SALB: DevOps, DYC: QA, JSA: Backend, DMC: Frontend) puede trabajar en su repositorio sin conflictos de merge.
- **Permisos granulares**: Se pueden gestionar permisos de acceso por repositorio en GitHub.
- **Historial limpio**: El historial de commits de cada servicio solo contiene cambios relevantes a ese servicio.
- **CI/CD independiente**: Cada repositorio puede tener su propio pipeline sin activar builds innecesarios.

---

## Consecuencias

### Ventajas
- Ciclos de deploy completamente independientes por servicio.
- Sin "big bang merges" que afecten a todo el sistema simultáneamente.
- Equipos no se bloquean entre sí por conflictos en el mismo repositorio.
- El tamaño del repositorio es manejable para cada desarrollador.

### Desventajas
- **Cambios atómicos cross-repo son imposibles**: Si un cambio en el schema de la BD requiere cambios simultáneos en 3 servicios, no existe un mecanismo de "transacción de commits" entre repositorios.
- **Versionado de contratos de API**: No hay definición de contratos OpenAPI compartidos que garanticen compatibilidad entre repos.
- **Overhead de coordinación**: Sincronizar cambios que afectan múltiples servicios requiere coordinación manual.
- **Sin shared libraries**: Código común (DTOs de error, validaciones) se duplica en cada servicio.
- **Descubrimiento de código difícil**: Un desarrollador nuevo debe clonar múltiples repositorios para entender el sistema completo.
- **La carpeta `DmApp/` es un "monorepo manual"**: El directorio de trabajo local agrega todos los repos, lo que contradice parcialmente el propósito del polyrepo.

### Trade-offs
Autonomía de equipos vs. cohesión del sistema. Polyrepo funciona bien cuando los contratos de API están estables. Con contratos en evolución frecuente, genera overhead de coordinación.

---

## Alternativas Consideradas

| Alternativa | Razón de descarte |
|---|---|
| Monorepo (Nx o Turborepo) | Requiere herramientas especializadas; todos los PRs afectan el mismo repo |
| Monorepo simple (sin herramientas) | Merges complejos, historial mezclado, CI/CD difícil |
| Polyrepo con packages compartidos | Requiere registro de paquetes privado (npm privado, PyPI privado) |

---

## Impacto Arquitectónico

**Alto**. Define cómo se organiza, versiona y coordina todo el desarrollo del sistema.

---

## Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|
| Incompatibilidad de APIs entre repos | Media | Alto | Definir y versionar contratos OpenAPI |
| Pérdida de visión global del sistema | Alta | Medio | Mantener `accesorios-dm` como repo de documentación central |
| Sincronización manual propensa a errores | Alta | Medio | Automatizar con scripts en `dm-deployment` |

---

## Relación con Otros Componentes

- **ADR-004**: La estrategia de ramas (develop/qa/main) se aplica independientemente en cada repo.
- **ADR-014**: El repo `dm-deployment` gestiona la composición de todos los servicios.

---

## Consideraciones Futuras

- Crear un repositorio de contratos OpenAPI compartido.
- Implementar `dm-deployment` con Docker Compose maestro que gestione todos los servicios.
- Evaluar migración a monorepo con Nx si el número de servicios crece significativamente.

---

## Por qué es Structural

Es **Structural** porque define la estructura de organización del código fuente del sistema: dónde vive cada componente, cómo se versionan, y cómo se relacionan los repositorios entre sí.
