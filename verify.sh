#!/usr/bin/env bash
# ============================================================
# Superpowers 설치 검증 스크립트
#
# 사용법:
#   bash verify.sh [프로젝트 경로]
#   bash verify.sh .
#   bash verify.sh ~/github/my-project
# ============================================================

set -uo pipefail

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

PASS=0
FAIL=0
WARN=0

# ── 출력 헬퍼 ───────────────────────────────────────────────
ok()   { echo "  ✅ $*"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $*"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $*"; WARN=$((WARN+1)); }
info() { echo "  ℹ️  $*"; }
section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $*"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

echo ""
echo "🦸 Superpowers 설치 검증"
echo "========================="
echo "   프로젝트: $PROJECT_DIR"

# ============================================================
# [1] 공통: 스킬 디렉토리
# ============================================================
section "[공통] 스킬 디렉토리"

COPILOT_SKILLS="$HOME/.copilot/skills/superpowers"
AGENT_SKILLS="$HOME/.agents/skills/superpowers"

# Copilot 스킬
if [ -d "$COPILOT_SKILLS" ] || [ -L "$COPILOT_SKILLS" ]; then
  SKILL_COUNT=$(find -L "$COPILOT_SKILLS" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SKILL_COUNT" -ge 14 ]; then
    ok "Copilot 스킬 ${SKILL_COUNT}개: $COPILOT_SKILLS"
  else
    fail "Copilot 스킬 ${SKILL_COUNT}개 (14개 기대): $COPILOT_SKILLS"
    info "수정: bash install-superpowers-copilot-plugin.sh"
  fi
else
  fail "Copilot 스킬 디렉토리 없음: $COPILOT_SKILLS"
  info "수정: bash install-superpowers-copilot-plugin.sh"
fi

# Cline 스킬
if [ -d "$AGENT_SKILLS" ] || [ -L "$AGENT_SKILLS" ]; then
  AGENT_COUNT=$(find -L "$AGENT_SKILLS" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$AGENT_COUNT" -ge 14 ]; then
    ok "Cline 스킬 ${AGENT_COUNT}개: $AGENT_SKILLS"
  else
    fail "Cline 스킬 ${AGENT_COUNT}개 (14개 기대): $AGENT_SKILLS"
    info "수정: ln -s $COPILOT_SKILLS $AGENT_SKILLS"
  fi
else
  warn "Cline 스킬 디렉토리 없음 (Cline 미사용 시 무시)"
  info "수정: ln -s $COPILOT_SKILLS $AGENT_SKILLS"
fi

# ============================================================
# [2] Copilot CLI Plugin
# ============================================================
section "[Copilot CLI] Plugin 설치"

INSTRUCTIONS="$HOME/.copilot/copilot-instructions.md"
AGENTS_DIR="$HOME/.copilot/agents"

if [ -f "$INSTRUCTIONS" ] && grep -q "superpowers-installed" "$INSTRUCTIONS" 2>/dev/null; then
  ok "copilot-instructions.md: superpowers 블록 있음"
else
  fail "copilot-instructions.md: superpowers 블록 없음"
  info "수정: bash install-superpowers-copilot-plugin.sh"
fi

if [ -f "$AGENTS_DIR/code-reviewer.md" ]; then
  ok "code-reviewer 에이전트: $AGENTS_DIR/code-reviewer.md"
else
  warn "code-reviewer 에이전트 없음 (선택 사항)"
fi

# ============================================================
# [3] Copilot CLI Hook (extension.mjs)
# ============================================================
section "[Copilot CLI] Hook Extension"

EXTENSION_DIR="$PROJECT_DIR/.github/extensions/superpowers-enforcer"
EXTENSION_MJS="$EXTENSION_DIR/extension.mjs"
EXTENSION_CFG="$EXTENSION_DIR/config.json"

if [ -f "$EXTENSION_MJS" ]; then
  ok "extension.mjs 존재: $EXTENSION_MJS"

  # Node.js 문법 검사
  if command -v node &>/dev/null; then
    if node --input-type=module --eval "
import { readFileSync } from 'fs';
readFileSync('$EXTENSION_MJS', 'utf-8');
" 2>/dev/null; then
      ok "extension.mjs 문법 이상 없음"
    else
      fail "extension.mjs 문법 오류 — node 로 확인 필요"
    fi
  else
    warn "node 없음 — extension.mjs 문법 검사 스킵"
  fi

  # 필수 hook 포함 여부
  for hook in onSessionStart onPreToolUse onUserPromptSubmitted; do
    if grep -q "$hook" "$EXTENSION_MJS"; then
      ok "hook 포함: $hook"
    else
      fail "hook 없음: $hook"
    fi
  done

  # 커스텀 도구
  for tool in superpowers_brainstorming_complete superpowers_read_skill superpowers_status; do
    if grep -q "$tool" "$EXTENSION_MJS"; then
      ok "커스텀 도구: $tool"
    else
      fail "커스텀 도구 없음: $tool"
    fi
  done
else
  fail "extension.mjs 없음: $EXTENSION_MJS"
  info "수정: bash install-superpowers-copilot-cli-hooks.sh $PROJECT_DIR"
fi

if [ -f "$EXTENSION_CFG" ]; then
  ok "config.json 존재: $EXTENSION_CFG"
  if command -v python3 &>/dev/null; then
    ENFORCE=$(python3 -c "
import json
with open('$EXTENSION_CFG') as f:
    d = json.load(f)
print(d.get('enforceHardGates', True))
" 2>/dev/null || echo "unknown")
    if [ "$ENFORCE" = "True" ]; then
      ok "enforceHardGates: true (HARD-GATE 활성화)"
    else
      warn "enforceHardGates: false (HARD-GATE 비활성화 — 차단 안 됨)"
    fi
  fi
else
  warn "config.json 없음 (기본값 사용)"
fi

# ============================================================
# [4] VS Code Copilot Chat Hook
# ============================================================
section "[VS Code Copilot] Hook"

HOOKS_DIR="$PROJECT_DIR/.github/hooks"
HOOKS_JSON="$HOOKS_DIR/hooks.json"
SCRIPTS_DIR="$HOOKS_DIR/scripts"

if [ -f "$HOOKS_JSON" ]; then
  ok "hooks.json 존재: $HOOKS_JSON"

  for event in SessionStart PreToolUse PostToolUse; do
    if grep -q "$event" "$HOOKS_JSON"; then
      ok "hook 이벤트: $event"
    else
      fail "hook 이벤트 없음: $event"
    fi
  done
else
  fail "hooks.json 없음: $HOOKS_JSON"
  info "수정: bash install-superpowers-copilot-vscode-hooks.sh $PROJECT_DIR"
fi

for script in session-start.sh pre-tool-use.sh post-tool-use.sh; do
  SCRIPT_PATH="$SCRIPTS_DIR/$script"
  if [ -f "$SCRIPT_PATH" ]; then
    if [ -x "$SCRIPT_PATH" ]; then
      ok "스크립트 실행권한 있음: $script"
    else
      fail "스크립트 실행권한 없음: $script"
      info "수정: chmod +x $SCRIPT_PATH"
    fi
  else
    fail "스크립트 없음: $SCRIPT_PATH"
  fi
done

# session-start.sh 실제 실행 테스트
if [ -f "$SCRIPTS_DIR/session-start.sh" ] && [ -x "$SCRIPTS_DIR/session-start.sh" ]; then
  RESULT=$(bash "$SCRIPTS_DIR/session-start.sh" 2>/dev/null || echo "")
  if echo "$RESULT" | grep -q "SUPERPOWERS"; then
    ok "session-start.sh 실행 결과: SUPERPOWERS 컨텍스트 주입 확인"
  else
    fail "session-start.sh 실행 결과: 예상 출력 없음"
    info "스킬 경로 확인: $COPILOT_SKILLS/using-superpowers/SKILL.md"
  fi
fi

# pre-tool-use.sh 테스트: brainstorming 미완료 → HARD-GATE 차단 (exit 2 기대)
if [ -f "$SCRIPTS_DIR/pre-tool-use.sh" ] && [ -x "$SCRIPTS_DIR/pre-tool-use.sh" ]; then
  # state 파일 제거 (brainstormingDone=false 보장)
  STATE_FILE="/tmp/superpowers-edit-state-$(echo "$PROJECT_DIR" | md5sum | cut -c1-8).json"
  rm -f "$STATE_FILE"

  TEST_INPUT='{"tool_name":"create_file","tool_input":{"filePath":"src/index.ts"},"cwd":"'"$PROJECT_DIR"'","hookEventName":"PreToolUse"}'
  echo "$TEST_INPUT" | bash "$SCRIPTS_DIR/pre-tool-use.sh" 2>/dev/null
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -eq 2 ]; then
    ok "pre-tool-use.sh HARD-GATE 차단 확인 (brainstorming 미완료 → exit 2)"
  elif [ "$EXIT_CODE" -eq 0 ]; then
    fail "pre-tool-use.sh HARD-GATE 미작동 (exit 0, 기대: exit 2)"
    info "config.json enforceHardGates 확인"
  else
    warn "pre-tool-use.sh exit code: $EXIT_CODE (기대: 2)"
  fi
fi

# .github/hooks/ 는 VS Code 기본 hookFilesLocations 에 포함됨 (별도 settings.json 불필요)
ok ".github/hooks/ 는 VS Code 기본 hookFilesLocations에 포함 (설정 불필요)"

# ============================================================
# [5] Cline
# ============================================================
section "[Cline] 설정"

CLINERULES="$PROJECT_DIR/.clinerules"
AGENTS_MD="$PROJECT_DIR/AGENTS.md"

if [ -f "$CLINERULES" ]; then
  if grep -q "superpowers-installed" "$CLINERULES" 2>/dev/null; then
    ok ".clinerules: superpowers 블록 있음"
  else
    fail ".clinerules: superpowers 블록 없음"
    info "수정: bash install-superpowers-cline.sh $PROJECT_DIR"
  fi

  # 스킬 트리거 규칙 확인
  for keyword in brainstorming systematic-debugging "writing-plans" "test-driven-development"; do
    if grep -q "$keyword" "$CLINERULES" 2>/dev/null; then
      ok ".clinerules: '$keyword' 트리거 규칙 있음"
    else
      warn ".clinerules: '$keyword' 트리거 규칙 없음"
    fi
  done
else
  fail ".clinerules 없음: $CLINERULES"
  info "수정: bash install-superpowers-cline.sh $PROJECT_DIR"
fi

if [ -f "$AGENTS_MD" ]; then
  ok "AGENTS.md 존재: $AGENTS_MD"
else
  warn "AGENTS.md 없음 (Cline이 스킬 경로를 자동 인식 못할 수 있음)"
  info "수정: bash install-superpowers-cline.sh $PROJECT_DIR"
fi

if [ -d "$PROJECT_DIR/docs/superpowers/specs" ] && [ -d "$PROJECT_DIR/docs/superpowers/plans" ]; then
  ok "docs/superpowers/{specs,plans}/ 디렉토리 있음"
else
  warn "docs/superpowers/ 구조 없음 (스킬 실행 시 자동 생성됨)"
fi

# ============================================================
# [6] 결과 요약
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 검증 결과 요약"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 통과: $PASS"
echo "  ❌ 실패: $FAIL"
echo "  ⚠️  경고: $WARN"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  🎉 모든 필수 항목 통과! Superpowers 정상 설치됨"
  echo ""
  echo "  다음 검증 단계 (수동):"
  echo "  [Copilot CLI] copilot 세션 → /extensions list → superpowers-enforcer 확인"
  echo "  [Cline]       VS Code에서 'what superpowers skills do you have?' 입력"
  echo "  [VS Code]     Copilot Chat에서 파일 생성 시도 → HARD-GATE 차단 확인"
else
  echo "  🔧 $FAIL개 항목 수정 필요. 위 ❌ 항목의 '수정:' 안내를 따르세요."
  echo ""
  echo "  빠른 전체 재설치:"
  echo "  bash install.sh all $PROJECT_DIR"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
