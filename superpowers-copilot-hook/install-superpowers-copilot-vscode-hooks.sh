#!/usr/bin/env bash
# ============================================================
# Superpowers Hook 강제화 — VS Code Copilot Chat
#
# CLI extension.mjs 방식과 다릅니다:
#   VS Code: .github/hooks/*.json + bash 셸 스크립트
#   CLI:     .github/extensions/*/extension.mjs (JS 프로세스)
#
# VS Code hooks 포맷:
#   { "version": 1, "hooks": { "PreToolUse": [...], ... } }
#   exit code 2     → 실행 차단 (deny)
#   stdout JSON     → { "continue": false } 세션 중단
#   stderr          → 모델에게 컨텍스트로 전달
#
# 활성화 조건 (VS Code settings.json):
#   "chat.hooks.enabled": true
#
# 사용법:
#   bash install-superpowers-copilot-vscode-hooks.sh [프로젝트 경로]
# ============================================================

set -euo pipefail

COMMAND="${1:-}"

if [ "$COMMAND" = "uninstall" ]; then
  if [ -z "${2:-}" ]; then
    echo "❌ 제거할 프로젝트 경로를 지정해야 합니다."
    echo "   사용법: bash $(basename "$0") uninstall /path/to/project"
    exit 1
  fi
  PROJECT_DIR="$(cd "$2" && pwd)"
  HOOKS_DIR="$PROJECT_DIR/.github/hooks"
  VSCODE_SETTINGS="$PROJECT_DIR/.vscode/settings.json"
  echo ""
  echo "🗑️  Superpowers VS Code Hook — 제거"
  echo "====================================="
  echo "   프로젝트: $PROJECT_DIR"
  echo ""

  if [ -d "$HOOKS_DIR" ]; then
    rm -rf "$HOOKS_DIR" && echo "✅ 삭제: $HOOKS_DIR"
  else
    echo "ℹ️  $HOOKS_DIR — 없음 (이미 제거됨)"
  fi

  if [ -f "$VSCODE_SETTINGS" ] && grep -q "chat.hooks.enabled" "$VSCODE_SETTINGS" 2>/dev/null; then
    python3 -c "
import json
with open('$VSCODE_SETTINGS') as f:
    d = json.load(f)
d.pop('chat.hooks.enabled', None)
with open('$VSCODE_SETTINGS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    echo "✅ .vscode/settings.json 에서 chat.hooks.enabled 제거"
  fi

  echo ""
  echo "✅ Superpowers VS Code Hook 제거 완료"
  exit 0
fi

if [ -z "$COMMAND" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  echo "   설치: bash $(basename "$0") /path/to/project"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project"
  exit 1
fi

PROJECT_DIR="$(cd "$1" && pwd)"
HOOKS_DIR="$PROJECT_DIR/.github/hooks"
SCRIPTS_DIR="$HOOKS_DIR/scripts"
SKILLS_DIR="$HOME/.copilot/skills/superpowers"

echo ""
echo "🦸 Superpowers Hook — VS Code Copilot Chat 설치"
echo "================================================"
echo "   프로젝트: $PROJECT_DIR"
echo ""

# ── 사전 조건 확인 ──────────────────────────────────────────
if [ ! -d "$SKILLS_DIR" ]; then
  echo "❌ 스킬이 설치되어 있지 않습니다."
  echo "   먼저 실행: bash install-superpowers-copilot-plugin.sh"
  exit 1
fi

mkdir -p "$HOOKS_DIR" "$SCRIPTS_DIR"

# ── 스크립트 1: session-start.sh ─────────────────────────────
cat > "$SCRIPTS_DIR/session-start.sh" << 'EOF'
#!/usr/bin/env bash
# onSessionStart: using-superpowers 스킬을 초기 컨텍스트에 주입
# stdout → 모델 컨텍스트로 전달됨

SKILLS_DIR="${HOME}/.copilot/skills/superpowers"
SKILL_FILE="${SKILLS_DIR}/using-superpowers/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "WARNING: Superpowers skill not found at $SKILL_FILE" >&2
  exit 0
fi

# JSON으로 additionalContext 반환 (VS Code hook output 포맷)
SKILL_CONTENT=$(cat "$SKILL_FILE")
printf '{"systemMessage": "=== SUPERPOWERS FRAMEWORK ACTIVE ===\n\n%s\n\nSkills path: %s\nRead the relevant SKILL.md before starting any task.\n=== END SUPERPOWERS ==="}' \
  "$SKILL_CONTENT" "$SKILLS_DIR"
EOF

# ── 스크립트 2: pre-tool-use.sh ──────────────────────────────
cat > "$SCRIPTS_DIR/pre-tool-use.sh" << 'SCRIPT_EOF'
#!/usr/bin/env bash
# onPreToolUse: HARD-GATE 강제화
#
# VS Code hook input (stdin으로 들어옴):
# {
#   "timestamp": "...",
#   "cwd": "...",
#   "sessionId": "...",
#   "hookEventName": "PreToolUse",
#   "transcript_path": "...",
#   "toolName": "...",
#   "toolInput": { ... }
# }
#
# 차단하려면: exit 2
# 경고만:    stderr에 출력 후 exit 0

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('toolName',''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('toolInput',{})))" 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")

