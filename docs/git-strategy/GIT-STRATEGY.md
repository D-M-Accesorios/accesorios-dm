# Git Branching Strategy — Accesorios DM

| Campo     | Valor                               |
|-----------|-------------------------------------|
| **Versión**| 1.0                                |
| **Fecha** | 2026-05-10                          |
| **Autor** | Sergio Andrés Losada Bahamón (SALB) |
| **Aplica a** | accesorios-dm-api-gateway, accesorios-dm-inventory-service, accesorios-dm-security-service |

---

## 1. Modelo de Ramas

El proyecto usa un modelo de tres ambientes permanentes con ramas de feature
por Historia de Usuario.

```
main        ← Producción. Solo recibe merges desde qa con aprobación.
  ↑
qa          ← Ambiente QA/Testing. Solo recibe merges desde develop.
  ↑
develop     ← Integración continua. Rama base para todas las HUs.
  ↑
HU-DEV-SALB_XX  ← Rama de feature por Historia de Usuario.
```

### Diagrama de flujo completo

```
                    ┌─────────────────────────────────────────┐
                    │              PRODUCCIÓN                  │
                    │                 main                     │
                    └──────────────────┬──────────────────────┘
                                       │ PR qa → main
                                       │ (aprobación manual requerida)
                    ┌──────────────────▼──────────────────────┐
                    │            AMBIENTE QA                   │
                    │                  qa                      │
                    └──────────────────┬──────────────────────┘
                                       │ PR develop → qa
                                       │ (al cerrar un ciclo de HUs)
                    ┌──────────────────▼──────────────────────┐
                    │         INTEGRACIÓN CONTINUA             │
                    │               develop                    │
                    └───┬───────────┬───────────┬─────────────┘
                        │           │           │
               PR        │  PR       │  PR       │
          ┌─────────┐ ┌──────────┐ ┌──────────┐
          │HU-DEV-  │ │HU-DEV-  │ │HU-DEV-  │
          │SALB_01  │ │SALB_05  │ │SALB_10  │
          └─────────┘ └──────────┘ └──────────┘
```

---

## 2. Ramas Permanentes

### `main` — Producción

| Propiedad | Valor |
|---|---|
| Ambiente | Producción |
| Push directo | ❌ Prohibido |
| Merge desde | `qa` únicamente |
| Requiere PR | ✅ Sí |
| Reviewers requeridos | 1 (mínimo) |
| Status checks | ✅ Requeridos (CI debe pasar) |
| Aprobación manual | ✅ Sí — deploy consciente |

**Regla**: ningún commit llega a `main` que no haya pasado por `develop` y `qa`.

### `qa` — Ambiente de pruebas

| Propiedad | Valor |
|---|---|
| Ambiente | QA / Testing |
| Push directo | ❌ Prohibido |
| Merge desde | `develop` únicamente |
| Requiere PR | ✅ Sí |
| Reviewers requeridos | 1 (mínimo) |
| Status checks | ✅ Requeridos |
| Cuándo mergear | Al cerrar un ciclo de HUs listas para pruebas |

### `develop` — Integración continua

| Propiedad | Valor |
|---|---|
| Ambiente | Desarrollo / CI |
| Push directo | ❌ Prohibido |
| Merge desde | Ramas `HU-DEV-SALB_XX` |
| Requiere PR | ✅ Sí |
| Reviewers requeridos | 1 (mínimo) |
| Status checks | ✅ Requeridos |
| Cuándo mergear | Cuando la HU cumple la Definición de Done |

---

## 3. Ramas de Feature (HUs)

### Convención de nomenclatura

```
HU-DEV-SALB_XX
```

| Segmento | Descripción |
|---|---|
| `HU` | Tipo — Historia de Usuario |
| `DEV` | Fase — Desarrollo |
| `SALB` | Autor — Sergio Andrés Losada Bahamón |
| `XX` | Número secuencial global (01, 02, 03...) |

