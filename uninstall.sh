#!/usr/bin/env bash
# ============================================================
# Superpowers Setup — 통합 제거 스크립트
#
# 사용법:
#   bash uninstall.sh all      <project> [--local] [--with-plugin]
#   bash uninstall.sh cline    <project> [--local]
#   bash uninstall.sh copilot  <project> [--local] [--with-plugin]
#   bash uninstall.sh opencode <project> [--local]
#
# <project>:      제거 대상 프로젝트 경로 (필수)
# --local:        설치 시 --local로 설치한 프로젝트 로컬 산출물을 제거
#                 (설치 모드가 섞여 있으면 해당 경로만 지움)
# --with-plugin:  전역 Copilot 플러그인도 함께 제거 (기본값: 제거 안 함)
#                 --local 모드에서는 의미 없음 (자동 무시 + 경고)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLINE_INSTALL="$SCRIPT_DIR/superpowers-cline/install-superpowers-cline.sh"
COPILOT_PLUGIN="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-plugin.sh"
COPILOT_CLI_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-cli-extensions.sh"
COPILOT_VSCODE_HOOKS="$SCRIPT_DIR/superpowers-copilot-hook/install-superpowers-copilot-vscode-hooks.sh"
OPENCODE_INSTALL="$SCRIPT_DIR/superpowers-opencode/install-superpowers-opencode.sh"

# ── 사용법 출력 ───────────────────────────────────────────────
usage() {
  echo ""
  echo "사용법:"
  echo "  bash $(basename "$0") all      /path/to/project [--local] [--with-plugin]"
  echo "  bash $(basename "$0") cline    /path/to/project [--local]"
  echo "  bash $(basename "$0") copilot  /path/to/project [--local] [--with-plugin]"
  echo "  bash $(basename "$0") opencode /path/to/project [--local]"
  echo ""
  echo "옵션:"
  echo "  --local        프로젝트 로컬 설치 산출물을 제거 (<project>/.superpowers/ 등)"
  echo "  --with-plugin  전역 Copilot 플러그인도 함께 제거 (다른 프로젝트에 영향)"
  echo ""
  exit 1
}

# ── 인자 파싱 ─────────────────────────────────────────────────
LOCAL_MODE=false
WITH_PLUGIN=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    --with-plugin) WITH_PLUGIN=true ;;
    -h|--help) usage ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

COMMAND="${1:-}"
PROJECT="${2:-}"

if [ -z "$COMMAND" ]; then
  echo "❌ 제거 대상을 지정해야 합니다. (all | cline | copilot | opencode)"
  usage
fi

if [[ "$COMMAND" != "all" && "$COMMAND" != "cline" && "$COMMAND" != "copilot" && "$COMMAND" != "opencode" ]]; then
  echo "❌ 알 수 없는 명령: $COMMAND"
  usage
fi

if [ -z "$PROJECT" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  usage
fi

PROJECT="$(cd "$PROJECT" && pwd)"

# --local + --with-plugin 조합은 의미 없음
if $LOCAL_MODE && $WITH_PLUGIN; then
  echo "⚠️  --local 모드에서는 전역 플러그인이 설치되지 않았으므로 --with-plugin은 무시됩니다."
  WITH_PLUGIN=false
fi

LOCAL_ARGS=()
$LOCAL_MODE && LOCAL_ARGS+=(--local)

# ── 제거 함수 ─────────────────────────────────────────────────
uninstall_cline() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for Cline 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$CLINE_INSTALL" uninstall "$PROJECT" "${LOCAL_ARGS[@]}"
}

uninstall_copilot() {
  local step=0
  local total=2
  # 전역 모드에서만 plugin 제거 가능
  if ! $LOCAL_MODE && $WITH_PLUGIN; then
    total=3
  fi

  if $LOCAL_MODE; then
    step=$((step + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [$step/$total] Superpowers Copilot Plugin 제거 (프로젝트 로컬)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$COPILOT_PLUGIN" uninstall "$PROJECT" --local
  elif $WITH_PLUGIN; then
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
  bash "$COPILOT_CLI_HOOKS" uninstall "$PROJECT" "${LOCAL_ARGS[@]}"

  step=$((step + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [$step/$total] Superpowers Copilot VS Code Hooks 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_VSCODE_HOOKS" uninstall "$PROJECT" "${LOCAL_ARGS[@]}"
}

uninstall_opencode() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for OpenCode 제거"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$OPENCODE_INSTALL" uninstall "$PROJECT" "${LOCAL_ARGS[@]}"
}

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo "🗑️  Superpowers Setup — 통합 제거"
echo "=================================="
echo "   명령:    $COMMAND"
echo "   프로젝트: $PROJECT"
$LOCAL_MODE && echo "   모드:    --local (프로젝트 로컬 산출물 제거)" || echo "   모드:    전역"
$WITH_PLUGIN && echo "   플러그인:  전역 제거 포함 (--with-plugin)" || true

case "$COMMAND" in
  all)
    uninstall_cline
    uninstall_copilot
    uninstall_opencode
    ;;
  cline)
    uninstall_cline
    ;;
  copilot)
    uninstall_copilot
    ;;
  opencode)
    uninstall_opencode
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 제거 완료!"
echo "   프로젝트: $PROJECT"
echo ""

if $LOCAL_MODE; then
  case "$COMMAND" in
    all | cline)
      echo "   [Cline — local]"
      echo "   - .clinerules, AGENTS.md, docs/superpowers/ 제거됨"
      echo "   - $PROJECT/.superpowers/ (cline 로컬 스킬) 제거됨"
      ;;&
    all | copilot)
      echo "   [Copilot — local]"
      echo "   - $PROJECT/.superpowers/ (skills/agents/cache/instructions) 제거됨"
      echo "   - $PROJECT/.github/extensions/superpowers-enforcer/ 제거됨"
      echo "   - $PROJECT/.github/hooks/ 제거됨"
      ;;&
    all | opencode)
      echo "   [OpenCode — local]"
      echo "   - $PROJECT/opencode.json에서 plugin 제거됨"
      echo "   - AGENTS.md, docs/superpowers/ 제거됨"
      ;;
  esac
else
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
      ;;&
    all | opencode)
      echo "   [OpenCode]"
      echo "   - ~/.config/opencode/opencode.json에서 plugin 제거됨"
      echo "   - AGENTS.md, docs/superpowers/ 제거됨"
      ;;
  esac
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
