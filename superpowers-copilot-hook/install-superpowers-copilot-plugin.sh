#!/usr/bin/env bash
# ============================================================
# Superpowers for GitHub Copilot CLI — Plugin Installer
# obra/superpowers 스킬을 Copilot CLI에 설치합니다
#
# 전역 모드 (기본):
#   1. 스킬을 ~/.copilot/skills/ 에 개별 symlink
#   2. ~/.copilot/copilot-instructions.md 에 스킬 로딩 지시 추가
#   3. code-reviewer 에이전트를 ~/.copilot/agents/ 에 설치
#
# 로컬 모드 (--local, <project> 지정 필수):
#   1. 스킬을 <project>/.superpowers/skills/ 에 symlink
#   2. <project>/.superpowers/copilot-instructions.md 생성 (로컬 지시문)
#   3. <project>/.superpowers/agents/code-reviewer.md 설치
#   4. \$HOME은 전혀 건드리지 않음
#
# 사용법:
#   bash install-superpowers-copilot-plugin.sh                       # 전역 설치
#   bash install-superpowers-copilot-plugin.sh <project> --local     # 로컬 설치
#   bash install-superpowers-copilot-plugin.sh uninstall             # 전역 제거
#   bash install-superpowers-copilot-plugin.sh uninstall <project> --local
# ============================================================

set -euo pipefail

# ── 인자 파싱 ─────────────────────────────────────────────────
LOCAL_MODE=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

PLUGIN_REPO_URL="https://github.com/DwainTR/superpowers-copilot.git"

# ── 경로 결정 ─────────────────────────────────────────────────
resolve_paths() {
  if $LOCAL_MODE; then
    if [ -z "${TARGET_PROJECT:-}" ]; then
      echo "❌ --local 모드에서는 프로젝트 경로가 필요합니다."
      exit 1
    fi
    COPILOT_DIR="$TARGET_PROJECT/.superpowers"
    SKILLS_DIR="$COPILOT_DIR/skills"
    AGENTS_DIR="$COPILOT_DIR/agents"
    INSTRUCTIONS_FILE="$COPILOT_DIR/copilot-instructions.md"
    CACHE_DIR="$COPILOT_DIR/cache/dwaintr-superpowers-copilot"
  else
    COPILOT_DIR="$HOME/.copilot"
    SKILLS_DIR="$COPILOT_DIR/skills"
    AGENTS_DIR="$COPILOT_DIR/agents"
    INSTRUCTIONS_FILE="$COPILOT_DIR/copilot-instructions.md"
    CACHE_DIR="$COPILOT_DIR/marketplace-cache/dwaintr-superpowers-copilot"
  fi
  # 실제 레포 구조: .../plugins/superpowers/skills/
  PLUGIN_DIR="$CACHE_DIR/plugins/superpowers"
}

