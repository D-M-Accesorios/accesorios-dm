#!/usr/bin/env bash
# create-org-rulesets.sh
#
# Crea Org-level Rulesets en GitHub para proteger las ramas main, qa y develop
# en TODOS los repositorios de la organización, incluyendo los que se creen en el futuro.
#
# Los Rulesets de organización son más robustos que Branch Protection Rules porque:
#   - Se aplican automáticamente a repos nuevos
#   - No requieren configuración por repositorio
#   - Permiten required_workflows desde un repo central
#
# Prerrequisitos:
#   1. gh CLI instalado: brew install gh
#   2. Autenticado con scope admin:org: gh auth login
#   3. Los workflows validate-branch-flow.yml y validate-commits.yml deben estar
#      mergeados en main del repo accesorios-dm antes de ejecutar este script.
#
# Uso:
#   chmod +x create-org-rulesets.sh
#   ORG=D-M-Accesorios ./create-org-rulesets.sh
#
#   Modo simulación:
#   DRY_RUN=true ORG=D-M-Accesorios ./create-org-rulesets.sh

set -euo pipefail

ORG="${ORG:-D-M-Accesorios}"
GOVERNANCE_REPO="${GOVERNANCE_REPO:-accesorios-dm}"
DRY_RUN="${DRY_RUN:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   Org Rulesets Setup — ${ORG}${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Organización     : ${ORG}"
echo -e "  Repo gobernanza  : ${GOVERNANCE_REPO}"
echo -e "  Modo             : $( [ "$DRY_RUN" = "true" ] && echo "${YELLOW}SIMULACIÓN (DRY RUN)${NC}" || echo "${GREEN}APLICANDO CAMBIOS${NC}" )"
echo ""

# Verificar autenticación
if ! gh auth status &>/dev/null; then
  echo -e "${RED}❌ No autenticado en gh CLI. Ejecuta: gh auth login${NC}"
  exit 1
fi

# Obtener el ID del repositorio de gobernanza (necesario para required_workflows)
echo "Obteniendo ID del repositorio de gobernanza..."
GOVERNANCE_REPO_ID=$(gh api "repos/${ORG}/${GOVERNANCE_REPO}" --jq '.id' 2>/dev/null || echo "")

if [ -z "$GOVERNANCE_REPO_ID" ]; then
  echo -e "${RED}❌ No se pudo obtener el ID de ${ORG}/${GOVERNANCE_REPO}${NC}"
  echo "   Verifica que el repo existe y tienes acceso."
  exit 1
fi

echo -e "  ID del repo de gobernanza: ${GOVERNANCE_REPO_ID}"
echo ""

# Función para verificar si un ruleset ya existe
ruleset_exists() {
  local name="$1"
  gh api "orgs/${ORG}/rulesets" --jq ".[].name" 2>/dev/null | grep -q "^${name}$"
}

# Función para obtener el ID de un ruleset existente
get_ruleset_id() {
  local name="$1"
  gh api "orgs/${ORG}/rulesets" --jq ".[] | select(.name == \"${name}\") | .id" 2>/dev/null
}

