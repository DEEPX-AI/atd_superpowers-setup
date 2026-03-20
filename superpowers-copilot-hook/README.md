# Superpowers for GitHub Copilot

obra/superpowers 스킬 프레임워크를 GitHub Copilot에 적용하기 위한 설치 스크립트 모음입니다.
VS Code Copilot Chat과 Copilot CLI 모두 지원합니다.

---

## 아키텍처 개요

Copilot에는 두 가지 Hook 메커니즘이 있으며, 이 프로젝트는 **양쪽 모두** 설치합니다.

```
┌─────────────────────────────────────────────────────────────┐
│  VS Code Copilot Chat + Copilot CLI (공통)                  │
│  .github/hooks/hooks.json → 셸 스크립트 (Bash)              │
│  ├── session-start.sh    스킬 컨텍스트 주입                  │
│  ├── pre-tool-use.sh     HARD-GATE 차단                     │
│  └── post-tool-use.sh    린트 자동 실행                      │
│                                                             │
│  hooks.json은 dual-format으로 VS Code(PascalCase)와         │
│  CLI(camelCase) 이벤트를 모두 포함합니다.                     │
│  pre-tool-use.sh는 환경을 자동 감지하여 적절한 차단 방식      │
│  (VS Code: exit 2, CLI: permissionDecision JSON)을 사용합니다│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Copilot CLI 전용 (확장 기능)                                │
│  .github/extensions/superpowers-enforcer/extension.mjs      │
│  ├── onUserPromptSubmitted  프롬프트 분석 → 스킬 자동 주입    │
│  ├── onErrorOccurred        모델 에러 자동 재시도             │
│  └── 커스텀 도구 3종 등록                                    │
│                                                             │
│  hooks로 대체 불가능한 SDK 전용 기능을 제공합니다.             │
└─────────────────────────────────────────────────────────────┘
```

---

## 스크립트 구성

```
install-superpowers-copilot-plugin.sh            ← 1단계: 전역 플러그인 (스킬, 에이전트, 지시사항)
install-superpowers-copilot-vscode-hooks.sh      ← 2단계 A: 셸 Hook (VS Code + CLI 공통)
install-superpowers-copilot-cli-extensions.sh    ← 2단계 B: SDK Extension (CLI 전용 확장)
```

---

## 설치 순서

### 1단계 — 플러그인 설치 (필수, 최초 1회)

```bash
bash install-superpowers-copilot-plugin.sh
```

모든 Hook의 전제 조건입니다. 이것부터 실행해야 합니다.

설치되는 것:
- `~/.copilot/skills/` → 14개 스킬 파일 (개별 symlink)
- `~/.copilot/agents/code-reviewer.md` → 코드 리뷰 에이전트
- `~/.copilot/copilot-instructions.md` → 스킬 로딩 지시 + 한국어 응답 설정

### 2단계 A — 셸 Hook 설치 (VS Code + CLI 공통, 프로젝트별)

```bash
bash install-superpowers-copilot-vscode-hooks.sh /path/to/project
```

`hooks.json`이 dual-format(PascalCase + camelCase)으로 생성되어
**VS Code Copilot Chat과 Copilot CLI 모두**에서 동작합니다.

생성되는 것:
```
프로젝트/
└── .github/
    └── hooks/
        ├── hooks.json            ← 이벤트 라우팅 (VS Code + CLI dual-format)
        ├── config.json           ← 프로젝트별 설정
        └── scripts/
            ├── session-start.sh  ← 스킬 컨텍스트 + 한국어 지시 주입
            ├── pre-tool-use.sh   ← HARD-GATE 차단 (환경 자동 감지)
            └── post-tool-use.sh  ← 린트 자동 실행 (선택)
```

> `.github/hooks/`는 VS Code의 기본 `chat.hookFilesLocations`에 포함되어 있어
> `.vscode/settings.json` 설정 없이 자동으로 로드됩니다.

`.gitignore`에 자동 추가되는 항목:
```
.github/hooks/hooks.json
.github/hooks/config.json
.github/hooks/scripts/session-start.sh
.github/hooks/scripts/pre-tool-use.sh
.github/hooks/scripts/post-tool-use.sh
```