**Ejemplos:**
```
HU-DEV-SALB_01   ← Configuración base NestJS
HU-DEV-SALB_05   ← Auth Guard JWT RS256
HU-DEV-SALB_10   ← Configuración base Spring Boot
HU-DEV-SALB_14   ← CRUD de Productos
```

### Reglas de ramas de feature

- Se crean **siempre desde `develop`** actualizado.
- Tienen una **única responsabilidad**: la HU que representan.
- Se **eliminan del remoto** tras el merge a `develop`.
- El número de HU es **globalmente único** en todo el proyecto (sin importar el repo).
- **Nunca** se mergean directamente a `qa` o `main`.

### Ciclo de vida

```bash
# 1. Actualizar develop
git checkout develop
git pull origin develop

# 2. Crear rama de la HU
git checkout -b HU-DEV-SALB_05

# 3. Desarrollar con commits atómicos
git commit -m "feat(HU-DEV-SALB_05): add JWT RS256 auth guard"
git commit -m "test(HU-DEV-SALB_05): add auth guard unit tests"

# 4. Push y Pull Request hacia develop
git push origin HU-DEV-SALB_05
# → Abrir PR en GitHub

# 5. Tras merge aprobado, eliminar la rama
git branch -d HU-DEV-SALB_05
git push origin --delete HU-DEV-SALB_05
```

---

## 4. Ramas de Hotfix

Para correcciones urgentes en producción que no pueden esperar un ciclo completo:

```
hotfix/descripcion-breve
```

**Flujo especial del hotfix:**

```bash
# 1. Crear desde main (no desde develop)
git checkout main
git pull origin main
git checkout -b hotfix/fix-jwt-validation

# 2. Aplicar la corrección

# 3. PR hacia main (con aprobación)
# 4. Tras merge a main → PR hacia develop también
#    para que develop no pierda el fix
```

> ⚠️ Los hotfixes que llegan a `main` **deben** mergearse también a `develop`
> para mantener la coherencia del historial.

---

## 5. Convención de Mensajes de Commit

Se adopta **Conventional Commits** como estándar:

```
<tipo>(<scope>): <descripción en imperativo, minúsculas>
```

### Tipos permitidos

| Tipo | Cuándo usar |
|---|---|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Refactorización sin cambio de comportamiento |
| `test` | Añadir o modificar tests |
| `docs` | Cambios en documentación |
| `chore` | Mantenimiento, configuración, dependencias |
| `ci` | Cambios en pipelines de CI/CD |

### Scope

El scope es el ID de la HU o el módulo afectado:

```
feat(HU-DEV-SALB_05): add JWT RS256 validation guard
fix(HU-DEV-SALB_14): correct BigDecimal serialization for precio field
test(HU-DEV-SALB_11): add ControllerAdvice unit tests
chore(deps): update spring-boot to 3.2.5
docs(readme): add local setup instructions
```

### Reglas de commits

- Descripción en **minúsculas**, sin punto final.
- Máximo **72 caracteres** en la primera línea.
- Usar el **imperativo**: "add", "fix", "update" — no "added", "fixed", "updating".
- Los commits deben ser **atómicos**: un cambio lógico por commit.
- **No** hacer commits con mensajes como "wip", "fix stuff", "cambios", "update".

---

## 6. Pull Requests

### Título del PR

```
[HU-DEV-SALB_XX] Título de la Historia de Usuario
```

Ejemplos:
```
[HU-DEV-SALB_05] Auth Guard con validación JWT RS256
[HU-DEV-SALB_14] CRUD de Productos — Inventory Service
```

### Proceso de PR

1. El autor abre el PR usando la plantilla `.github/pull_request_template.md`.
2. Asigna al menos **1 reviewer**.
3. El reviewer verifica:
   - Que la implementación cumple los criterios de aceptación de la HU.
   - Que los ADRs referenciados en la HU están siendo respetados.
   - Que el código no contiene secretos, hardcoding ni lógica fuera del scope.
