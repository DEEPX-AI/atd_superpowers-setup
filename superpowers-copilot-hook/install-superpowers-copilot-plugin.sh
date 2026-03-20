#!/usr/bin/env bash
# ============================================================
# Superpowers for GitHub Copilot CLI — Plugin Installer
# obra/superpowers 스킬을 Copilot CLI에 설치합니다
# 
# 작동 방식:
#   1. superpowers 스킬 파일을 ~/.copilot/skills/ 에 개별 symlink로 설치
#   2. ~/.copilot/copilot-instructions.md 에 스킬 로딩 지시 추가
#   3. code-reviewer 에이전트를 ~/.copilot/agents/ 에 설치
#
# 사용법:
#   bash install-superpowers-copilot-plugin.sh
# ============================================================

set -euo pipefail

COPILOT_DIR="$HOME/.copilot"
SKILLS_DIR="$COPILOT_DIR/skills"
AGENTS_DIR="$COPILOT_DIR/agents"
INSTRUCTIONS_FILE="$COPILOT_DIR/copilot-instructions.md"
CACHE_DIR="$COPILOT_DIR/marketplace-cache/dwaintr-superpowers-copilot"
# 실제 레포 구조: marketplace-cache/.../plugins/superpowers/skills/
PLUGIN_DIR="$CACHE_DIR/plugins/superpowers"

# ── uninstall 처리 ───────────────────────────────────────────
if [ "${1:-}" = "uninstall" ]; then
  echo ""
  echo "🗑️  Superpowers for Copilot — 제거"
  echo "===================================="
  echo ""

  removed=0
  for skill_link in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_link")
    if [ -L "${SKILLS_DIR}/${skill_name}" ]; then
      target=$(readlink "${SKILLS_DIR}/${skill_name}")
      if [[ "$target" == *"superpowers"* ]]; then
        rm "${SKILLS_DIR}/${skill_name}"
        removed=$((removed + 1))
      fi
    fi
  done
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
    python3 -c "
import re
with open('$INSTRUCTIONS_FILE', 'r') as f:
    content = f.read()
content = re.sub(r'\n*<!-- superpowers-installed -->.*', '', content, flags=re.DOTALL)
with open('$INSTRUCTIONS_FILE', 'w') as f:
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

echo ""
echo "🦸 Superpowers for GitHub Copilot CLI — Installer"
echo "=================================================="
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
  git clone --quiet --depth=1 \
    https://github.com/DwainTR/superpowers-copilot.git \
    "$CACHE_DIR"
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

# 각 스킬을 개별 symlink로 생성 (CLI가 ~/.copilot/skills/ 바로 아래에서 탐색)
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
echo "   (CLI가 ~/.copilot/skills/ 에서 직접 탐색)"

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
echo "   다음 단계:"
echo "   1. 새 Copilot CLI 세션 시작: copilot"
echo "   2. 확인: '/skills list' 또는 'what superpowers skills do you have?'"
echo "   3. 시도: 'Use the /brainstorming skill to explore an idea'"
echo ""
echo "   ⚠️  참고: copilot-instructions.md는 텍스트 지시 수준입니다."
echo "   강제화(실행 차단)는 별도 hook 설치가 필요합니다:"
echo "   bash install-superpowers-hooks.sh [프로젝트 경로]"
echo ""
echo "   제거 방법:"
echo "   rm -f $SKILLS_DIR $AGENTS_DIR/code-reviewer.md"
echo "   # copilot-instructions.md에서 superpowers 블록 제거"
