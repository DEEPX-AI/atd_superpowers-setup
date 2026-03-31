# superpowers-setup

obra/superpowers 스킬 프레임워크를 AI 개발 도구에 적용하기 위한 설치 스크립트 모음입니다.

---

## 배경

### 도구 요약

| 도구 | 주 사용 환경 | Superpowers 적용/강제 방식 | 강제성 |
|---|---|---|---|
| **Claude Code** | 터미널 CLI | OS 레벨 런타임 Hook + 공식 Superpowers 지원 | 강함 |
| **Copilot Chat** | VS Code Chat | 셸 Hook으로 Superpowers 흐름 적용 및 강제화 | 강함 |
| **Copilot CLI** | 터미널 CLI | 셸 Hook + SDK Extension으로 Superpowers 흐름 적용 및 강제화 | 강함 |
| **Cline** | VS Code Extension | `.clinerules` 기반 텍스트 지시로 Superpowers 흐름 적용 | 약함 |
| **OpenCode** | 터미널 CLI | 공식 plugin 방식(opencode.json)으로 Superpowers 적용 및 강제화 | 강함 |

세부 항목 비교는 아래의 `도구 비교` 섹션에 정리했습니다.

### 이 프로젝트를 만든 이유

Claude Code를 직접 쓰기 어렵거나(**회사 지원 도구가 GitHub Copilot, OpenCode 등으로 제한**) 다양한 AI 개발 환경에서 Superpowers의 체계적 워크플로우를 손쉽게 적용할 수 있도록 **표준화하여 팀 전체에 확산**하기 위함입니다.

OpenCode 환경에서도 공식 Superpowers 플러그인 방식으로 동일한 워크플로우를 강제·적용할 수 있도록 지원합니다.

핵심 목표는 다음과 같습니다.


| 목표 | 의미 |
|---|---|
| **Copilot Chat 적용 및 강제화** | VS Code의 `Copilot Chat`에 Superpowers 흐름을 적용하고, 셸 Hook으로 강제 |
| **Copilot CLI 적용 및 강제화** | `Copilot CLI`에 Superpowers 흐름을 적용하고, 셸 Hook + SDK Extension으로 강제 |
| **Cline 병행 적용** | `Cline`에도 동일한 흐름을 최대한 맞추되, 텍스트 지시 방식으로 보완 |
| **OpenCode 공식 플러그인 적용** | `OpenCode`에 Superpowers 공식 플러그인(opencode.json) 방식으로 동일한 워크플로우를 강제 |
| **설치 표준화** | 팀원 누구나 **스크립트 한 줄**로 동일한 개발 환경 구성 |
| **무계획 코딩 억제** | 설계 없이 바로 코드를 쓰지 못하도록 **워크플로우 레벨에서 제어** |

즉, 이 프로젝트는 단순 설치 스크립트 모음이 아니라,
**Copilot Chat, Copilot CLI, Cline 각각에 설계 → 계획 → 구현 순서를 적용하고 가능한 수준까지 강제하는 운영 레이어**입니다.

### 얻을 수 있는 것

| AS-IS | TO-BE |
|---|---|
| AI가 요청 즉시 코드 작성 시작 | 브레인스토밍 → 설계 → 계획 → 구현 순서 강제 |
| 설계가 승인되기 전에 코드가 나옴 | PreToolUse Hook으로 코드 파일 작성 사전 차단 |
| 추측 기반 버그 수정 | systematic-debugging 스킬로 근본 원인 파악 필수 |
| 팀마다 다른 AI 활용 방식 | 스킬 파일로 팀 워크플로우 표준화 |
| 환경 구성에 시간 낭비 | 스크립트 한 줄로 즉시 셋업 |

---

## Superpowers란?

