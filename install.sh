#!/usr/bin/env bash
# ============================================================
# Superpowers Setup — 통합 설치 스크립트
#
# 사용법:
#   bash install.sh all      <project> [--local]   # Cline + Copilot + OpenCode 모두 설치
#   bash install.sh cline    <project> [--local]   # Cline만 설치
#   bash install.sh copilot  <project> [--local]   # Copilot (plugin + CLI hook + VS Code hook)
#   bash install.sh opencode <project> [--local]   # OpenCode만 설치
#
# <project>: 설치 대상 프로젝트 경로 (필수)
# --local:   전역($HOME) 설치 없이 프로젝트 내부에만 설치
#            스킬·플러그인·캐시를 모두 <project>/.superpowers/ 하위에 배치
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
  echo "  bash $(basename "$0") all      /path/to/project [--local]   # Cline + Copilot + OpenCode 모두 설치"
  echo "  bash $(basename "$0") cline    /path/to/project [--local]   # Cline만 설치"
  echo "  bash $(basename "$0") copilot  /path/to/project [--local]   # Copilot 설치"
  echo "  bash $(basename "$0") opencode /path/to/project [--local]   # OpenCode만 설치"
  echo ""
  echo "옵션:"
  echo "  --local  전역(\$HOME) 설치 없이 <project>/.superpowers/ 하위에만 설치"
  echo ""
  exit 1
}

# ── 인자 파싱 (--local 플래그 분리) ───────────────────────────
LOCAL_MODE=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    -h|--help) usage ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

COMMAND="${1:-}"
PROJECT="${2:-}"

if [ -z "$COMMAND" ]; then
  echo "❌ 설치 대상을 지정해야 합니다. (all | cline | copilot | opencode)"
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

# --local 플래그를 하위 스크립트 인자로 전달하기 위한 배열
LOCAL_ARGS=()
$LOCAL_MODE && LOCAL_ARGS+=(--local)

# ── 설치 함수 ─────────────────────────────────────────────────
install_cline() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for Cline"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$CLINE_INSTALL" "$PROJECT" "${LOCAL_ARGS[@]}"
}

install_copilot() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if $LOCAL_MODE; then
    echo "  [1/3] Superpowers Copilot Plugin (프로젝트 로컬)"
  else
    echo "  [1/3] Superpowers Copilot Plugin (전역)"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if $LOCAL_MODE; then
    bash "$COPILOT_PLUGIN" "$PROJECT" --local
  else
    bash "$COPILOT_PLUGIN"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [2/3] Superpowers Copilot CLI Extensions"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_CLI_HOOKS" "$PROJECT" "${LOCAL_ARGS[@]}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [3/3] Superpowers Copilot VS Code Hooks (셸 Hook — VS Code + CLI 공통)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$COPILOT_VSCODE_HOOKS" "$PROJECT" "${LOCAL_ARGS[@]}"
}

install_opencode() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [1/1] Superpowers for OpenCode"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$OPENCODE_INSTALL" "$PROJECT" "${LOCAL_ARGS[@]}"
}

# ── 실행 ─────────────────────────────────────────────────────
echo ""
echo "🦸 Superpowers Setup — 통합 설치"
echo "================================="
echo "   명령:    $COMMAND"
echo "   프로젝트: $PROJECT"
$LOCAL_MODE && echo "   모드:    --local (프로젝트 로컬 전용, \$HOME 변경 없음)" || echo "   모드:    전역 (\$HOME 하위 사용)"

case "$COMMAND" in
  all)
    install_cline
    install_copilot
    install_opencode
    ;;
  cline)
    install_cline
    ;;
  copilot)
    install_copilot
    ;;
  opencode)
    install_opencode
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 설치 완료!"
echo "   프로젝트: $PROJECT"
echo ""

if $LOCAL_MODE; then
  case "$COMMAND" in
    all | cline)
      echo "   [Cline — local]"
      echo "   - $PROJECT/.clinerules, AGENTS.md, docs/superpowers/ 생성"
      echo "   - $PROJECT/.superpowers/skills/ (14개, 로컬)"
      ;;&
    all | copilot)
      echo "   [Copilot — local]"
      echo "   - $PROJECT/.superpowers/skills/ (14개)"
      echo "   - $PROJECT/.superpowers/agents/code-reviewer.md"
      echo "   - $PROJECT/.superpowers/copilot-instructions.md (로컬 지시문)"
      echo "   - $PROJECT/.github/extensions/superpowers-enforcer/ (CLI Extension, 로컬 경로)"
      echo "   - $PROJECT/.github/hooks/ (셸 Hook, 로컬 경로)"
      ;;&
    all | opencode)
      echo "   [OpenCode — local]"
      echo "   - $PROJECT/opencode.json plugin 등록 (프로젝트별 설정)"
      echo "   - AGENTS.md, docs/superpowers/ 생성"
      ;;
  esac
else
  case "$COMMAND" in
    all | cline)
      echo "   [Cline]"
      echo "   - .clinerules, AGENTS.md, docs/superpowers/ 생성됨"
      echo "   - VS Code에서 Cline 세션 시작 후 스킬 동작 확인"
      ;;&
    all | copilot)
      echo "   [Copilot]"
      echo "   - ~/.copilot/skills/ (14개 스킬, 개별 symlink)"
      echo "   - $PROJECT/.github/extensions/superpowers-enforcer/ (CLI Extension)"
      echo "   - $PROJECT/.github/hooks/ (셸 Hook — VS Code + CLI 공통)"
      ;;&
    all | opencode)
      echo "   [OpenCode]"
      echo "   - ~/.config/opencode/opencode.json plugin 추가됨"
      echo "   - AGENTS.md, docs/superpowers/ 생성됨"
      ;;
  esac
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