4. El CI debe pasar antes de que el reviewer apruebe.
5. Tras aprobación, el **autor** hace el merge (no el reviewer).
6. El autor elimina la rama remota tras el merge.

### Reglas de merge

| Destino | Estrategia de merge | Razón |
|---|---|---|
| `develop` | **Squash and merge** | Historial limpio en develop |
| `qa` | **Merge commit** | Trazabilidad del ciclo de QA |
| `main` | **Merge commit** | Trazabilidad del release |

---

## 7. Flujo entre Ambientes

### develop → qa

Se hace cuando un conjunto de HUs está listo para testing en QA:

```
Condiciones para abrir PR develop → qa:
- Al menos 1 HU crítica completada y mergeada a develop
- El ambiente develop está estable (todos los tests pasan)
- Se notifica al equipo de QA que el ambiente está listo
```

### qa → main

Se hace cuando QA valida el ambiente y autoriza el paso a producción:

```
Condiciones para abrir PR qa → main:
- QA validó los flujos críticos en el ambiente qa
- No hay bugs bloqueantes abiertos
- El Tech Lead aprueba el release
- Se documenta qué HUs entran en el release (release notes)
```

---

## 8. Limpieza de Ramas

### Ramas a limpiar al adoptar esta estrategia

Al iniciar el desarrollo bajo esta convención, las siguientes ramas con la
nomenclatura anterior deben ser evaluadas y cerradas:

**accesorios-dm-api-gateway:**
- `feature/HU-01-initial-api-gateway` → revisar si hay trabajo pendiente o cerrar.
- `feature/HU-02-rutas-catalogo-gateway` → revisar si hay trabajo pendiente o cerrar.

**accesorios-dm-inventory-service:**
- `dev` → rama sin equivalente en remoto, verificar y eliminar.
- `feature/refactor-inventory-service` → revisar si hay trabajo pendiente o cerrar.

> **Proceso de limpieza**: antes de eliminar una rama, verificar con
> `git log develop..rama` si tiene commits que no están en `develop`. Si los
> tiene, decidir si incorporarlos o descartarlos conscientemente.

---

## 9. Configuración de Branch Protection en GitHub

Las siguientes reglas deben configurarse en GitHub → Settings → Branches para
cada repositorio.

### Rama `main`

```
✅ Require a pull request before merging
   ✅ Require approvals: 1
   ✅ Dismiss stale pull request approvals when new commits are pushed
✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
✅ Require conversation resolution before merging
✅ Do not allow bypassing the above settings
❌ Allow force pushes → DESHABILITADO
❌ Allow deletions → DESHABILITADO
```

### Rama `qa`

```
✅ Require a pull request before merging
   ✅ Require approvals: 1
✅ Require status checks to pass before merging
✅ Require conversation resolution before merging
❌ Allow force pushes → DESHABILITADO
❌ Allow deletions → DESHABILITADO
```

### Rama `develop`

```
✅ Require a pull request before merging
   ✅ Require approvals: 1
✅ Require status checks to pass before merging
❌ Allow force pushes → DESHABILITADO
❌ Allow deletions → DESHABILITADO
```

---

## 10. Resumen de Reglas

| # | Regla |
|---|---|
| R1 | Las ramas permanentes (`main`, `qa`, `develop`) nunca reciben push directo |
| R2 | Todo cambio entra por PR con al menos 1 aprobación |
| R3 | Las ramas de feature siguen la convención `HU-DEV-SALB_XX` |
| R4 | Las ramas de feature se crean desde `develop` y se eliminan tras el merge |
| R5 | El número de HU es globalmente único en todo el proyecto |
| R6 | Los commits siguen Conventional Commits con scope de HU |
| R7 | Los hotfixes desde `main` deben mergearse también a `develop` |
| R8 | El merge a `develop` usa Squash; los merges a `qa` y `main` usan Merge Commit |
| R9 | Ninguna HU salta de `feature` directamente a `qa` o `main` |