# ── 설정 파일 로드 ─────────────────────────────────────────
CONFIG_FILE="${CWD}/.github/hooks/config.json"
ENFORCE_GATES="true"
if [ -f "$CONFIG_FILE" ]; then
  ENFORCE_GATES=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    d = json.load(f)
print(str(d.get('enforceHardGates', True)).lower())
" 2>/dev/null || echo "true")
fi

if [ "$ENFORCE_GATES" = "false" ]; then
  exit 0
fi

# ── 코드 파일 작성 도구 확인 ──────────────────────────────
CODE_WRITE_TOOLS="create edit str_replace_based_edit_tool"
IS_CODE_WRITE=false
for t in $CODE_WRITE_TOOLS; do
  if [ "$TOOL_NAME" = "$t" ]; then
    IS_CODE_WRITE=true
    break
  fi
done

if [ "$IS_CODE_WRITE" = "false" ]; then
  exit 0
fi

# ── 파일 경로 추출 ────────────────────────────────────────
FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('path', d.get('file_path', '')))
" 2>/dev/null || echo "")

# ── 테스트 파일은 항상 허용 (TDD RED 단계) ───────────────
if echo "$FILE_PATH" | grep -qE '\.(test|spec)\.[jt]sx?$|/tests?/|/__tests__/'; then
  exit 0
fi

# ── 브레인스토밍 완료 여부 확인 ──────────────────────────
STATE_FILE="/tmp/superpowers-${TOOL_NAME}-state-$(echo "$CWD" | md5sum | cut -c1-8).json"
BRAINSTORMING_DONE=false
if [ -f "$STATE_FILE" ]; then
  BRAINSTORMING_DONE=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(str(d.get('brainstormingDone', False)).lower())
" 2>/dev/null || echo "false")
fi

# ── 트랜스크립트에서 현재 작업 유형 감지 ─────────────────
IS_BUILD_TASK=false
if [ -f "$TRANSCRIPT" ]; then
  RECENT_PROMPTS=$(python3 -c "
import json, sys
with open('$TRANSCRIPT') as f:
    lines = f.readlines()[-20:]  # 최근 20줄
content = ' '.join(lines).lower()
import re
if re.search(r\"let.?s build|add feature|implement|create|만들어|추가|구현\", content):
    print('true')
else:
    print('false')
" 2>/dev/null || echo "false")
  IS_BUILD_TASK="$RECENT_PROMPTS"
fi

# ── HARD-GATE 적용 ────────────────────────────────────────
if [ "$IS_BUILD_TASK" = "true" ] && [ "$BRAINSTORMING_DONE" = "false" ]; then
  # stderr → VS Code가 모델에게 컨텍스트로 전달
  cat >&2 << 'DENY_MSG'
HARD-GATE VIOLATION: 설계(brainstorming)가 완료되지 않았습니다.

코드를 작성하기 전에 반드시:
1. brainstorming 스킬을 실행하세요:
   Read: ~/.copilot/skills/superpowers/brainstorming/SKILL.md
2. 설계가 승인되면 아래 파일을 생성하여 잠금을 해제하세요:
   echo '{"brainstormingDone": true}' > /tmp/superpowers-state.json

또는 config.json에서 enforceHardGates: false 로 설정하면 차단이 비활성화됩니다.
DENY_MSG

  # exit 2 → VS Code가 tool 실행을 차단
  exit 2
fi

exit 0
SCRIPT_EOF

# ── 스크립트 3: post-tool-use.sh ─────────────────────────────
cat > "$SCRIPTS_DIR/post-tool-use.sh" << 'EOF'
#!/usr/bin/env bash
# onPostToolUse: 파일 편집 후 린트 자동 실행 (선택적)

INPUT=$(cat)

# config에서 lint 활성화 여부 확인
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")
CONFIG_FILE="${CWD}/.github/hooks/config.json"

ENABLE_LINT="false"
LINT_CMD="npx eslint --fix"
LINT_EXTS=".ts .tsx .js .jsx"

if [ -f "$CONFIG_FILE" ]; then
  ENABLE_LINT=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    d = json.load(f)
print(str(d.get('enableLintAfterEdit', False)).lower())
" 2>/dev/null || echo "false")
  LINT_CMD=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    d = json.load(f)
print(d.get('lintCommand', 'npx eslint --fix'))
" 2>/dev/null || echo "npx eslint --fix")
fi

if [ "$ENABLE_LINT" = "false" ]; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('toolName',''))" 2>/dev/null || echo "")
if [ "$TOOL_NAME" != "edit" ] && [ "$TOOL_NAME" != "str_replace_based_edit_tool" ]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys,json
d = json.load(sys.stdin)
ti = d.get('toolInput', {})
print(ti.get('path', ti.get('file_path', '')))
" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 확장자 확인
SHOULD_LINT=false
for ext in $LINT_EXTS; do
  if [[ "$FILE_PATH" == *"$ext" ]]; then
    SHOULD_LINT=true
    break
  fi
done

if [ "$SHOULD_LINT" = "true" ] && [ -f "$FILE_PATH" ]; then
  RESULT=$(eval "$LINT_CMD \"$FILE_PATH\"" 2>&1 || true)
  if [ -n "$RESULT" ]; then
    echo "$RESULT" >&2  # stderr → 모델 컨텍스트
  fi
fi

exit 0
EOF

# ── hooks.json 생성 ──────────────────────────────────────────
echo "📝 hooks.json 생성 중..."

cat > "$HOOKS_DIR/hooks.json" << 'HOOKS_EOF'
{
  "version": 1,
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": ".github/hooks/scripts/session-start.sh",
        "timeout": 15
      }
    ],
    "PreToolUse": [
      {
        "type": "command",
        "command": ".github/hooks/scripts/pre-tool-use.sh",
        "timeout": 10
      }
    ],
    "PostToolUse": [
      {
        "type": "command",
        "command": ".github/hooks/scripts/post-tool-use.sh",
        "timeout": 30
      }
    ]
  }
}
HOOKS_EOF

