#!/usr/bin/env bash
# ============================================================
# Superpowers Hook 강제화 — Copilot CLI Extension 설치
# SDK 공식 방식: .github/extensions/<name>/extension.mjs
#
# 이 스크립트가 하는 일:
#   1. .github/extensions/superpowers-enforcer/extension.mjs 생성
#      - onSessionStart: using-superpowers 스킬을 컨텍스트에 주입
#      - onPreToolUse: 설계 없이 코드 작성 차단 (HARD-GATE)
#      - onPostToolUse: 파일 편집 후 린트 자동 실행 (선택)
#      - onErrorOccurred: 재시도 전략 설정
#   2. .github/extensions/superpowers-enforcer/config.json 생성
#      (프로젝트별 설정 오버라이드)
#
# 사용법:
#   bash install-superpowers-copilot-cli-extensions.sh [프로젝트 경로]
#   bash install-superpowers-copilot-cli-extensions.sh .              # 현재 디렉토리
#   bash install-superpowers-copilot-cli-extensions.sh ~/my-project   # 특정 프로젝트
#
# 참고: Copilot CLI Extension은 .mjs(ES Module)만 지원
#       @github/copilot-sdk는 자동 resolve됨 (npm install 불필요)
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
  EXTENSIONS_DIR="$PROJECT_DIR/.github/extensions/superpowers-enforcer"
  echo ""
  echo "🗑️  Superpowers CLI Hook — 제거"
  echo "================================"
  echo "   프로젝트: $PROJECT_DIR"
  echo ""

  if [ -d "$EXTENSIONS_DIR" ]; then
    rm -rf "$EXTENSIONS_DIR" && echo "✅ 삭제: $EXTENSIONS_DIR"
  else
    echo "ℹ️  $EXTENSIONS_DIR — 없음 (이미 제거됨)"
  fi

  echo ""
  echo "✅ Superpowers CLI Hook 제거 완료"
  exit 0
fi

if [ -z "$COMMAND" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  echo "   설치: bash $(basename "$0") /path/to/project"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project"
  exit 1
fi
PROJECT_DIR="$(cd "$1" && pwd)"
EXTENSIONS_DIR="$PROJECT_DIR/.github/extensions/superpowers-enforcer"
SKILLS_DIR="$HOME/.copilot/skills"

echo ""
echo "🦸 Superpowers Hook 강제화 — Extension 설치"
echo "============================================"
echo "   프로젝트: $PROJECT_DIR"
echo ""

# ── 사전 조건 확인 ──────────────────────────────────────────
if [ ! -d "$SKILLS_DIR" ]; then
  echo "❌ 스킬이 설치되어 있지 않습니다."
  echo "   먼저 실행: bash install-superpowers-copilot-plugin.sh"
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ 프로젝트 디렉토리가 존재하지 않습니다: $PROJECT_DIR"
  exit 1
fi

mkdir -p "$EXTENSIONS_DIR"

# ── extension.mjs 생성 ───────────────────────────────────────
echo "📝 extension.mjs 생성 중..."

cat > "$EXTENSIONS_DIR/extension.mjs" << 'EXTENSION_EOF'
/**
 * Superpowers Enforcer — Copilot CLI Extension
 *
 * 공식 SDK: @github/copilot-sdk/extension
 * 파일 위치: .github/extensions/superpowers-enforcer/extension.mjs
 *
 * Hook 동작:
 *   onSessionStart    → using-superpowers 스킬 컨텍스트 주입
 *   onUserPromptSubmitted → 스킬 트리거 감지 + 추가 컨텍스트 주입
 *   onPreToolUse      → HARD-GATE: 설계 없는 코드 작성 차단
 *   onPostToolUse     → 파일 편집 후 린트 자동 실행
 *   onErrorOccurred   → 에러 재시도 전략
 */

import { joinSession } from "@github/copilot-sdk/extension";
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

// ── 설정 ────────────────────────────────────────────────────
const SKILLS_BASE = join(process.env.HOME ?? "/root", ".copilot/skills");
const CONFIG_PATH = join(import.meta.dirname ?? ".", "config.json");

function loadConfig() {
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf-8"));
  } catch {
    return {};
  }
}

const config = loadConfig();
const ENABLE_LINT_HOOK    = config.enableLintAfterEdit ?? false;
const LINT_COMMAND        = config.lintCommand ?? "npx eslint --fix";
const LINT_EXTENSIONS     = config.lintExtensions ?? [".ts", ".tsx", ".js", ".jsx"];
const ENFORCE_HARD_GATES  = config.enforceHardGates ?? true;
const LOG_SKILL_INVOCATIONS = config.logSkillInvocations ?? true;

