#!/bin/bash
# install-hooks.sh — configura git hooks del proyecto usando core.hooksPath
#
# Cada repositorio de servicio tiene su propio directorio .githooks/ con los
# hooks versionados. Este script configura git para que los use directamente,
# eliminando la necesidad de copiar archivos a .git/hooks/.
#
# Uso (desde la raíz del repo de servicio donde quieres activar los hooks):
#   bash path/to/accesorios-dm/scripts/install-hooks.sh
#
# Para instalar en todos los repos a la vez (desde el directorio padre):
#   for repo in accesorios-dm-*/; do
#     git -C "$repo" config core.hooksPath .githooks && echo "✅ $repo"
#   done

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [ -z "$REPO_ROOT" ]; then
  echo "❌ No se encontró un repositorio git."
  echo "   Ejecuta este script desde dentro de un repo de servicio."
  exit 1
fi

REPO_NAME="$(basename "$REPO_ROOT")"
HOOKS_DIR="${REPO_ROOT}/.githooks"

echo ""
echo "🔧 Configurando git hooks — ${REPO_NAME}"
echo ""

if [ ! -d "$HOOKS_DIR" ]; then
  echo "  ❌ No se encontró el directorio .githooks/ en: ${REPO_ROOT}"
  echo "     Este repo no tiene hooks versionados."
  exit 1
fi

# Contar hooks disponibles
HOOK_COUNT=$(find "$HOOKS_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')

if [ "$HOOK_COUNT" -eq 0 ]; then
  echo "  ⚠️  El directorio .githooks/ está vacío."
  exit 1
fi

# Configurar core.hooksPath para usar .githooks/ del repo
git -C "$REPO_ROOT" config core.hooksPath .githooks
echo "  ✅ core.hooksPath = .githooks"
echo ""

# Verificar que los hooks tienen permisos de ejecución
for HOOK_FILE in "${HOOKS_DIR}"/*; do
  HOOK_NAME=$(basename "$HOOK_FILE")
  if [ ! -x "$HOOK_FILE" ]; then
    chmod +x "$HOOK_FILE"
    echo "  ✅ Permisos de ejecución aplicados: ${HOOK_NAME}"
  else
    echo "  ✅ ${HOOK_NAME} (ya ejecutable)"
  fi
done

echo ""
echo "Hooks activos en ${REPO_NAME}:"
find "$HOOKS_DIR" -maxdepth 1 -type f -exec basename {} \; | sed 's/^/  - /'
echo ""
echo "Los hooks se ejecutarán automáticamente en las operaciones git."
echo ""
echo "Para verificar la configuración:"
echo "  git config core.hooksPath"
echo ""
echo "Para desactivar (sin eliminar los archivos):"
echo "  git config --unset core.hooksPath"