# ── uninstall 처리 ───────────────────────────────────────────
if [ "${1:-}" = "uninstall" ]; then
  if $LOCAL_MODE; then
    if [ -z "${2:-}" ]; then
      echo "❌ --local 모드 제거에는 프로젝트 경로가 필요합니다."
      echo "   사용법: bash $(basename "$0") uninstall /path/to/project --local"
      exit 1
    fi
    TARGET_PROJECT="$(cd "$2" && pwd)"
  fi
  resolve_paths

  echo ""
  echo "🗑️  Superpowers for Copilot — 제거"
  echo "===================================="
  $LOCAL_MODE && echo "   모드:     --local ($COPILOT_DIR)" || echo "   모드:     전역 ($COPILOT_DIR)"
  echo ""

  if $LOCAL_MODE; then
    # 로컬 모드: .superpowers/ 디렉토리 통째로 정리
    if [ -d "$COPILOT_DIR" ]; then
      rm -rf "$COPILOT_DIR" && echo "✅ 삭제: $COPILOT_DIR"
    else
      echo "ℹ️  $COPILOT_DIR — 없음 (이미 제거됨)"
    fi
    echo ""
    echo "✅ Superpowers for Copilot (local) 제거 완료"
    exit 0
  fi

  # 전역 모드 기존 로직
  removed=0
  if [ -d "$SKILLS_DIR" ]; then
    for skill_link in "$SKILLS_DIR"/*/; do
      [ -e "$skill_link" ] || continue
      skill_name=$(basename "$skill_link")
      if [ -L "${SKILLS_DIR}/${skill_name}" ]; then
        target=$(readlink "${SKILLS_DIR}/${skill_name}")
        if [[ "$target" == *"superpowers"* ]]; then
          rm "${SKILLS_DIR}/${skill_name}"
          removed=$((removed + 1))
        fi
      fi
    done
  fi
  if [ $removed -gt 0 ]; then
    echo "✅ 삭제: ${removed}개 스킬 symlink (from $SKILLS_DIR)"
  else
    echo "ℹ️  Superpowers 스킬 symlink 없음 (이미 제거됨)"
  fi
  # 기존 단일 superpowers symlink도 정리
  if [ -L "$SKILLS_DIR/superpowers" ]; then
    rm "$SKILLS_DIR/superpowers" && echo "✅ 삭제: $SKILLS_DIR/superpowers (legacy symlink)"
  fi

  if [ -f "$AGENTS_DIR/code-reviewer.md" ]; then
    rm -f "$AGENTS_DIR/code-reviewer.md" && echo "✅ 삭제: $AGENTS_DIR/code-reviewer.md"
  fi

  if [ -f "$INSTRUCTIONS_FILE" ] && grep -q "superpowers-installed" "$INSTRUCTIONS_FILE" 2>/dev/null; then
    INSTRUCTIONS_FILE="$INSTRUCTIONS_FILE" python3 -c "
import os, re
p = os.environ['INSTRUCTIONS_FILE']
with open(p, 'r') as f:
    content = f.read()
content = re.sub(r'\n*<!-- superpowers-installed -->.*', '', content, flags=re.DOTALL)
with open(p, 'w') as f:
    f.write(content.rstrip('\n') + '\n')
"
    echo "✅ copilot-instructions.md 에서 Superpowers 블록 제거"
  else
    echo "ℹ️  copilot-instructions.md — Superpowers 블록 없음"
  fi

  echo ""
  echo "✅ Superpowers for Copilot 제거 완료"
  exit 0
fi

# ── 설치 모드 ─────────────────────────────────────────────────
if $LOCAL_MODE; then
  if [ -z "${1:-}" ]; then
    echo "❌ --local 모드에서는 프로젝트 경로가 필요합니다."
    echo "   사용법: bash $(basename "$0") /path/to/project --local"
    exit 1
  fi
  TARGET_PROJECT="$(cd "$1" && pwd)"
fi
resolve_paths

echo ""
echo "🦸 Superpowers for GitHub Copilot CLI — Installer"
echo "=================================================="
$LOCAL_MODE && echo "   모드:    --local ($COPILOT_DIR)" || echo "   모드:    전역 ($COPILOT_DIR)"
echo ""

# ── 사전 조건 확인 ──────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "❌ git이 설치되어 있지 않습니다"
  exit 1
fi

mkdir -p "$COPILOT_DIR" "$AGENTS_DIR"

# ── Step 1: 플러그인 캐시 클론/업데이트 ──────────────────────
echo "📦 Superpowers 플러그인 가져오는 중..."

if [ -d "$CACHE_DIR/.git" ]; then
  echo "   (캐시 존재) 최신 버전으로 업데이트..."
  git -C "$CACHE_DIR" pull --quiet --ff-only 2>/dev/null || \
    echo "   ⚠️  업데이트 실패 (오프라인?). 기존 버전 사용"
else
  mkdir -p "$(dirname "$CACHE_DIR")"
  git clone --quiet --depth=1 "$PLUGIN_REPO_URL" "$CACHE_DIR"
fi
echo "✅ 플러그인 준비 완료"

# ── Step 2: 스킬 디렉토리 symlink ────────────────────────────
echo ""
echo "🔗 스킬 연결 중..."

mkdir -p "$SKILLS_DIR"

# 기존 단일 superpowers symlink가 있으면 제거
if [ -L "$SKILLS_DIR/superpowers" ]; then
  rm "$SKILLS_DIR/superpowers"
  echo "   ℹ️  기존 superpowers symlink 제거"
fi

# 각 스킬을 개별 symlink로 생성
SKILL_COUNT=0
for skill_dir in "$PLUGIN_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  link_path="$SKILLS_DIR/$skill_name"
  if [ -L "$link_path" ]; then
    rm "$link_path"
  fi
  ln -s "$skill_dir" "$link_path"
  SKILL_COUNT=$((SKILL_COUNT + 1))
done
echo "✅ 스킬 연결: ${SKILL_COUNT}개 개별 symlink → $SKILLS_DIR/"

# ── Step 3: 에이전트 설치 ─────────────────────────────────────
echo ""
echo "🤖 에이전트 설치 중..."

AGENT_SRC="$PLUGIN_DIR/agents/code-reviewer.md"
AGENT_DST="$AGENTS_DIR/code-reviewer.md"

if [ -f "$AGENT_SRC" ]; then
  cp "$AGENT_SRC" "$AGENT_DST"
  echo "✅ 에이전트 설치: $AGENT_DST"
else
  echo "   ⚠️  code-reviewer.md 없음 (스킵)"
fi

# ── Step 4: copilot-instructions.md 업데이트 ─────────────────
echo ""
echo "📝 copilot-instructions.md 업데이트 중..."

touch "$INSTRUCTIONS_FILE"

if grep -q "superpowers-installed" "$INSTRUCTIONS_FILE" 2>/dev/null; then
  echo "✅ copilot-instructions.md 이미 설정됨 (스킵)"
else
  cat >> "$INSTRUCTIONS_FILE" << 'INSTRUCTIONS'


<!-- superpowers-installed -->
## Superpowers Skills

You have Superpowers skills installed. Before any task, check if a relevant skill applies.
If there is even a 1% chance a skill might be relevant, invoke it.

Available skills: brainstorming, test-driven-development, systematic-debugging, writing-plans,
executing-plans, subagent-driven-development, dispatching-parallel-agents, requesting-code-review,
receiving-code-review, verification-before-completion, using-git-worktrees,
finishing-a-development-branch, writing-skills, using-superpowers.

Priority order:
1. Process skills first (brainstorming, debugging) — these determine HOW to approach the task
2. Implementation skills second — these guide execution

"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → systematic-debugging first, then domain-specific skills.

## Required Feature Workflow

For any build or feature request, follow this order exactly:

1. `brainstorming`
2. Write a design spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
3. Get user approval on the written spec
4. `writing-plans`
5. Save the implementation plan to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`
6. `test-driven-development`
7. Only then write non-test code
8. `verification-before-completion` before claiming success

Never skip spec writing, plan writing, or test-first development even for small tasks.
If a plan exists, implementation must start with a failing test before editing non-test code.

## Language Preference

Always respond in Korean (한국어). All questions, explanations, design proposals,
and code comments should be in Korean. Code identifiers (variable names, function names)
remain in English.
INSTRUCTIONS
  echo "✅ copilot-instructions.md 업데이트 완료"
fi

# ── 완료 ──────────────────────────────────────────────────────
echo ""
echo "🎉 Superpowers 설치 완료!"
echo ""
echo "   스킬:    $SKILLS_DIR/ (${SKILL_COUNT}개 개별 symlink)"
echo "   에이전트: $AGENTS_DIR/code-reviewer.md"
echo "   지시문:  $INSTRUCTIONS_FILE"
echo ""
if $LOCAL_MODE; then
  echo "   ⚠️  --local 모드: copilot-instructions.md는 \$HOME이 아닌 프로젝트 내부에 생성되었습니다."
  echo "      Copilot CLI/VS Code는 기본적으로 ~/.copilot/copilot-instructions.md만 읽으므로,"
  echo "      로컬 모드의 세션 컨텍스트 주입은 .github/hooks/session-start.sh 에 의존합니다."
  echo "      (install-superpowers-copilot-vscode-hooks.sh --local 을 함께 실행하세요)"
fi
echo ""
echo "   다음 단계:"
echo "   1. 새 Copilot CLI 세션 시작: copilot"
echo "   2. 시도: 'Use the /brainstorming skill to explore an idea'"
echo ""
echo "   제거 방법:"
if $LOCAL_MODE; then
  echo "   bash $(basename "$0") uninstall $TARGET_PROJECT --local"
else
  echo "   bash $(basename "$0") uninstall"
fi
