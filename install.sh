#!/usr/bin/env bash
# ============================================================
# Superpowers Setup — 통합 설치 스크립트
#
# 사용법:
#   bash install.sh all     <project>   # Cline + Copilot 모두 설치
#   bash install.sh cline   <project>   # Cline만 설치
#   bash install.sh copilot <project>   # Copilot (plugin + CLI hook + VS Code hook) 설치
#
# <project>: 설치 대상 프로젝트 경로 (필수)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLINE_INSTALL="$SCRIPT_DIR/superpowers-cline/install-superpowers-cline.sh"
COPILOT_PLUGIN="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-plugin.sh"
COPILOT_CLI_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-cli-hooks.sh"
COPILOT_VSCODE_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-vscode-hooks.sh"

# ── 사용법 출력 ───────────────────────────────────────────────
usage() {
  echo ""
  echo "사용법:"
  echo "  bash $(basename "$0") all     /path/to/project   # Cline + Copilot 모두 설치"
  echo "  bash $(basename "$0") cline   /path/to/project   # Cline만 설치"
  echo "  bash $(basename "$0") copilot /path/to/project   # Copilot 설치"
  echo ""
  exit 1
}

# ── 인자 검증 ─────────────────────────────────────────────────
COMMAND="${1:-}"
PROJECT="${2:-}"

if [ -z "$COMMAND" ]; then
  echo "❌ 설치 대상을 지정해야 합니다. (all | cline | copilot)"
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

# ── 설치 함수 ─────────────────────────────────────────────────
install_cline() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for Cline"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$CLINE_INSTALL" "$PROJECT"
}

install_copilot() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/3] Superpowers Copilot Plugin (전역)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_PLUGIN"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [2/3] Superpowers Copilot CLI Hooks"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_CLI_HOOKS" "$PROJECT"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [3/3] Superpowers Copilot VS Code Hooks"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_VSCODE_HOOKS" "$PROJECT"
}

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo "🦸 Superpowers Setup — 통합 설치"
echo "================================="
echo "   명령:    $COMMAND"
echo "   프로젝트: $PROJECT"

case "$COMMAND" in
  all)
    install_cline
    install_copilot
    ;;
  cline)
    install_cline
    ;;
  copilot)
    install_copilot
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 설치 완료!"
echo "   프로젝트: $PROJECT"
echo ""

case "$COMMAND" in
  all | cline)
    echo "   [Cline]"
    echo "   - .clinerules, AGENTS.md, docs/superpowers/ 생성됨"
    echo "   - VS Code에서 Cline 세션 시작 후 스킬 동작 확인"
    ;;&
  all | copilot)
    echo "   [Copilot]"
    echo "   - ~/.copilot/skills/superpowers/ (14개 스킬)"
    echo "   - .github/extensions/superpowers-enforcer/ (CLI Hook)"
    echo "   - .github/hooks/ (VS Code Hook)"
    echo "   - .vscode/settings.json (chat.hooks.enabled: true)"
    ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