// ── 유틸: 스킬 파일 읽기 ─────────────────────────────────────
function readSkill(skillName) {
  const skillPath = join(SKILLS_BASE, skillName, "SKILL.md");
  if (!existsSync(skillPath)) return null;
  return readFileSync(skillPath, "utf-8");
}

// ── 세션 상태 (메모리, /clear 시 초기화됨) ──────────────────
const state = {
  brainstormingDone: false,      // brainstorming 스킬 완료 여부
  planWritten: false,            // writing-plans 완료 여부
  currentTask: null,             // 현재 작업 유형
  gateViolations: 0,             // HARD-GATE 위반 횟수
};

// ── HARD-GATE 감지: 설계 없이 코드 작성 시도 ────────────────
const CODE_WRITE_TOOLS = new Set([
  "create", "edit", "str_replace_based_edit_tool",
  "create_file", "replace_string_in_file", "multi_replace_string_in_file", "edit_notebook_file",
]);

const BUILD_TRIGGER_PATTERNS = [
  /let['"]s\s+build/i,
  /add\s+feature/i,
  /create\s+(a\s+)?(new\s+)?/i,
  /implement/i,
  /새\s*기능/,
  /만들어/,
  /추가해/,
  /구현해/,
];

const DEBUG_TRIGGER_PATTERNS = [
  /fix\s+(?:this\s+)?bug/i,
  /debug/i,
  /왜\s+실패/,
  /버그\s*수정/,
  /에러\s*고쳐/,
];

function detectTrigger(prompt) {
  if (BUILD_TRIGGER_PATTERNS.some((p) => p.test(prompt))) return "build";
  if (DEBUG_TRIGGER_PATTERNS.some((p) => p.test(prompt)))  return "debug";
  return null;
}

// ── 메인 ─────────────────────────────────────────────────────
const session = await joinSession({
  hooks: {

    // ── onSessionStart: 세션 시작 시 스킬 컨텍스트 주입 ─────
    onSessionStart: async (input) => {
      const usingSuperpowers = readSkill("using-superpowers");
      if (!usingSuperpowers) {
        await session.log("⚠️  Superpowers 스킬을 찾을 수 없습니다: " + SKILLS_BASE, { level: "warning" });
        return {};
      }

      await session.log(`🦸 [EXTENSION] Superpowers Extension 활성화 | 스킬: ${SKILLS_BASE} | HARD-GATE: ${ENFORCE_HARD_GATES ? "ON" : "OFF"}`);

      // using-superpowers 스킬 전체를 초기 컨텍스트로 주입
      return {
        additionalContext: [
          "=== SUPERPOWERS FRAMEWORK ACTIVE ===",
          "",
          usingSuperpowers,
          "",
          "=== SKILL PATHS ===",
          `Skills are located at: ${SKILLS_BASE}`,
          "Read the relevant SKILL.md file before starting any task.",
          "",
          "[Language] 모든 응답, 질문, 설명, 설계 제안은 한국어로 작성하세요. 코드 식별자(변수명, 함수명)는 영어를 유지합니다.",
          "=== END SUPERPOWERS ===",
        ].join("\n"),
      };
    },

    // ── onUserPromptSubmitted: 프롬프트 분석 + 스킬 트리거 ──
    onUserPromptSubmitted: async (input) => {
      const trigger = detectTrigger(input.prompt);
      state.currentTask = trigger;

      const contextParts = [];

      if (trigger === "build" && !state.brainstormingDone) {
        const skill = readSkill("brainstorming");
        if (skill && LOG_SKILL_INVOCATIONS) {
          await session.log("🎨 brainstorming 스킬 활성화", { ephemeral: true });
        }
        contextParts.push(
          "SKILL TRIGGERED: brainstorming",
          "You MUST invoke the brainstorming skill before any implementation.",
          "Read: " + SKILLS_BASE + "/brainstorming/SKILL.md",
          skill ? "\n---\n" + skill.slice(0, 2000) + "\n---" : "",
        );
      }

      if (trigger === "debug") {
        const skill = readSkill("systematic-debugging");
        if (skill && LOG_SKILL_INVOCATIONS) {
          await session.log("🔍 systematic-debugging 스킬 활성화", { ephemeral: true });
        }
        contextParts.push(
          "SKILL TRIGGERED: systematic-debugging",
          "You MUST follow the systematic-debugging process. NO fixes without root cause first.",
          "Read: " + SKILLS_BASE + "/systematic-debugging/SKILL.md",
          skill ? "\n---\n" + skill.slice(0, 2000) + "\n---" : "",
        );
      }

      if (contextParts.length === 0) return {};

      return {
        additionalContext: contextParts.join("\n"),
      };
    },

    // ── onPreToolUse: HARD-GATE 강제화 ───────────────────────
    onPreToolUse: async (input) => {
      if (!ENFORCE_HARD_GATES) return { permissionDecision: "allow" };

      const isCodeWrite = CODE_WRITE_TOOLS.has(input.toolName);
      if (!isCodeWrite) return { permissionDecision: "allow" };

      // 테스트 파일 작성은 허용 (TDD의 RED 단계)
      const filePath = String(
        input.toolArgs?.path ?? input.toolArgs?.file_path ?? ""
      );
      const isTestFile =
        /\.(test|spec)\.[jt]sx?$/.test(filePath) ||
        /\/test[s]?\//.test(filePath) ||
        /\/__tests__\//.test(filePath);

      if (isTestFile) {
        await session.log("✅ 테스트 파일 작성 허용 (TDD)", { ephemeral: true });
        return { permissionDecision: "allow" };
      }

      // brainstorming이 완료되지 않은 경우 코드 작성 차단
      if (!state.brainstormingDone) {
        state.gateViolations++;
        await session.log(
          `🚫 HARD-GATE 위반 #${state.gateViolations}: 설계 없이 코드 작성 시도`,
          { level: "warning" }
        );
        return {
          permissionDecision: "deny",
          permissionDecisionReason: [
            "HARD-GATE: 설계(brainstorming)가 완료되지 않았습니다.",
            "",
            "코드를 작성하기 전에 반드시:",
            "1. 'Use the brainstorming skill' 을 실행하세요",
            "2. 설계가 승인되면 'brainstorming complete' 라고 알려주세요",
            "",
            `위반 횟수: ${state.gateViolations}회`,
          ].join("\n"),
        };
      }

      return { permissionDecision: "allow" };
    },

    // ── onPostToolUse: 파일 편집 후 린트 자동 실행 ──────────
    onPostToolUse: async (input) => {
      if (!ENABLE_LINT_HOOK) return {};

      const isEdit =
        input.toolName === "edit" ||
        input.toolName === "str_replace_based_edit_tool";
      if (!isEdit) return {};

      const filePath = String(input.toolArgs?.path ?? "");
      if (!filePath) return {};

      const shouldLint = LINT_EXTENSIONS.some((ext) => filePath.endsWith(ext));
      if (!shouldLint) return {};

      try {
        await session.log(`🔧 린트 실행: ${filePath}`, { ephemeral: true });
        const { stdout, stderr } = await execAsync(
          `${LINT_COMMAND} "${filePath}"`,
          { cwd: process.cwd(), timeout: 30_000 }
        );
        const output = (stdout + stderr).trim();
        if (output) {
          return {
            additionalContext: `Lint result for ${filePath}:\n${output}`,
          };
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          additionalContext: `Lint error for ${filePath}:\n${msg}`,
        };
      }

      return {};
    },

    // ── onErrorOccurred: 에러 재시도 전략 ───────────────────
    onErrorOccurred: async (input) => {
      if (input.recoverable && input.errorContext === "model_call") {
        return { errorHandling: "retry", retryCount: 2 };
      }
      return {
        errorHandling: "abort",
        userNotification: `에러 발생: ${input.error}`,
      };
    },
  },

  tools: [
    // ── 커스텀 도구: brainstorming 완료 신호 ─────────────────
    {
      name: "superpowers_brainstorming_complete",
      description:
        "Call this tool when the brainstorming skill has been completed and the user has approved the design. This unlocks code writing.",
      parameters: {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "One-sentence summary of the approved design",
          },
        },
        required: ["summary"],
      },
      handler: async (args) => {
        state.brainstormingDone = true;
        await session.log(`✅ Brainstorming 완료: ${args.summary}`);
        return `Brainstorming complete. Code writing is now unlocked. Design: ${args.summary}`;
      },
    },

    // ── 커스텀 도구: 스킬 읽기 ──────────────────────────────
    {
      name: "superpowers_read_skill",
      description:
        "Read a Superpowers skill file. Use this to load the full skill content before executing a workflow.",
      parameters: {
        type: "object",
        properties: {
          skill_name: {
            type: "string",
            description:
              "Name of the skill to read (e.g. brainstorming, test-driven-development, systematic-debugging, writing-plans)",
          },
        },
        required: ["skill_name"],
      },
      handler: async (args) => {
        const content = readSkill(args.skill_name);
        if (!content) {
          return `Skill not found: ${args.skill_name}\nAvailable skills: ${
            ["brainstorming","test-driven-development","systematic-debugging",
             "writing-plans","executing-plans","subagent-driven-development",
             "dispatching-parallel-agents","requesting-code-review",
             "receiving-code-review","verification-before-completion",
             "using-git-worktrees","finishing-a-development-branch",
             "writing-skills","using-superpowers"].join(", ")
          }`;
        }
        await session.log(`📖 스킬 로드: ${args.skill_name}`, { ephemeral: true });
        return content;
      },
    },

    // ── 커스텀 도구: 세션 상태 확인 ─────────────────────────
    {
      name: "superpowers_status",
      description: "Check the current Superpowers session state (gates, violations, etc.)",
      parameters: { type: "object", properties: {} },
      handler: async () => {
        return JSON.stringify({
          brainstormingDone: state.brainstormingDone,
          planWritten: state.planWritten,
          currentTask: state.currentTask,
          gateViolations: state.gateViolations,
          enforceHardGates: ENFORCE_HARD_GATES,
          skillsPath: SKILLS_BASE,
          skillsExist: existsSync(SKILLS_BASE),
        }, null, 2);
      },
    },
  ],
});

