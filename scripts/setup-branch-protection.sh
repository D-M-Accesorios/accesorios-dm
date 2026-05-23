#!/usr/bin/env bash
# setup-branch-protection.sh
#
# Configura Branch Protection Rules en todos los repos de la organización.
#
# Prerrequisitos:
#   1. gh CLI instalado y autenticado: gh auth login
#   2. Token con scope: repo (o admin:org para org-level rulesets)
#   3. Los workflows DEBEN estar mergeados a main antes de ejecutar este script,
#      de lo contrario el required status check no existe aún en GitHub.
#
# Uso:
#   chmod +x setup-branch-protection.sh
#   ORG=D-M-Accesorios ./setup-branch-protection.sh
#
#   Para modo simulación (ver qué haría sin aplicar):
#   DRY_RUN=true ORG=D-M-Accesorios ./setup-branch-protection.sh

set -euo pipefail

ORG="${ORG:-D-M-Accesorios}"
DRY_RUN="${DRY_RUN:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REPOS=(
  "accesorios-dm-api-gateway"
  "accesorios-dm-database"
  "accesorios-dm-inventory-service"
  "accesorios-dm-payment-service"
  "accesorios-dm-security-service"
  "accesorios-dm-frontend"
)

# Nombres exactos de los jobs en los workflows de validación
# GitHub registra el check como el job id del workflow
STATUS_CHECK_FLOW="validate-branch-flow"
STATUS_CHECK_COMMITS="validate-commits"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Branch Protection Setup — D-M-Accesorios              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Organización : ${ORG}"
echo -e "  Modo         : $( [ "$DRY_RUN" = "true" ] && echo "${YELLOW}SIMULACIÓN (DRY RUN)${NC}" || echo "${GREEN}APLICANDO CAMBIOS${NC}" )"
echo -e "  Status checks: ${STATUS_CHECK_FLOW}, ${STATUS_CHECK_COMMITS}"
echo ""

# Verificar autenticación
if ! gh auth status &>/dev/null; then
  echo -e "${RED}❌ No autenticado en gh CLI. Ejecuta: gh auth login${NC}"
  exit 1
fi

apply_protection() {
  local repo="$1"
  local branch="$2"
  local required_reviews="$3"      # número de reviews requeridos
  local require_codeowners="$4"    # true/false

  echo -e "  ${CYAN}→ ${repo}/${branch}${NC}"

  if [ "$DRY_RUN" = "true" ]; then
    echo -e "    ${YELLOW}[DRY RUN] Aplicaría protección con ${required_reviews} review(s)${NC}"
    return 0
  fi

  # Construir payload de branch protection
  local payload
  payload=$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      {
        "context": "${STATUS_CHECK_FLOW}",
        "app_id": -1
      },
      {
        "context": "${STATUS_CHECK_COMMITS}",
        "app_id": -1
      }
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": ${require_codeowners},
    "required_approving_review_count": ${required_reviews},
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false
}
JSON
)

  if gh api \
    "repos/${ORG}/${repo}/branches/${branch}/protection" \
    -X PUT \
    --input - <<< "$payload" > /dev/null 2>&1; then
    echo -e "    ${GREEN}✓ Protección aplicada${NC}"
  else
    echo -e "    ${RED}✗ Error aplicando protección — verificar permisos${NC}"
    return 1
  fi
}

TOTAL_OK=0
TOTAL_FAIL=0

for repo in "${REPOS[@]}"; do
  echo ""
  echo -e "${CYAN}┌─ ${repo}${NC}"

  # develop: 1 review, sin require_codeowners (hasta que CODEOWNERS esté activo)
  if apply_protection "$repo" "develop" 1 "true"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi

  # qa: 1 review, con codeowners
  if apply_protection "$repo" "qa" 1 "true"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi

  # main: 2 reviews, con codeowners (más restrictivo)
  if apply_protection "$repo" "main" 2 "true"; then
    TOTAL_OK=$((TOTAL_OK + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi

  echo -e "${CYAN}└─ done${NC}"
done

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Resumen                                                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Configuraciones exitosas : ${GREEN}${TOTAL_OK}${NC}"
echo -e "  Configuraciones fallidas : $( [ "$TOTAL_FAIL" -gt 0 ] && echo "${RED}${TOTAL_FAIL}${NC}" || echo "${GREEN}0${NC}" )"
echo ""

if [ "$DRY_RUN" != "true" ] && [ "$TOTAL_OK" -gt 0 ]; then
  echo -e "${GREEN}✅ Branch protection configurada correctamente.${NC}"
  echo ""
  echo -e "  ${YELLOW}Pasos siguientes:${NC}"
  echo ""
  echo -e "  1. Verificar que los checks aparecen en los PRs:"
  echo -e "     Checks requeridos: '${STATUS_CHECK_FLOW}' y '${STATUS_CHECK_COMMITS}'"
  echo -e "     Crear un PR de prueba con una rama inválida (ej: test-rama → develop)"
  echo -e "     Ambos checks deben aparecer. El de flujo debe fallar automáticamente."
  echo ""
  echo -e "  2. Activar CODEOWNERS en GitHub:"
  echo -e "     Ir a cada repo → Settings → Branches → main → Edit"
  echo -e "     Verificar que 'Require review from Code Owners' está marcado."
  echo ""
  echo -e "  3. Crear equipos en la organización:"
  echo -e "     https://github.com/orgs/${ORG}/teams"
  echo -e "     Crear: 'leads', 'backend', 'frontend', 'dba'"
  echo -e "     Agregar miembros a cada equipo."
  echo ""
  echo -e "  4. Configurar permisos de la organización (manual en GitHub UI):"
  echo -e "     https://github.com/organizations/${ORG}/settings/member_privileges"
  echo -e "     → Repository deletion and transfer: DESMARCAR"
  echo ""
  echo -e "  5. Configurar Secrets necesarios en accesorios-dm:"
  echo -e "     ORG_BACKUP_TOKEN  — PAT con scope: repo (para backup)"
  echo -e "     ORG_AUDIT_TOKEN   — PAT con scope: read:audit_log (para audit monitor)"
  echo -e "     ORG_ADMIN_TOKEN   — PAT con scope: repo, workflow (para sync)"
  echo -e "     SLACK_WEBHOOK_URL — Webhook de Slack para notificaciones"
  echo -e "     ORG_NAME          — Variable (no secret): D-M-Accesorios"
fi

if [ "$TOTAL_FAIL" -gt 0 ]; then
  exit 1
fi