[obra/superpowers](https://github.com/obra/superpowers)는 AI 코딩 도구가 따라야 할
개발 워크플로우(브레인스토밍, TDD, 체계적 디버깅 등)를 **스킬 파일**로 패키징한 프레임워크입니다.

출시 하루 만에 GitHub 스타 1,867개를 획득하며 큰 관심을 받았습니다.

핵심 철학은 **"에이전트가 코드를 바로 작성하는 것을 막는다"** 는 것입니다.
브레인스토밍 → 설계 → 계획 → 구현 → 리뷰의 구조화된 워크플로우를 강제합니다.

---

## 도구 비교

| | **Claude Code** | **Copilot Chat** | **Copilot CLI** | **Cline** | **OpenCode** |
|---|---|---|---|---|---|
| 환경 | 터미널 CLI | VS Code Chat | 터미널 CLI | VS Code Extension | 터미널 CLI |
| 모델 | Claude 전용 | 멀티모델 (Claude, GPT-5, Gemini 등) | 멀티모델 (Claude, GPT-5, Gemini 등) | 멀티모델 (Claude, OpenAI, 로컬 등) | 멀티모델 (Claude, GPT, Gemini, 로컬 등) |
| 비용 | Claude 구독 | Copilot 구독 포함 | Copilot 구독 포함 | Copilot 구독 + 모델 API 또는 구독 | 무료/유료 |
| Superpowers 지원 | ✅ 공식 | ⚠️ 커뮤니티 포트 | ⚠️ 커뮤니티 포트 | ❌ 수동 구성 | ✅ 공식 plugin |
| Hook 방식 | OS 레벨 런타임 | 셸 Hook (`.github/hooks/hooks.json`) | 셸 Hook + SDK Extension | 텍스트 지시 (`.clinerules`) | 공식 plugin |
| Hook 강제성 | AI 무시 불가 | AI 무시 불가 | AI 무시 불가 | AI 무시 가능 | AI 무시 불가 |
| Copilot 모델 연결 / 구독 | ❌ | ✅ | ✅ | ✅ (모델 연결 가능) | ✅ (공식 plugin, 모델 연결 가능) |

> **이 프로젝트의 목표:** Copilot Chat과 Copilot CLI 각각에 Superpowers 흐름을 적용하고 강제화하며,
> Cline에는 텍스트 지시 방식으로 최대한 동일한 워크플로우를 맞춥니다.

---

## 강제성 수준 비교

| 구성 | 적용 방식 | 차단 수준 | AI 무시 가능 여부 |
|------|-----------|-----------|-------------------|
| **Copilot CLI** (hooks + extension) | 셸 Hook + SDK Extension | OS 레벨 차단 | ❌ 무시 불가 |
| **VS Code Copilot Chat** (hooks) | 셸 Hook | OS 레벨 차단 | ❌ 무시 불가 |
| **OpenCode** (공식 plugin) | 공식 plugin(opencode.json) | OS/플랫폼 차단 | ❌ 무시 불가 |
| **Copilot CLI** (plugin만) | 텍스트 지시 | 소프트 가이드 | ⚠️ 무시 가능 |
| **Cline** (.clinerules) | 텍스트 지시 | 소프트 가이드 | ⚠️ 무시 가능 |

---

## 빠른 시작

```bash
# Cline + Copilot + OpenCode 모두 설치
bash install.sh all /path/to/project

# Cline만 설치
bash install.sh cline /path/to/project

# Copilot만 설치 (plugin + CLI Hook + VS Code Hook)
bash install.sh copilot /path/to/project

# OpenCode만 설치 (공식 plugin 방식)
bash install.sh opencode /path/to/project
```

### 제거

```bash
# Cline + Copilot + OpenCode 모두 제거 (Hook만, 플러그인 유지)
bash uninstall.sh all /path/to/project

# Cline만 제거
bash uninstall.sh cline /path/to/project

# Copilot Hook만 제거 (전역 플러그인 유지)
bash uninstall.sh copilot /path/to/project

# OpenCode만 제거
bash uninstall.sh opencode /path/to/project

# 전역 Copilot 플러그인까지 함께 제거 (다른 프로젝트에 영향 주의)
bash uninstall.sh copilot /path/to/project --with-plugin
bash uninstall.sh all    /path/to/project --with-plugin
```

---

## 폴더 구성

### [`superpowers-cline/`](superpowers-cline/README.md)

Cline(VS Code) 전용 설치 스크립트.

- `.clinerules` — Cline이 자동으로 읽는 스킬 호출 규칙
- `AGENTS.md` — 에이전트 공통 지시사항
- `docs/superpowers/{specs,plans}/` — 설계/계획 문서 디렉토리

```bash
# 설치
bash superpowers-cline/install-superpowers-cline.sh /path/to/project

# 제거
bash superpowers-cline/install-superpowers-cline.sh uninstall /path/to/project
```

---

### [`superpowers-copilot-hook/`](superpowers-copilot-hook/README.md)

GitHub Copilot용 Hook 설치 스크립트. VS Code Copilot Chat과 Copilot CLI 모두 지원합니다.

- **셸 Hook** (vscode-hooks.sh): VS Code + CLI 공통. 3개 이벤트(SESSION START, PRE/POST TOOL USE)를 dual-format `hooks.json`으로 처리
- **SDK Extension** (cli-extensions.sh): CLI 전용 확장. 프롬프트 분석, 커스텀 도구 등록, 에러 자동 재시도

최신 실세션 예시는 아래 파일에서 바로 확인할 수 있습니다.

- Transcript: [`superpowers-copilot-hook/res/example_copilot_cli_session/session_export.md`](superpowers-copilot-hook/res/example_copilot_cli_session/session_export.md)
- Spec / Plan: [`superpowers-copilot-hook/res/example_superpowers_plan_and_spec/2026-03-24-login-api-design.md`](superpowers-copilot-hook/res/example_superpowers_plan_and_spec/2026-03-24-login-api-design.md), [`superpowers-copilot-hook/res/example_superpowers_plan_and_spec/2026-03-24-login-api.md`](superpowers-copilot-hook/res/example_superpowers_plan_and_spec/2026-03-24-login-api.md)
- Brainstorm 화면: [`superpowers-copilot-hook/res/example_brainstorm_session/1353273-1774318201/approaches.html`](superpowers-copilot-hook/res/example_brainstorm_session/1353273-1774318201/approaches.html), [`superpowers-copilot-hook/res/example_brainstorm_session/1353273-1774318201/architecture.html`](superpowers-copilot-hook/res/example_brainstorm_session/1353273-1774318201/architecture.html)

스킬 호출을 **소프트 지시(텍스트)** 가 아닌 **하드 차단(Hook)** 으로 강제합니다.

```bash
# 1단계: 전역 플러그인 설치 (최초 1회)
bash superpowers-copilot-hook/install-superpowers-copilot-plugin.sh

# 2단계: 프로젝트별 Hook 강제화
bash superpowers-copilot-hook/install-superpowers-copilot-vscode-hooks.sh /path/to/project  # VS Code + CLI 공통
bash superpowers-copilot-hook/install-superpowers-copilot-cli-extensions.sh /path/to/project # CLI 전용 확장

# 제거 (Hook만, 전역 플러그인 유지)
bash superpowers-copilot-hook/install-superpowers-copilot-cli-extensions.sh uninstall /path/to/project
bash superpowers-copilot-hook/install-superpowers-copilot-vscode-hooks.sh uninstall /path/to/project

# 제거 (전역 플러그인까지 함께 제거)
bash superpowers-copilot-hook/install-superpowers-copilot-plugin.sh uninstall
```

---

### [`superpowers-opencode/`](superpowers-opencode/README.md)

OpenCode.ai 전용 설치 스크립트.

- **공식 Plugin 방식** — `opencode.json`에 plugin 배열 추가
- `AGENTS.md` — 에이전트 공통 지시사항
- `docs/superpowers/{specs,plans}/` — 설계/계획 문서 디렉토리

```bash
# 설치
bash superpowers-opencode/install-superpowers-opencode.sh /path/to/project

# 제거
bash superpowers-opencode/install-superpowers-opencode.sh uninstall /path/to/project
```

공식 예시 (opencode.json):

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

설치 후 검증:

```
Tell me about your superpowers
```

참고: 더 자세한 내용은 `superpowers-opencode/README.md`를 참조하세요.

---

## 스크립트 목록

| 스크립트 | 폴더 | 경로 필수 | 설명 |
|----------|------|:---------:|------|
| `install.sh` | 루트 | ✅ | 통합 설치 (`all` / `cline` / `copilot` / `opencode`) |
| `uninstall.sh` | 루트 | ✅ | 통합 제거 (`all` / `cline` / `copilot` / `opencode`) |
| `install-superpowers-cline.sh` | `superpowers-cline/` | ✅ | Cline 프로젝트 설정 |
| `install-superpowers-copilot-plugin.sh` | `superpowers-copilot-hook/` | ❌ | Copilot 전역 플러그인 (1회) |
| `install-superpowers-copilot-cli-extensions.sh` | `superpowers-copilot-hook/` | ✅ | Copilot CLI SDK Extension (CLI 전용 확장) |
| `install-superpowers-copilot-vscode-hooks.sh` | `superpowers-copilot-hook/` | ✅ | 셸 Hook (VS Code + CLI 공통) |
| `install-superpowers-opencode.sh` | `superpowers-opencode/` | ✅ | OpenCode 공식 plugin 설치 |

모든 스크립트는 `uninstall` 서브커맨드를 지원합니다.

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