await session.log("🦸 [EXTENSION] Superpowers Enforcer 준비 완료 | 커스텀 도구 3종 등록됨");
EXTENSION_EOF

echo "✅ extension.mjs 생성: $EXTENSIONS_DIR/extension.mjs"

# ── config.json 생성 ─────────────────────────────────────────
echo ""
echo "⚙️  config.json 생성 중..."

cat > "$EXTENSIONS_DIR/config.json" << 'CONFIG_EOF'
{
  "_comment": "Superpowers Enforcer 설정 — 프로젝트별 오버라이드",

  "enforceHardGates": true,
  "_enforceHardGates": "true: 설계 없이 코드 작성 시 실제 차단 / false: 경고만",

  "logSkillInvocations": true,
  "_logSkillInvocations": "스킬 활성화 시 타임라인에 표시",

  "enableLintAfterEdit": false,
  "_enableLintAfterEdit": "true: 파일 편집 후 자동 린트 실행",

  "lintCommand": "npx eslint --fix",
  "_lintCommand": "프로젝트에 맞게 수정 (예: npx prettier --write, ruff check --fix)",

  "lintExtensions": [".ts", ".tsx", ".js", ".jsx"],
  "_lintExtensions": "린트 적용할 파일 확장자"
}
CONFIG_EOF

