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
#
# hooks.json이 .github/hooks/ 에 있으면 VS Code가 자동으로 로드합니다.
# 별도의 settings.json 설정이 필요 없습니다.
#
# 사용법:
#   bash install-superpowers-copilot-vscode-hooks.sh [프로젝트 경로]
# ============================================================

set -euo pipefail

# ── 인자 파싱 (--local 분리) ──────────────────────────────────
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

COMMAND="${1:-}"

if [ "$COMMAND" = "uninstall" ]; then
  if [ -z "${2:-}" ]; then
    echo "❌ 제거할 프로젝트 경로를 지정해야 합니다."
    echo "   사용법: bash $(basename "$0") uninstall /path/to/project [--local]"
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

  if [ -f "$VSCODE_SETTINGS" ] && grep -q "hookFilesLocations" "$VSCODE_SETTINGS" 2>/dev/null; then
    python3 -c "
import json
with open('$VSCODE_SETTINGS') as f:
    d = json.load(f)
d.pop('chat.hookFilesLocations', None)
if d:
    with open('$VSCODE_SETTINGS', 'w') as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write('\n')
else:
    import os; os.remove('$VSCODE_SETTINGS')
"
    echo "✅ .vscode/settings.json 에서 chat.hookFilesLocations 제거"
  fi

  echo ""
  echo "✅ Superpowers VS Code Hook 제거 완료"
  exit 0
fi

