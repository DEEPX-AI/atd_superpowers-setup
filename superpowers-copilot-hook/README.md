# Superpowers for GitHub Copilot

obra/superpowers 스킬 프레임워크를 GitHub Copilot CLI와 VS Code Copilot Chat에
적용하기 위한 설치 스크립트 모음입니다.

---

## 스크립트 구성

```
install-superpowers-copilot-plugin.sh        ← 1단계: 플러그인 설치 (필수, 전역)
install-superpowers-copilot-cli-hooks.sh     ← 2단계 A: Copilot CLI Hook 강제화
install-superpowers-copilot-vscode-hooks.sh  ← 2단계 B: VS Code Copilot Chat Hook 강제화
```

---

## 설치 순서

### 1단계 — 플러그인 설치 (필수, 최초 1회)

```bash
bash install-superpowers-copilot-plugin.sh
```

모든 hook 스크립트의 전제 조건입니다. 이것부터 실행해야 합니다.

설치되는 것:
- `~/.copilot/skills/superpowers/` → 14개 스킬 파일 (symlink)
- `~/.copilot/agents/code-reviewer.md` → 코드 리뷰 에이전트
- `~/.copilot/copilot-instructions.md` → 스킬 로딩 지시 추가

### 2단계 A — Copilot CLI Hook 강제화 (프로젝트별)

```bash
bash install-superpowers-copilot-cli-hooks.sh /path/to/project
```

생성되는 것:
```
프로젝트/
└── .github/
    └── extensions/
        └── superpowers-enforcer/
            ├── extension.mjs    ← Hook 로직 (Copilot SDK JS Extension)
            └── config.json      ← 프로젝트별 설정
```

`.gitignore`에 자동 추가되는 항목:
```
.github/extensions/superpowers-enforcer/extension.mjs
.github/extensions/superpowers-enforcer/config.json
```

### 2단계 B — VS Code Copilot Chat Hook 강제화 (프로젝트별)

```bash
bash install-superpowers-copilot-vscode-hooks.sh /path/to/project
```

생성되는 것:
```
프로젝트/
├── .vscode/
│   └── settings.json            ← chat.hooks.enabled: true 추가
└── .github/
    └── hooks/
        ├── hooks.json            ← Hook 이벤트 설정
        ├── config.json           ← 프로젝트별 설정
        └── scripts/
            ├── session-start.sh  ← 스킬 컨텍스트 주입
            ├── pre-tool-use.sh   ← HARD-GATE 차단 (exit 2)
            └── post-tool-use.sh  ← 린트 자동 실행 (선택)
```

`.gitignore`에 자동 추가되는 항목:
```
.github/hooks/hooks.json
.github/hooks/config.json
.github/hooks/scripts/session-start.sh
.github/hooks/scripts/pre-tool-use.sh
.github/hooks/scripts/post-tool-use.sh
.vscode/settings.json
```

### CLI + VS Code 모두 적용 (권장)

```bash
bash install-superpowers-copilot-plugin.sh
bash install-superpowers-copilot-cli-hooks.sh /path/to/project
bash install-superpowers-copilot-vscode-hooks.sh /path/to/project
```

---

## CLI vs VS Code Hook 방식 차이

두 환경은 hook 시스템이 완전히 다릅니다.

| | Copilot CLI | VS Code Copilot Chat |
|---|---|---|
| hook 파일 위치 | `.github/extensions/*/extension.mjs` | `.github/hooks/hooks.json` |
| hook 로직 방식 | JavaScript 함수 (`onPreToolUse` 등) | 셸 스크립트 (`pre-tool-use.sh`) |
| 실행 차단 방법 | `permissionDecision: "deny"` 반환 | `exit 2` |
| 활성화 조건 | 자동 (Extension 디렉토리 스캔) | `chat.hooks.enabled: true` 필요 |
| 추가 커스텀 도구 | ✅ (`superpowers_read_skill` 등) | ❌ |

---

## 강제성 수준 비교

```
강제성 강함 ←——————————————————————————→ 강제성 약함

Copilot CLI          VS Code              Copilot CLI       Cline
(cli-hooks.sh)       (vscode-hooks.sh)    (plugin만)        (.clinerules)
JS Extension         셸 스크립트          텍스트 지시        텍스트 지시
OS 레벨 차단          OS 레벨 차단          AI 무시 가능       AI 무시 가능
AI 무시 불가           AI 무시 불가
```

---

## Hook 동작 상세

### 공통 (CLI + VS Code)

| Hook | 동작 |
|------|------|
| `SessionStart` | `using-superpowers` 스킬 전체를 초기 컨텍스트에 주입 |
| `PreToolUse` | 설계 없이 코드 파일 작성 시도 → 실제 차단 |
| `PostToolUse` | 파일 편집 후 린트 자동 실행 (config에서 활성화 필요) |

### CLI 전용 커스텀 도구

| 도구 | 설명 |
|------|------|
| `superpowers_brainstorming_complete` | 설계 완료 신호 → 코드 작성 잠금 해제 |
| `superpowers_read_skill` | 스킬 파일 로드 (14개 스킬) |
| `superpowers_status` | 현재 세션 상태 확인 |

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
   → SessionStart hook: using-superpowers 스킬 컨텍스트 이미 주입됨
   → PreToolUse: brainstorming 미완료 → 코드 파일 작성 시도 시 차단

2. brainstorming 스킬 실행 → 설계 승인

3. CLI:     superpowers_brainstorming_complete 도구 호출 → 잠금 해제
   VS Code: /tmp/superpowers-state-<hash>.json 생성 → 잠금 해제

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

# CLI Hook 제거 (프로젝트별)
bash install-superpowers-copilot-cli-hooks.sh uninstall /path/to/project

# VS Code Hook 제거 (프로젝트별)
bash install-superpowers-copilot-vscode-hooks.sh uninstall /path/to/project
```

각 uninstall 동작:

| 스크립트 | 제거 대상 |
|---|---|
| `install-superpowers-copilot-plugin.sh uninstall` | `~/.copilot/skills/superpowers`, `~/.copilot/agents/code-reviewer.md`, `copilot-instructions.md` 블록 |
| `install-superpowers-copilot-cli-hooks.sh uninstall` | `.github/extensions/superpowers-enforcer/` |
| `install-superpowers-copilot-vscode-hooks.sh uninstall` | `.github/hooks/`, `.vscode/settings.json`의 `chat.hooks.enabled` |

### 수동 제거

```bash
# CLI Extension 제거
rm -rf 프로젝트/.github/extensions/superpowers-enforcer/

# VS Code Hook 제거
rm -rf 프로젝트/.github/hooks/
# .vscode/settings.json에서 chat.hooks.enabled 제거

# 플러그인 전역 제거
rm -f ~/.copilot/skills/superpowers
rm -f ~/.copilot/agents/code-reviewer.md
# ~/.copilot/copilot-instructions.md에서 superpowers 블록 수동 제거
```