echo "✅ config.json 생성: $EXTENSIONS_DIR/config.json"

# ── .gitignore 업데이트 ──────────────────────────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
GITIGNORE_ENTRIES=(
  ".github/extensions/superpowers-enforcer/extension.mjs"
  ".github/extensions/superpowers-enforcer/config.json"
)

echo ""
echo "🔒 Updating .gitignore..."

# 섹션이 아직 없을 때만 헤더+항목+푸터를 한 번에 추가
if ! grep -qF "# BEGIN superpowers-copilot-cli-hooks" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "# BEGIN superpowers-copilot-cli-hooks"
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      echo "$entry"
    done
    echo "# END superpowers-copilot-cli-hooks"
  } >> "$GITIGNORE"
  echo "✅ Added superpowers-copilot-cli-hooks section to .gitignore"
else
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
      echo "✅ Already in .gitignore: $entry"
    else
      sed -i "/# END superpowers-copilot-cli-hooks/i $entry" "$GITIGNORE"
      echo "✅ Added to .gitignore: $entry"
    fi
  done
fi

# ── 완료 ─────────────────────────────────────────────────────
echo ""
echo "🎉 Superpowers Hook 강제화 설치 완료!"
echo ""
echo "   Extension 위치:"
echo "   $EXTENSIONS_DIR/"
echo "   ├── extension.mjs   ← Hook 로직 (SDK 공식 방식)"
echo "   └── config.json     ← 프로젝트별 설정"
echo ""
echo "   제공되는 Hook:"
echo "   • onSessionStart      → using-superpowers 스킬 자동 주입"
echo "   • onUserPromptSubmitted → 빌드/디버그 요청 시 스킬 트리거"
echo "   • onPreToolUse        → 설계 없는 코드 작성 차단 (HARD-GATE)"
echo "   • onPostToolUse       → 린트 자동 실행 (config에서 활성화)"
echo "   • onErrorOccurred     → 재시도 전략"
echo ""
echo "   제공되는 커스텀 도구:"
echo "   • superpowers_brainstorming_complete → 설계 완료 신호 (코드 작성 잠금 해제)"
echo "   • superpowers_read_skill             → 스킬 파일 로드"
echo "   • superpowers_status                 → 세션 상태 확인"
echo ""
echo "   다음 단계:"
echo "   1. Copilot CLI 세션 시작: copilot"
echo "   2. Extension 로드 확인: /extensions list"
echo "   3. 상태 확인: 'call superpowers_status'"
echo ""
echo "   HARD-GATE 비활성화 (소규모 작업용):"
echo "   config.json에서 enforceHardGates: false 로 변경"
echo ""
echo "   ⚡ Cline 대비 차이:"
echo "   ✅ OS 레벨 강제 (AI가 무시 불가)"
echo "   ✅ 실행 차단 (deny 반환)"
echo "   ✅ 커스텀 도구 등록"
echo "   ✅ 세션 상태 추적"