if [ -z "$COMMAND" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  echo "   설치: bash $(basename "$0") /path/to/project [--local]"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project [--local]"
  exit 1
fi

PROJECT_DIR="$(cd "$1" && pwd)"
HOOKS_DIR="$PROJECT_DIR/.github/hooks"
SCRIPTS_DIR="$HOOKS_DIR/scripts"

# ── 이미 설치 감지 ───────────────────────────────────────────
if [ -f "$HOOKS_DIR/hooks.json" ]; then
  if ! $FORCE_MODE; then
    echo "" >&2
    echo "❌ 이미 설치 되었습니다. 이전 설치 내용을 삭제후 재설치 하려면 --force|-f 옵션을 사용해주세요" >&2
    echo "   감지: $HOOKS_DIR/hooks.json" >&2
    exit 1
  fi
  echo ""
  echo "⚠️  --force 지정됨. 기존 설치 제거 후 재설치합니다."
  UNINSTALL_ARGS=(uninstall "$PROJECT_DIR")
  $LOCAL_MODE && UNINSTALL_ARGS+=(--local)
  bash "$0" "${UNINSTALL_ARGS[@]}" < /dev/null
  echo ""
fi

if $LOCAL_MODE; then
  SKILLS_DIR="$PROJECT_DIR/.superpowers/skills"
else
  SKILLS_DIR="$HOME/.copilot/skills"
fi

echo ""
echo "🦸 Superpowers Hook — VS Code Copilot Chat 설치"
echo "================================================"
echo "   프로젝트: $PROJECT_DIR"
$LOCAL_MODE && echo "   모드:    --local ($SKILLS_DIR)" || echo "   모드:    전역 ($SKILLS_DIR)"
echo ""

# ── 사전 조건 확인 ──────────────────────────────────────────
if [ ! -d "$SKILLS_DIR" ]; then
  echo "❌ 스킬이 설치되어 있지 않습니다: $SKILLS_DIR"
  if $LOCAL_MODE; then
    echo "   먼저 실행: bash install-superpowers-copilot-plugin.sh $PROJECT_DIR --local"
  else
    echo "   먼저 실행: bash install-superpowers-copilot-plugin.sh"
  fi
  exit 1
fi

mkdir -p "$HOOKS_DIR" "$SCRIPTS_DIR"

# ── 스크립트 1: session-start.sh ─────────────────────────────
cat > "$SCRIPTS_DIR/session-start.sh" << 'EOF'
#!/usr/bin/env bash
# SessionStart / sessionStart: using-superpowers 스킬을 초기 컨텍스트에 주입
# VS Code: stdout JSON (hookSpecificOutput.additionalContext)
# CLI: sessionStart output은 무시됨 (해가 없음)

SKILLS_DIR="${HOME}/.copilot/skills"
SKILL_FILE="${SKILLS_DIR}/using-superpowers/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "WARNING: Superpowers skill not found at $SKILL_FILE" >&2
  exit 0
fi

# VS Code 공식 포맷: hookSpecificOutput.additionalContext
SKILL_CONTENT=$(cat "$SKILL_FILE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"=== SUPERPOWERS FRAMEWORK ACTIVE ===\nSkills path: %s\nRead the relevant SKILL.md before starting any task.\n\n[Language] 모든 응답, 질문, 설명, 설계 제안은 한국어로 작성하세요. 코드 식별자(변수명, 함수명)는 영어를 유지합니다.\n=== END SUPERPOWERS ==="}}' \
  "$SKILLS_DIR"
EOF

# ── 로컬 모드: session-start.sh 의 SKILLS_DIR 절대경로 치환 ──
if $LOCAL_MODE; then
  # SKILLS_DIR="${HOME}/.copilot/skills" → SKILLS_DIR="<project>/.superpowers/skills"
  SKILLS_DIR_ESCAPED=$(printf '%s' "$SKILLS_DIR" | sed -e 's/[\/&]/\\&/g')
  sed -i "s|^SKILLS_DIR=\".*\"|SKILLS_DIR=\"${SKILLS_DIR_ESCAPED}\"|" "$SCRIPTS_DIR/session-start.sh"
  echo "✅ session-start.sh: SKILLS_DIR → $SKILLS_DIR (--local)"
fi

# ── 스크립트 2: pre-tool-use.sh ──────────────────────────────
cat > "$SCRIPTS_DIR/pre-tool-use.sh" << 'SCRIPT_EOF'
#!/usr/bin/env bash
# PreToolUse / preToolUse: HARD-GATE 강제화
#
# VS Code hook input:
#   { "tool_name": "create_file", "tool_input": { "filePath": "..." }, "cwd": "..." }
#   차단: exit 2 + stderr
#
# Copilot CLI hook input:
#   { "toolName": "edit", "toolArgs": "{\"path\":\"...\"}", "cwd": "..." }
#   차단: stdout {"permissionDecision":"deny","permissionDecisionReason":"..."}

INPUT=$(cat)

# ── 환경 감지: VS Code vs CLI ────────────────────
IS_CLI=$(echo "$INPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('true' if 'toolArgs' in d else 'false')
" 2>/dev/null || echo "false")

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name', d.get('toolName','')))" 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

# toolInput 파싱: VS Code은 object, CLI는 JSON string
TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ti = d.get('tool_input', None)
if ti is not None:
    print(json.dumps(ti))
else:
    args = d.get('toolArgs', '{}')
    if isinstance(args, str):
        try:
            print(json.dumps(json.loads(args)))
        except:
            print('{}')
    else:
        print(json.dumps(args))
" 2>/dev/null || echo "{}")

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
CODE_WRITE_TOOLS="create_file replace_string_in_file multi_replace_string_in_file edit_notebook_file create edit str_replace_based_edit_tool"
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
print(d.get('filePath', d.get('path', d.get('file_path', ''))))
" 2>/dev/null || echo "")

# ── 상태 파일 및 단계 확인 ────────────────────────────────
STATE_FILE="/tmp/superpowers-edit-state-$(echo "$CWD" | md5sum | cut -c1-8).json"
BRAINSTORMING_DONE=false
SPEC_WRITTEN=false
PLAN_WRITTEN=false
TDD_STARTED=false

if [ -f "$STATE_FILE" ]; then
  BRAINSTORMING_DONE=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(str(d.get('brainstormingDone', False)).lower())
" 2>/dev/null || echo "false")
  SPEC_WRITTEN=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(str(d.get('specWritten', False)).lower())
" 2>/dev/null || echo "false")
  PLAN_WRITTEN=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(str(d.get('planWritten', False)).lower())
" 2>/dev/null || echo "false")
  TDD_STARTED=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(str(d.get('tddStarted', False)).lower())
" 2>/dev/null || echo "false")
fi

if [ "$SPEC_WRITTEN" = "false" ] && find "$CWD/docs/superpowers/specs" -type f -name '*.md' -print -quit 2>/dev/null | grep -q .; then
  SPEC_WRITTEN=true
  BRAINSTORMING_DONE=true
fi

if [ "$PLAN_WRITTEN" = "false" ] && find "$CWD/docs/superpowers/plans" -type f -name '*.md' -print -quit 2>/dev/null | grep -q .; then
  PLAN_WRITTEN=true
  SPEC_WRITTEN=true
  BRAINSTORMING_DONE=true
fi

if [ "$TDD_STARTED" = "false" ] && find "$CWD" \( -path "$CWD/node_modules" -o -path "$CWD/.git" \) -prune -o -type f -print 2>/dev/null | grep -qE '\.(test|spec)\.[jt]sx?$|/tests?/|/__tests__/'; then
  TDD_STARTED=true
  PLAN_WRITTEN=true
  SPEC_WRITTEN=true
  BRAINSTORMING_DONE=true
fi

IS_SPEC_DOC=false
IS_PLAN_DOC=false
IS_SETUP_FILE=false
if echo "$FILE_PATH" | grep -qE '(^|/)docs/superpowers/specs/.+\.md$'; then
  IS_SPEC_DOC=true
fi
if echo "$FILE_PATH" | grep -qE '(^|/)docs/superpowers/plans/.+\.md$'; then
  IS_PLAN_DOC=true
fi
if echo "$FILE_PATH" | grep -qE '(^|/)(package\.json|package-lock\.json|\.gitignore)$'; then
  IS_SETUP_FILE=true
fi

deny_with_reason() {
  local reason="$1"
  if [ "$IS_CLI" = "true" ]; then
    echo "{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$reason\"}"
    exit 0
  else
    echo "$reason" >&2
    exit 2
  fi
}

# ── HARD-GATE 적용 (spec -> plan -> TDD -> code) ──────────
if [ "$IS_SPEC_DOC" = "true" ]; then
  if [ "$BRAINSTORMING_DONE" = "false" ]; then
    deny_with_reason "HARD-GATE: brainstorming 완료 후 spec 문서를 작성하세요."
  fi
  exit 0
fi

if [ "$IS_PLAN_DOC" = "true" ]; then
  if [ "$BRAINSTORMING_DONE" = "false" ]; then
    deny_with_reason "HARD-GATE: brainstorming 완료 후 plan 문서를 작성하세요."
  fi
  if [ "$SPEC_WRITTEN" = "false" ]; then
    deny_with_reason "HARD-GATE: spec 문서가 없습니다. docs/superpowers/specs/... 를 먼저 작성하세요."
  fi
  exit 0
fi

if echo "$FILE_PATH" | grep -qE '\.(test|spec)\.[jt]sx?$|/tests?/|/__tests__/'; then
  if [ "$BRAINSTORMING_DONE" = "false" ] || [ "$SPEC_WRITTEN" = "false" ] || [ "$PLAN_WRITTEN" = "false" ]; then
    deny_with_reason "HARD-GATE: 테스트 파일은 brainstorming -> spec -> plan 이후에 작성해야 합니다."
  fi
  exit 0
fi

if [ "$IS_SETUP_FILE" = "true" ]; then
  if [ "$BRAINSTORMING_DONE" = "false" ] || [ "$SPEC_WRITTEN" = "false" ] || [ "$PLAN_WRITTEN" = "false" ]; then
    deny_with_reason "HARD-GATE: setup 파일은 spec과 plan 작성 이후에 수정해야 합니다."
  fi
  exit 0
fi

if [ "$BRAINSTORMING_DONE" = "false" ]; then
  deny_with_reason "HARD-GATE: 설계(brainstorming)가 완료되지 않았습니다."
fi

if [ "$SPEC_WRITTEN" = "false" ]; then
  deny_with_reason "HARD-GATE: spec 문서가 없습니다. non-test code 전에 spec을 먼저 작성하세요."
fi

if [ "$PLAN_WRITTEN" = "false" ]; then
  deny_with_reason "HARD-GATE: plan 문서가 없습니다. non-test code 전에 plan을 먼저 작성하세요."
fi

if [ "$TDD_STARTED" = "false" ]; then
  deny_with_reason "HARD-GATE: TDD가 시작되지 않았습니다. non-test code 전에 failing test를 먼저 작성하세요."
fi

exit 0
SCRIPT_EOF

# ── 스크립트 3: post-tool-use.sh ─────────────────────────────
cat > "$SCRIPTS_DIR/post-tool-use.sh" << 'EOF'
#!/usr/bin/env bash
# onPostToolUse: 상태 파일 갱신 + 파일 편집 후 린트 자동 실행 (선택적)

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name', d.get('toolName','')))" 2>/dev/null || echo "")
EDIT_TOOLS="create_file replace_string_in_file multi_replace_string_in_file edit_notebook_file edit str_replace_based_edit_tool create"
IS_EDIT=false
for t in $EDIT_TOOLS; do
  if [ "$TOOL_NAME" = "$t" ]; then
    IS_EDIT=true
    break
  fi
done
if [ "$IS_EDIT" = "false" ]; then
  exit 0
fi

# 파일 경로 추출: VS Code (tool_input object) / CLI (toolArgs JSON string)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys,json
d = json.load(sys.stdin)
ti = d.get('tool_input', None)
if ti is None:
    args = d.get('toolArgs', '{}')
    ti = json.loads(args) if isinstance(args, str) else (args or {})
elif not isinstance(ti, dict):
    ti = {}
print(ti.get('filePath', ti.get('path', ti.get('file_path', ''))))
" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")
STATE_FILE="/tmp/superpowers-edit-state-$(echo "$CWD" | md5sum | cut -c1-8).json"

python3 - <<PY 2>/dev/null || true
import json, os, re

state_file = ${STATE_FILE@Q}
file_path = ${FILE_PATH@Q}.replace('\\\\', '/')
state = {}

if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except Exception:
        state = {}

state.setdefault('brainstormingDone', False)
state.setdefault('specWritten', False)
state.setdefault('planWritten', False)
state.setdefault('tddStarted', False)

if re.search(r'(^|/)docs/superpowers/specs/.+\.md$', file_path):
    state['specWritten'] = True
    state['brainstormingDone'] = True
if re.search(r'(^|/)docs/superpowers/plans/.+\.md$', file_path):
    state['planWritten'] = True
    state['specWritten'] = True
    state['brainstormingDone'] = True
if re.search(r'(\.(test|spec)\.[jt]sx?$)|/tests?/|/__tests__/', file_path):
    state['tddStarted'] = True
    state['planWritten'] = True
    state['specWritten'] = True
    state['brainstormingDone'] = True

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
PY

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
    ],
    "sessionStart": [
      {
        "type": "command",
        "bash": ".github/hooks/scripts/session-start.sh",
        "timeoutSec": 15
      }
    ],
    "preToolUse": [
      {
        "type": "command",
        "bash": ".github/hooks/scripts/pre-tool-use.sh",
        "timeoutSec": 10
      }
    ],
    "postToolUse": [
      {
        "type": "command",
        "bash": ".github/hooks/scripts/post-tool-use.sh",
        "timeoutSec": 30
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

# ── .gitignore 업데이트 ──────────────────────────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
GITIGNORE_ENTRIES=(
  ".github/hooks/hooks.json"
  ".github/hooks/config.json"
  ".github/hooks/scripts/session-start.sh"
  ".github/hooks/scripts/pre-tool-use.sh"
  ".github/hooks/scripts/post-tool-use.sh"
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
echo "   ✅ VS Code 자동 로드:"
echo "   .github/hooks/hooks.json 이 있으면 VS Code가 자동으로 Hook을 로드합니다."
echo "   별도 settings.json 설정 불필요."
echo ""
echo "   ⚡ CLI vs VS Code Hook:"
echo "   CLI:    extension.mjs JS 프로세스 + .github/hooks/hooks.json 공용"
echo "   VS Code: .github/hooks/hooks.json 자동 로드 (v1.109.3+)"
echo "   차단:    exit 2 로 tool 실행 차단"