# Función principal para crear o actualizar un ruleset
create_ruleset() {
  local branch="$1"
  local required_reviews="$2"
  local ruleset_name="protect-${branch}"

  echo -e "${CYAN}━━━ Ruleset: ${ruleset_name} ━━━${NC}"

  # Construir payload del ruleset
  local payload
  payload=$(cat <<JSON
{
  "name": "${ruleset_name}",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/${branch}"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${required_reviews},
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "validate-branch-flow"
          },
          {
            "context": "validate-commits"
          }
        ]
      }
    },
    {
      "type": "required_workflows",
      "parameters": {
        "required_workflows": [
          {
            "path": ".github/workflows/validate-branch-flow.yml",
            "repository_id": ${GOVERNANCE_REPO_ID},
            "ref": "refs/heads/main"
          },
          {
            "path": ".github/workflows/validate-commits.yml",
            "repository_id": ${GOVERNANCE_REPO_ID},
            "ref": "refs/heads/main"
          }
        ]
      }
    }
  ]
}
JSON
)

  if [ "$DRY_RUN" = "true" ]; then
    echo -e "  ${YELLOW}[DRY RUN] Crearía/actualizaría ruleset '${ruleset_name}' para rama '${branch}'${NC}"
    echo -e "  ${YELLOW}          Reviews requeridos: ${required_reviews}${NC}"
    echo ""
    return 0
  fi

  # Verificar si ya existe el ruleset
  if ruleset_exists "$ruleset_name"; then
    EXISTING_ID=$(get_ruleset_id "$ruleset_name")
    echo "  Ruleset ya existe (ID: ${EXISTING_ID}) — actualizando..."

    if gh api "orgs/${ORG}/rulesets/${EXISTING_ID}" \
      -X PUT \
      --input - <<< "$payload" > /dev/null 2>&1; then
      echo -e "  ${GREEN}✓ Ruleset actualizado${NC}"
    else
      echo -e "  ${RED}✗ Error actualizando ruleset — verificar permisos de admin:org${NC}"
      return 1
    fi
  else
    echo "  Creando nuevo ruleset..."

    if gh api "orgs/${ORG}/rulesets" \
      -X POST \
      --input - <<< "$payload" > /dev/null 2>&1; then
      echo -e "  ${GREEN}✓ Ruleset creado${NC}"
    else
      echo -e "  ${RED}✗ Error creando ruleset — verificar permisos de admin:org${NC}"
      return 1
    fi
  fi

  echo ""
}

# ────────────────────────────────────────────────────────────────
#   Crear rulesets para las 3 ramas protegidas
# ────────────────────────────────────────────────────────────────

TOTAL_OK=0
TOTAL_FAIL=0

create_ruleset "main"    2 && TOTAL_OK=$((TOTAL_OK + 1)) || TOTAL_FAIL=$((TOTAL_FAIL + 1))
create_ruleset "qa"      1 && TOTAL_OK=$((TOTAL_OK + 1)) || TOTAL_FAIL=$((TOTAL_FAIL + 1))
create_ruleset "develop" 1 && TOTAL_OK=$((TOTAL_OK + 1)) || TOTAL_FAIL=$((TOTAL_FAIL + 1))

# ────────────────────────────────────────────────────────────────
#   Resumen
# ────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   Resumen                                                ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Rulesets exitosos : ${GREEN}${TOTAL_OK}${NC}"
echo -e "  Rulesets fallidos : $( [ "$TOTAL_FAIL" -gt 0 ] && echo "${RED}${TOTAL_FAIL}${NC}" || echo "${GREEN}0${NC}" )"
echo ""

if [ "$DRY_RUN" != "true" ] && [ "$TOTAL_OK" -gt 0 ]; then
  echo -e "${GREEN}✅ Org-level Rulesets configurados.${NC}"
  echo ""
  echo -e "  ${YELLOW}Verificar en GitHub:${NC}"
  echo -e "  https://github.com/organizations/${ORG}/settings/rules"
  echo ""
  echo -e "  ${YELLOW}Nota importante:${NC}"
  echo -e "  Los Rulesets de organización se aplican a TODOS los repos actuales"
  echo -e "  y futuros. No requieren configuración por repositorio."
  echo ""
  echo -e "  ${YELLOW}Siguiente paso:${NC}"
  echo -e "  Verifica que Branch Protection Rules también están activas (defense-in-depth):"
  echo -e "  ORG=${ORG} ./setup-branch-protection.sh"
fi

if [ "$TOTAL_FAIL" -gt 0 ]; then
  echo -e "${RED}❌ Algunos rulesets fallaron. Verifica que tu token tiene scope admin:org.${NC}"
  exit 1
fi
