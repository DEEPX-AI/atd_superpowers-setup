#!/usr/bin/env bash
# ============================================================
# Superpowers for OpenCode — Installer
# 공식 plugin 방식으로 obra/superpowers 설치
#
# 사용법:
#   bash install-superpowers-opencode.sh <project>            # 전역 설정 (~/.config/opencode/opencode.json)
#   bash install-superpowers-opencode.sh <project> --local    # 프로젝트 로컬 (<project>/opencode.json)
#   bash install-superpowers-opencode.sh uninstall <project> [--local]
# ============================================================

set -euo pipefail

SUPERPOWERS_PLUGIN="superpowers@git+https://github.com/obra/superpowers.git"

# ── 인자 파싱 ─────────────────────────────────────────────────
LOCAL_MODE=false
FORCE_MODE=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    --force|-f) FORCE_MODE=true ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

# ── 설정 경로 결정 (전역 vs 로컬) ────────────────────────────
# 실제 경로는 TARGET_PROJECT가 확정된 뒤에 설정합니다.
resolve_config_path() {
  if $LOCAL_MODE; then
    OPENCODE_CONFIG="$TARGET_PROJECT/opencode.json"
    OPENCODE_CONFIG_DIR="$TARGET_PROJECT"
  else
    OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
    OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.json"
  fi
}

# ── uninstall 처리 ───────────────────────────────────────────
if [ "${1:-}" = "uninstall" ]; then
  if [ -z "${2:-}" ]; then
    echo "❌ 제거할 프로젝트 경로를 지정해야 합니다."
    echo "   사용법: bash $(basename "$0") uninstall /path/to/project [--local]"
    exit 1
  fi
  TARGET_PROJECT="$(cd "$2" && pwd)"
  resolve_config_path

  echo ""
  echo "🗑️  Superpowers for OpenCode — 제거"
  echo "====================================="
  echo "   프로젝트: $TARGET_PROJECT"
  $LOCAL_MODE && echo "   모드:    --local ($OPENCODE_CONFIG)" || echo "   모드:    전역 ($OPENCODE_CONFIG)"
  echo ""

  if [ -f "$OPENCODE_CONFIG" ]; then
    python3 -c "
import json
with open('$OPENCODE_CONFIG', 'r') as f:
    config = json.load(f)
if 'plugin' in config:
    config['plugin'] = [p for p in config['plugin'] if 'superpowers' not in p]
    if not config['plugin']:
        del config['plugin']