echo "✅ hooks.json 생성: $HOOKS_DIR/hooks.json"

# ── config.json 생성 ─────────────────────────────────────────
cat > "$HOOKS_DIR/config.json" << 'CONFIG_EOF'
{
  "_comment": "Superpowers VS Code Hook 설정",
  "enforceHardGates": true,
  "enableLintAfterEdit": false,
  "lintCommand": "npx eslint --fix",
  "lintExtensions": [".ts", ".tsx", ".js", ".jsx"]
}
CONFIG_EOF

# ── 실행 권한 부여 ───────────────────────────────────────────
chmod +x "$SCRIPTS_DIR/session-start.sh"
chmod +x "$SCRIPTS_DIR/pre-tool-use.sh"
chmod +x "$SCRIPTS_DIR/post-tool-use.sh"

echo "✅ 스크립트 권한 설정 완료"

# ── VS Code settings 안내 ────────────────────────────────────
VSCODE_SETTINGS="$PROJECT_DIR/.vscode/settings.json"
mkdir -p "$(dirname "$VSCODE_SETTINGS")"

if [ -f "$VSCODE_SETTINGS" ]; then
  if ! grep -q "chat.hooks.enabled" "$VSCODE_SETTINGS" 2>/dev/null; then
    echo ""
    echo "⚠️  VS Code settings.json에 아래를 추가해야 Hook이 활성화됩니다:"
    echo '   "chat.hooks.enabled": true'
  fi
else
  cat > "$VSCODE_SETTINGS" << 'SETTINGS_EOF'
{
  "chat.hooks.enabled": true
}
SETTINGS_EOF
  echo "✅ .vscode/settings.json 생성 (chat.hooks.enabled: true)"
fi

# ── .gitignore 업데이트 ──────────────────────────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
GITIGNORE_ENTRIES=(
  ".github/hooks/hooks.json"
  ".github/hooks/config.json"
  ".github/hooks/scripts/session-start.sh"
  ".github/hooks/scripts/pre-tool-use.sh"
  ".github/hooks/scripts/post-tool-use.sh"
  ".vscode/settings.json"
)

echo ""
echo "🔒 Updating .gitignore..."

# 섹션이 아직 없을 때만 헤더+항목+푸터를 한 번에 추가
if ! grep -qF "# BEGIN superpowers-copilot-vscode-hooks" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "# BEGIN superpowers-copilot-vscode-hooks"
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      echo "$entry"
    done
    echo "# END superpowers-copilot-vscode-hooks"
  } >> "$GITIGNORE"
  echo "✅ Added superpowers-copilot-vscode-hooks section to .gitignore"
else
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
      echo "✅ Already in .gitignore: $entry"
    else
      sed -i "/# END superpowers-copilot-vscode-hooks/i $entry" "$GITIGNORE"
      echo "✅ Added to .gitignore: $entry"
    fi
  done
fi
echo ""
echo "🎉 VS Code Copilot Chat Hook 설치 완료!"
echo ""
echo "   생성된 파일:"
echo "   $HOOKS_DIR/"
echo "   ├── hooks.json            ← Hook 이벤트 설정"
echo "   ├── config.json           ← 프로젝트별 설정"
echo "   └── scripts/"
echo "       ├── session-start.sh  ← 스킬 컨텍스트 주입"
echo "       ├── pre-tool-use.sh   ← HARD-GATE 차단 (exit 2)"
echo "       └── post-tool-use.sh  ← 린트 자동 실행"
echo ""
echo "   ✅ VS Code 활성화 확인:"
echo "   .vscode/settings.json → chat.hooks.enabled: true"
echo ""
echo "   ⚡ CLI vs VS Code Hook 차이:"
echo "   CLI:    extension.mjs JS 프로세스 (permissionDecision: 'deny')"
echo "   VS Code: 셸 스크립트 (exit 2 로 차단)"
echo "   포맷:    hooks.json 은 두 환경 모두 호환"