### 2단계 B — CLI SDK Extension 설치 (CLI 전용, 프로젝트별)

```bash
bash install-superpowers-copilot-cli-extensions.sh /path/to/project
```

셸 Hook으로는 불가능한 **CLI 전용 확장 기능**을 추가합니다.

생성되는 것:
```
프로젝트/
└── .github/
    └── extensions/
        └── superpowers-enforcer/
            ├── extension.mjs    ← SDK Extension (JavaScript ES Module)
            └── config.json      ← 프로젝트별 설정
```

`.gitignore`에 자동 추가되는 항목:
```
.github/extensions/superpowers-enforcer/extension.mjs
.github/extensions/superpowers-enforcer/config.json
```

### 전체 설치 (권장)

```bash
bash install-superpowers-copilot-plugin.sh                        # 1회
bash install-superpowers-copilot-vscode-hooks.sh /path/to/project # VS Code + CLI
bash install-superpowers-copilot-cli-extensions.sh /path/to/project # CLI 확장
```

---

## 두 가지 Hook 방식의 차이

### 셸 Hook (vscode-hooks.sh) — VS Code + CLI 공통

| 항목 | 설명 |
|------|------|
| 파일 위치 | `.github/hooks/hooks.json` |
| 로직 방식 | Bash 셸 스크립트 |
| 이벤트 형식 | PascalCase (`SessionStart`) + camelCase (`sessionStart`) dual-format |
| VS Code 차단 | `exit 2` + stderr 메시지 |
| CLI 차단 | `permissionDecision: "deny"` JSON stdout |
| 환경 감지 | `toolArgs` 필드 유무로 자동 판별 |
| 활성화 | 자동 (`.github/hooks/`는 기본 탐색 경로) |

### SDK Extension (cli-extensions.sh) — CLI 전용

| 항목 | 설명 |
|------|------|
| 파일 위치 | `.github/extensions/*/extension.mjs` |
| 로직 방식 | JavaScript ES Module (`@github/copilot-sdk`) |
| 활성화 | 자동 (Extension 디렉토리 스캔) |
| 커스텀 도구 | ✅ 3종 등록 가능 |
| 프롬프트 분석 | ✅ (`onUserPromptSubmitted`) |
| 에러 처리 | ✅ (`onErrorOccurred`) |

### SDK Extension에만 있는 기능

다음은 셸 Hook으로 대체할 수 없는 SDK 전용 기능입니다:

| 기능 | 설명 |
|------|------|
| `onUserPromptSubmitted` | 사용자 프롬프트에서 build/debug 의도를 감지하여 스킬 자동 주입 |
| `onErrorOccurred` | 모델 호출 에러 시 자동 재시도 (최대 2회) |
| `superpowers_brainstorming_complete` | 에이전트가 직접 HARD-GATE 해제 (도구 호출) |
| `superpowers_read_skill` | 스킬 파일을 에이전트가 직접 로드 |
| `superpowers_status` | 세션 상태 조회 (게이트 상태, 위반 횟수 등) |
| 인메모리 상태 | 세션 내 state 추적 (`brainstormingDone`, `gateViolations` 등) |

---

## HARD-GATE 차단 대상 도구 (8개)

두 방식 모두 동일한 도구 목록을 차단합니다:

| 도구 | 환경 |
|------|------|
| `create_file` | VS Code |
| `replace_string_in_file` | VS Code |
| `multi_replace_string_in_file` | VS Code |
| `edit_notebook_file` | VS Code |
| `create` | CLI |
| `edit` | CLI |
| `str_replace_based_edit_tool` | CLI |

> 테스트 파일 (`.test.`, `.spec.`, `/tests/`, `/__tests__/`)은 항상 허용됩니다.

---

## 강제성 수준 비교

```
강제성 강함 ←——————————————————————————→ 강제성 약함

Copilot CLI           VS Code              Copilot CLI       Cline
(hooks + extension)   (hooks)              (plugin만)        (.clinerules)
셸 Hook + SDK         셸 Hook              텍스트 지시        텍스트 지시
OS 레벨 차단           OS 레벨 차단          AI 무시 가능       AI 무시 가능
AI 무시 불가            AI 무시 불가
```