with open('$OPENCODE_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
print('✅ opencode.json에서 superpowers plugin 제거')
"
    # 로컬 모드에서 파일이 사실상 비어있으면 삭제
    if $LOCAL_MODE; then
      if python3 -c "
import json,sys
with open('$OPENCODE_CONFIG') as f:
    d = json.load(f)
# \$schema만 남았거나 완전히 비어있으면 cleanup 대상
keys = [k for k in d.keys() if k != '\$schema']
sys.exit(0 if not keys else 1)
" 2>/dev/null; then
        rm -f "$OPENCODE_CONFIG" && echo "✅ 삭제: $OPENCODE_CONFIG (빈 설정)"
      fi
    fi
  fi

  rm -f  "$TARGET_PROJECT/AGENTS.md" && echo "✅ 삭제: AGENTS.md" || true
  rm -rf "$TARGET_PROJECT/docs/superpowers" && echo "✅ 삭제: docs/superpowers/" || true

  echo ""
  echo "✅ Superpowers for OpenCode 제거 완료"
  exit 0
fi

if [ -z "${1:-}" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  echo "   설치: bash $(basename "$0") /path/to/project [--local]"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project [--local]"
  exit 1
fi
TARGET_PROJECT="$(cd "$1" && pwd)"
resolve_config_path

# ── 이미 설치 감지 ───────────────────────────────────────────
if [ -f "$OPENCODE_CONFIG" ] && grep -qE '"superpowers(@|-)' "$OPENCODE_CONFIG" 2>/dev/null; then
  if ! $FORCE_MODE; then
    echo "" >&2
    echo "❌ 이미 설치 되었습니다. 이전 설치 내용을 삭제후 재설치 하려면 --force|-f 옵션을 사용해주세요" >&2
    echo "   감지: $OPENCODE_CONFIG 에 superpowers plugin 항목 존재" >&2
    exit 1
  fi
  echo ""
  echo "⚠️  --force 지정됨. 기존 설치 제거 후 재설치합니다."
  UNINSTALL_ARGS=(uninstall "$TARGET_PROJECT")
  $LOCAL_MODE && UNINSTALL_ARGS+=(--local)
  bash "$0" "${UNINSTALL_ARGS[@]}"
  echo ""
fi

echo ""
echo "🦸 Superpowers for OpenCode — Installer"
echo "========================================="
echo "   프로젝트: $TARGET_PROJECT"
$LOCAL_MODE && echo "   모드:    --local ($OPENCODE_CONFIG)" || echo "   모드:    전역 ($OPENCODE_CONFIG)"
echo ""

# ── Step 1: opencode.json에 plugin 추가 ──────────────────────
echo "📝 opencode.json 설정 중..."

mkdir -p "$OPENCODE_CONFIG_DIR"

if [ -f "$OPENCODE_CONFIG" ]; then
  cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.bak"
  echo "✅ 백업: ${OPENCODE_CONFIG}.bak"
fi

CONFIG_PATH="$OPENCODE_CONFIG" PLUGIN_ENTRY="$SUPERPOWERS_PLUGIN" python3 << 'PYTHON_SCRIPT'
import json
import os

config_path = os.environ["CONFIG_PATH"]
plugin_entry = os.environ["PLUGIN_ENTRY"]

if os.path.exists(config_path):
    with open(config_path, 'r') as f:
        config = json.load(f)
else:
    config = {"$schema": "https://opencode.ai"}

if "plugin" not in config:
    config["plugin"] = []

if plugin_entry not in config["plugin"]:
    config["plugin"].append(plugin_entry)
    print(f"✅ plugin 추가: {plugin_entry}")
else:
    print("ℹ️  plugin 이미 존재함")

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print(f"✅ 설정 저장: {config_path}")
PYTHON_SCRIPT

# ── Step 2: AGENTS.md 생성 ─────────────────────────────────────
AGENTS_MD="$TARGET_PROJECT/AGENTS.md"
if [ ! -f "$AGENTS_MD" ]; then
  cat > "$AGENTS_MD" << 'EOF'
# Agent Instructions

## Superpowers
This project uses the Superpowers skills framework.
Skills are loaded automatically via OpenCode plugin.

Before any task, check if a relevant skill applies.
Use the skill tool to load: `superpowers/<skill-name>`

## Project-specific overrides
<!-- Add your team's specific instructions below -->
EOF
  echo "✅ AGENTS.md 생성: $AGENTS_MD"
else
  echo "ℹ️  AGENTS.md 이미 존재 (수정 안 함)"
fi

# ── Step 3: docs/superpowers 디렉토리 생성 ────────────────────
mkdir -p "$TARGET_PROJECT/docs/superpowers/specs"
mkdir -p "$TARGET_PROJECT/docs/superpowers/plans"
touch "$TARGET_PROJECT/docs/superpowers/.gitkeep"
echo "✅ docs/superpowers/{specs,plans}/ 생성"

# ── Step 4: .gitignore 업데이트 ───────────────────────────────
GITIGNORE="$TARGET_PROJECT/.gitignore"
GITIGNORE_ENTRIES=(
  "docs/superpowers/plans/"
  "docs/superpowers/specs/"
  "docs/superpowers/.gitkeep"
  "/AGENTS.md"
)
# 로컬 모드에서는 프로젝트 루트 opencode.json도 .gitignore 후보 (팀 공유 여부는 사용자 선택)
if $LOCAL_MODE; then
  GITIGNORE_ENTRIES+=("/opencode.json")
fi

if [ -f "$GITIGNORE" ]; then
  if ! grep -qF "# BEGIN superpowers-opencode" "$GITIGNORE" 2>/dev/null; then
    {
      echo ""
      echo "# BEGIN superpowers-opencode"
      for entry in "${GITIGNORE_ENTRIES[@]}"; do
        echo "$entry"
      done
      echo "# END superpowers-opencode"
    } >> "$GITIGNORE"
    echo "✅ .gitignore 업데이트"
  else
    echo "ℹ️  .gitignore 이미 설정됨"
  fi
fi

# ── 완료 ──────────────────────────────────────────────────────
echo ""
echo "🎉 Superpowers for OpenCode 설치 완료!"
echo ""
echo "   설정:    $OPENCODE_CONFIG"
echo "   프로젝트: $TARGET_PROJECT"
if $LOCAL_MODE; then
  echo "   모드:    프로젝트 로컬 (\$HOME 변경 없음)"
  echo ""
  echo "   ℹ️  OpenCode는 프로젝트 루트의 opencode.json을 자동 인식합니다."
  echo "      팀 공유가 필요하면 opencode.json을 git에 포함시키고,"
  echo "      개인 전용이면 .gitignore의 /opencode.json 항목을 유지하세요."
fi
echo ""
echo "   다음 단계:"
echo "   1. OpenCode 재시작"
echo "   2. 확인: 'Tell me about your superpowers'"
echo ""
echo "   제거 방법:"
if $LOCAL_MODE; then
  echo "   bash $(basename "$0") uninstall $TARGET_PROJECT --local"
else
  echo "   bash $(basename "$0") uninstall $TARGET_PROJECT"
fi
