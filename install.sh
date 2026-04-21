#!/usr/bin/env bash
# ============================================================
# Superpowers Setup — 통합 설치 스크립트
#
# 사용법:
#   bash install.sh all      <project> [--local] [--force|-f]
#   bash install.sh cline    <project> [--local] [--force|-f]
#   bash install.sh copilot  <project> [--local] [--force|-f]
#   bash install.sh opencode <project> [--local] [--force|-f]
#
# <project>:     설치 대상 프로젝트 경로 (필수)
# --local:       전역($HOME) 설치 없이 프로젝트 내부에만 설치
# --force, -f:   이미 설치되어 있어도 삭제 후 재설치
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
  echo "  bash $(basename "$0") all      /path/to/project [--local] [--force|-f]"
  echo "  bash $(basename "$0") cline    /path/to/project [--local] [--force|-f]"
  echo "  bash $(basename "$0") copilot  /path/to/project [--local] [--force|-f]"
  echo "  bash $(basename "$0") opencode /path/to/project [--local] [--force|-f]"
  echo ""
  echo "옵션:"
  echo "  --local       전역(\$HOME) 설치 없이 <project>/.superpowers/ 하위에만 설치"
  echo "  --force, -f   이미 설치되어 있어도 이전 설치를 삭제 후 재설치"
  echo ""
  exit 1
}

# ── 인자 파싱 ─────────────────────────────────────────────────
LOCAL_MODE=false
FORCE_MODE=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    --force|-f) FORCE_MODE=true ;;
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

# --local 플래그를 하위 스크립트 인자로 전달
LOCAL_ARGS=()
$LOCAL_MODE && LOCAL_ARGS+=(--local)

# --force 플래그도 하위 스크립트로 전달
FORCE_ARGS=()
$FORCE_MODE && FORCE_ARGS+=(--force)

UNINSTALL_SH="$SCRIPT_DIR/uninstall.sh"

# ── 기존 설치 감지 ────────────────────────────────────────────
# 각 함수는 "이미 설치되어 있으면 0", 아니면 1을 반환.
detect_cline_installed() {
  [ -f "$PROJECT/.clinerules" ] && grep -qF "superpowers-installed" "$PROJECT/.clinerules" 2>/dev/null
}

detect_opencode_installed() {
  local cfg
  if $LOCAL_MODE; then
    cfg="$PROJECT/opencode.json"
  else
    cfg="$HOME/.config/opencode/opencode.json"
  fi
  [ -f "$cfg" ] && grep -qE '"superpowers(@|-)' "$cfg" 2>/dev/null
}

detect_copilot_plugin_installed() {
  if $LOCAL_MODE; then
    [ -f "$PROJECT/.superpowers/copilot-instructions.md" ]
  else
    [ -f "$HOME/.copilot/copilot-instructions.md" ] && \
      grep -qF "superpowers-installed" "$HOME/.copilot/copilot-instructions.md" 2>/dev/null
  fi
}

detect_copilot_cli_ext_installed() {
  [ -f "$PROJECT/.github/extensions/superpowers-enforcer/extension.mjs" ]
}

detect_copilot_vscode_hooks_installed() {
  [ -f "$PROJECT/.github/hooks/hooks.json" ]
}

# 컴포넌트명을 받아 감지 결과를 (라벨) 배열로 수집
# 주의: set -e 아래에서 detect_X && ... 복합 명령이 실패(감지 안 됨)를 반환하면
# 함수 전체가 종료될 수 있으므로 || true로 감싼다.
collect_installed_components() {
  local target="$1"
  INSTALLED_LABELS=()
  case "$target" in
    all)
      detect_cline_installed && INSTALLED_LABELS+=("cline (.clinerules)") || true
      detect_copilot_plugin_installed && INSTALLED_LABELS+=("copilot plugin") || true
      detect_copilot_cli_ext_installed && INSTALLED_LABELS+=("copilot cli-extension") || true
      detect_copilot_vscode_hooks_installed && INSTALLED_LABELS+=("copilot vscode-hooks") || true
      detect_opencode_installed && INSTALLED_LABELS+=("opencode") || true
      ;;
    cline)
      detect_cline_installed && INSTALLED_LABELS+=("cline (.clinerules)") || true
      ;;
    copilot)
      detect_copilot_plugin_installed && INSTALLED_LABELS+=("copilot plugin") || true
      detect_copilot_cli_ext_installed && INSTALLED_LABELS+=("copilot cli-extension") || true
      detect_copilot_vscode_hooks_installed && INSTALLED_LABELS+=("copilot vscode-hooks") || true
      ;;
    opencode)
      detect_opencode_installed && INSTALLED_LABELS+=("opencode") || true
      ;;
  esac
}

# 기존 설치가 감지되면 거부(종료)하거나 --force 시 uninstall 수행
handle_existing_installation() {
  collect_installed_components "$COMMAND"
  if [ ${#INSTALLED_LABELS[@]} -eq 0 ]; then
    return 0
  fi

  if ! $FORCE_MODE; then
    echo "" >&2
    echo "❌ 이미 설치 되었습니다. 이전 설치 내용을 삭제후 재설치 하려면 --force|-f 옵션을 사용해주세요" >&2
    echo "" >&2
    echo "   감지된 설치 항목:" >&2
    for label in "${INSTALLED_LABELS[@]}"; do
      echo "   - $label" >&2
    done
    echo "" >&2
    echo "   재설치 예:" >&2
    if $LOCAL_MODE; then
      echo "     bash $(basename "$0") $COMMAND $PROJECT --local --force" >&2
    else
      echo "     bash $(basename "$0") $COMMAND $PROJECT --force" >&2
    fi
    echo "" >&2
    exit 1
  fi

  echo ""
  echo "⚠️  --force 지정됨. 기존 설치를 먼저 제거합니다."
  echo "   감지 항목: ${INSTALLED_LABELS[*]}"
  echo ""
  bash "$UNINSTALL_SH" "$COMMAND" "$PROJECT" "${LOCAL_ARGS[@]}"
  echo ""
  echo "✅ 기존 설치 제거 완료. 재설치를 진행합니다."
}

handle_existing_installation

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
