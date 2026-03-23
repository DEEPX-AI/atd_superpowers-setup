#!/usr/bin/env bash
# ============================================================
# Superpowers Setup — 통합 제거 스크립트
#
# 사용법:
#   bash uninstall.sh all     <project> [--with-plugin]   # Cline + Copilot 모두 제거
#   bash uninstall.sh cline   <project>                   # Cline만 제거
#   bash uninstall.sh copilot <project> [--with-plugin]   # Copilot 제거
#
# <project>:      제거 대상 프로젝트 경로 (필수)
# --with-plugin:  전역 Copilot 플러그인도 함께 제거 (기본값: 제거 안 함)
#                 다른 프로젝트에 영향을 줄 수 있으므로 명시적으로 지정해야 함
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLINE_INSTALL="$SCRIPT_DIR/superpowers-cline/install-superpowers-cline.sh"
COPILOT_PLUGIN="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-plugin.sh"
COPILOT_CLI_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-cli-extensions.sh"
COPILOT_VSCODE_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-vscode-hooks.sh"

# ── 사용법 출력 ───────────────────────────────────────────────
usage() {
  echo ""
  echo "사용법:"
  echo "  bash $(basename "$0") all     /path/to/project [--with-plugin]   # Cline + Copilot 모두 제거"
  echo "  bash $(basename "$0") cline   /path/to/project                   # Cline만 제거"
  echo "  bash $(basename "$0") copilot /path/to/project [--with-plugin]   # Copilot Hook 제거"
  echo ""
  echo "옵션:"
  echo "  --with-plugin  w 전역 Copilot 플러그인도 함께 제거 (다른 프로젝트에 영향)"
  echo ""
  exit 1
}

# ── 인자 검증 ─────────────────────────────────────────────────
COMMAND="${1:-}"
PROJECT="${2:-}"

if [ -z "$COMMAND" ]; then
  echo "❌ 제거 대상을 지정해야 합니다. (all | cline | copilot)"
  usage
fi

if [[ "$COMMAND" != "all" && "$COMMAND" != "cline" && "$COMMAND" != "copilot" ]]; then
  echo "❌ 알 수 없는 명령: $COMMAND"
  usage
fi

if [ -z "$PROJECT" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  usage
fi

PROJECT="$(cd "$PROJECT" && pwd)"

# ── 옵션 파싱 ─────────────────────────────────────────────────
WITH_PLUGIN=false
for arg in "${@:3}"; do
  if [[ "$arg" == "--with-plugin" ]]; then
    WITH_PLUGIN=true
  fi
done

# ── 제거 함수 ─────────────────────────────────────────────────
uninstall_cline() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for Cline 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$CLINE_INSTALL" uninstall "$PROJECT"
}

uninstall_copilot() {
  local step=0
  local total=2
  $WITH_PLUGIN && total=3

  if $WITH_PLUGIN; then
    step=$((step + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [$step/$total] Superpowers Copilot Plugin 제거 (전역)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$COPILOT_PLUGIN" uninstall
  else
    echo ""
    echo "ℹ️  전역 Copilot 플러그인은 제거하지 않습니다. (다른 프로젝트에 영향 없음)"
    echo "   전역 플러그인도 제거하려면: --with-plugin 옵션 추가"
  fi

  step=$((step + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [$step/$total] Superpowers Copilot CLI Extensions 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_CLI_HOOKS" uninstall "$PROJECT"

  step=$((step + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [$step/$total] Superpowers Copilot VS Code Hooks 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_VSCODE_HOOKS" uninstall "$PROJECT"
}

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo "🗑️  Superpowers Setup — 통합 제거"
echo "=================================="
echo "   명령:    $COMMAND"
echo "   프로젝트: $PROJECT"
$WITH_PLUGIN && echo "   플러그인:  전역 제거 포함 (--with-plugin)" || true

case "$COMMAND" in
  all)
    uninstall_cline
    uninstall_copilot
    ;;
  cline)
    uninstall_cline
    ;;
  copilot)
    uninstall_copilot
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 제거 완료!"
echo "   프로젝트: $PROJECT"
echo ""

case "$COMMAND" in
  all | cline)
    echo "   [Cline]"
    echo "   - .clinerules, AGENTS.md, docs/superpowers/ 제거됨"
    ;;&
  all | copilot)
    echo "   [Copilot]"
    if $WITH_PLUGIN; then
      echo "   - ~/.copilot/skills/ 스킬 symlink 제거됨"
    else
      echo "   - ~/.copilot/skills/ 스킬 symlink 유지됨 (다른 프로젝트에서 사용 중일 수 있음)"
      echo "     삭제하려면: bash $(basename "$0") $COMMAND $PROJECT --with-plugin"
    fi
    echo "   - .github/extensions/superpowers-enforcer/ 제거됨"
    echo "   - .github/hooks/ 제거됨"
    echo "   - .vscode/settings.json의 chat.hooks 설정 제거됨"
    ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
