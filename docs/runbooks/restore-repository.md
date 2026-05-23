# Runbook: Restauración de Repositorio Eliminado

**RTO objetivo:** 2 horas  
**RPO objetivo:** 24 horas (último backup diario)

---

## Cuándo usar este runbook

- Un repositorio de la organización `D-M-Accesorios` fue eliminado accidentalmente
- El issue de incidente ya fue creado automáticamente por `audit-monitor`
- El `verify-branch-protection` detectó un repositorio faltante

---

## Paso 1 — Confirmar el incidente

```bash
# Verificar el audit log para confirmar la eliminación
gh api "orgs/D-M-Accesorios/audit-log?phrase=action:repo.destroy&per_page=10" \
  --jq '.[] | "DELETED: \(.repo) by \(.actor) at \(.created_at)"'
```

Confirmar:
- Nombre exacto del repositorio eliminado
- Quién lo eliminó (`actor`)
- Cuándo ocurrió (`created_at`)

---

## Paso 2 — Localizar el backup

Los backups están en GitHub Artifacts del workflow `org-backup`:

```
https://github.com/D-M-Accesorios/accesorios-dm/actions/workflows/org-backup.yml
```

1. Abrir el último run exitoso de `org-backup`
2. En la sección **Artifacts**, descargar: `dm-accesorios-backup-YYYYMMDD_HHMMSS.tar.gz`
3. Verificar que la fecha del backup es anterior a la eliminación

---

## Paso 3 — Extraer el repositorio del backup

```bash
# Crear directorio de trabajo
mkdir -p /tmp/restore && cd /tmp/restore

# Extraer el backup (ajustar nombre del archivo)
tar -xzf ~/Downloads/dm-accesorios-backup-YYYYMMDD_HHMMSS.tar.gz

# Verificar que el repo está en el backup
ls /tmp/restore/
# Debes ver: accesorios-dm-{repo-name}.git

# Inspeccionar el contenido del mirror
git -C /tmp/restore/accesorios-dm-{repo-name}.git log --oneline | head -10
```

---

## Paso 4 — Recrear el repositorio en GitHub

```bash
export GH_TOKEN="tu-pat-con-scope-repo-admin-org"
REPO_NAME="accesorios-dm-{nombre-del-repo}"

# Crear repositorio privado
gh repo create "D-M-Accesorios/${REPO_NAME}" \
  --private \
  --description "Restaurado desde backup el $(date +%Y-%m-%d)"

echo "✅ Repositorio creado: https://github.com/D-M-Accesorios/${REPO_NAME}"
```

---

## Paso 5 — Restaurar el código desde el mirror

```bash
# Hacer push de todo el mirror (branches + tags) al nuevo repositorio
git -C /tmp/restore/${REPO_NAME}.git push \
  "https://x-access-token:${GH_TOKEN}@github.com/D-M-Accesorios/${REPO_NAME}.git" \
  --mirror

echo "✅ Mirror restaurado a GitHub"
```

---

## Paso 6 — Reaplicar branch protection

```bash
# Desde la raíz del repositorio accesorios-dm
cd /path/to/accesorios-dm

# Aplicar solo al repo restaurado
ORG=D-M-Accesorios \
  TARGET_REPO="${REPO_NAME}" \
  ./scripts/setup-branch-protection.sh

# Verificar que la protección fue aplicada
gh api "repos/D-M-Accesorios/${REPO_NAME}/branches/main/protection" \
  --jq '{enforce_admins: .enforce_admins.enabled, required_reviews: .required_pull_request_reviews.required_approving_review_count}'
```

---

## Paso 7 — Verificar integridad del restore

```bash
# Comparar branches restaurados con el backup
REMOTE_BRANCHES=$(gh api "repos/D-M-Accesorios/${REPO_NAME}/branches" \
  --jq '.[].name' | sort)
LOCAL_BRANCHES=$(git -C /tmp/restore/${REPO_NAME}.git branch -r | \
  sed 's|.*HEAD.*||' | sed 's|origin/||' | sort)

echo "Branches en GitHub:"
echo "$REMOTE_BRANCHES"
echo ""
echo "Branches en backup:"
echo "$LOCAL_BRANCHES"
```

---

## Paso 8 — Notificar y cerrar el incidente

1. Actualizar el issue de incidente con el resultado del restore
2. Notificar al equipo en Slack (`#security-alerts`)
3. Documentar la causa raíz y las acciones preventivas

```bash
# Cerrar el issue de incidente con nota de resolución
gh issue comment {ISSUE_NUMBER} \
  --repo "D-M-Accesorios/accesorios-dm" \
  --body "✅ Repositorio restaurado exitosamente desde backup del $(date +%Y-%m-%d).

Tiempo de restauración: {X} minutos
Branch protection reaplicada: ✅
Verificación de integridad: ✅

Causa raíz: {DESCRIPCIÓN}
Acción preventiva: {DESCRIPCIÓN}"

gh issue close {ISSUE_NUMBER} \
  --repo "D-M-Accesorios/accesorios-dm"
```

---

## Referencias

- Workflow de backup: `.github/workflows/org-backup.yml`
- Script de branch protection: `scripts/setup-branch-protection.sh`
- Audit log de la org: `https://github.com/organizations/D-M-Accesorios/settings/audit-log`