---

## config.json 설정

CLI (`extension.mjs` 옆)와 VS Code (`.github/hooks/` 안) 모두 동일한 설정 키를 사용합니다.

```json
{
  "enforceHardGates": true,
  "logSkillInvocations": true,
  "enableLintAfterEdit": false,
  "lintCommand": "npx eslint --fix",
  "lintExtensions": [".ts", ".tsx", ".js", ".jsx"]
}
```

`enforceHardGates: false` 로 설정하면 차단 없이 경고만 표시합니다.

---

## 일반적인 워크플로우

```
1. "로그인 기능 추가해줘"
   → SessionStart hook: using-superpowers 스킬 컨텍스트 + 한국어 지시 주입됨
   → CLI: onUserPromptSubmitted가 build 의도 감지 → brainstorming 스킬 자동 주입

2. brainstorming 스킬 실행 → 설계 승인
   → PreToolUse: brainstorming 미완료 시 코드 파일 작성 시도 차단

3. HARD-GATE 해제:
   CLI:     superpowers_brainstorming_complete 도구 호출 (SDK Extension)
   VS Code: /tmp/superpowers-edit-state-<hash>.json 파일 생성

4. 코드 작성 → PostToolUse: 린트 자동 실행 (활성화 시)
```

---

## 스킬 목록 (14개)

| 스킬 | 사용 시점 |
|------|-----------|
| `brainstorming` | 모든 기능 개발 시작 전 — 설계 없이 코드 금지 |
| `writing-plans` | 설계 승인 후 구현 계획 작성 |
| `test-driven-development` | 코드 작성 전 항상 — RED→GREEN→REFACTOR |
| `systematic-debugging` | 버그/테스트 실패 시 — 추측 수정 금지 |
| `executing-plans` | 계획 실행 (서브에이전트 없는 환경) |
| `subagent-driven-development` | 계획 실행 (서브에이전트 있는 환경) |
| `dispatching-parallel-agents` | 병렬 작업 분배 |
| `requesting-code-review` | PR 준비 완료 후 |
| `receiving-code-review` | 리뷰 피드백 반영 시 |
| `verification-before-completion` | 작업 완료 선언 전 항상 |
| `using-git-worktrees` | 새 기능 브랜치 시작 시 |
| `finishing-a-development-branch` | 브랜치 머지 준비 시 |
| `writing-skills` | 새 팀 전용 스킬 작성 시 |
| `using-superpowers` | 세션 시작 시 자동 주입 (메타 스킬) |

---

## 제거

### 스크립트로 제거 (권장)

```bash
# 플러그인 전역 제거
bash install-superpowers-copilot-plugin.sh uninstall

# CLI Extension 제거 (프로젝트별)
bash install-superpowers-copilot-cli-extensions.sh uninstall /path/to/project

# 셸 Hook 제거 (프로젝트별)
bash install-superpowers-copilot-vscode-hooks.sh uninstall /path/to/project
```

각 uninstall 동작:

| 스크립트 | 제거 대상 |
|---|---|
| `install-superpowers-copilot-plugin.sh uninstall` | `~/.copilot/skills/` 스킬 symlink들, `~/.copilot/agents/code-reviewer.md`, `copilot-instructions.md` 블록 |
| `install-superpowers-copilot-cli-extensions.sh uninstall` | `.github/extensions/superpowers-enforcer/` |
| `install-superpowers-copilot-vscode-hooks.sh uninstall` | `.github/hooks/` |

### 수동 제거

```bash
# CLI Extension 제거
rm -rf 프로젝트/.github/extensions/superpowers-enforcer/

# 셸 Hook 제거
rm -rf 프로젝트/.github/hooks/

# 플러그인 전역 제거
rm -f ~/.copilot/skills/brainstorming  # 등 개별 symlink 제거
rm -f ~/.copilot/agents/code-reviewer.md
# ~/.copilot/copilot-instructions.md에서 superpowers 블록 수동 제거
```
