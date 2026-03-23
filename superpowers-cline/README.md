# Superpowers for Cline

obra/superpowers 스킬 프레임워크를 Cline(VS Code)에서 사용하기 위한 설정 파일 모음입니다.

---

## Before vs After

> **같은 요청, 전혀 다른 결과**  
> `"로그인 기능을 추가해줘"` — 빈 프로젝트에서 실행한 결과를 비교합니다.

### ❌ Before: Superpowers 없이

Cline이 질문 없이 즉시 코드를 생성합니다.

```
┌─────────────────────────────────────────────────┐
│  "로그인 기능을 추가해줘"                         │
├─────────────────────────────────────────────────┤
│                                                 │
│  🤖 Cline:                                     │
│  네, 로그인 기능을 구현하겠습니다.                │
│                                                 │
│  > Cline wants to execute this command:         │
│                                                 │
│    npm install express express-session           │
│    bcrypt jsonwebtoken mongoose                  │
│                                                 │
│  📁 Creating: src/routes/auth.js                │
│  📁 Creating: src/middleware/auth.js             │
│  📁 Creating: src/models/User.js                │
│  📁 Creating: src/config/database.js            │
│                                                 │
│  ✅ 로그인 기능이 완성되었습니다!                 │
│     - JWT 기반 인증                              │
│     - MongoDB 연결 설정                          │
│     - 회원가입 + 로그인 + 로그아웃 구현           │
│                                                 │
└─────────────────────────────────────────────────┘
```

**문제점:**
- 🚫 기술 스택을 물어보지 않음 — JWT를 임의로 선택
- 🚫 저장소를 확인하지 않음 — MongoDB를 가정
- 🚫 엔드포인트 범위를 모름 — 회원가입까지 과잉 구현
- 🚫 대안을 제시하지 않음 — 선택지 없이 한 가지 방식만 진행
- **결과: 원래 의도와 다른 코드 → 다시 만들어야 함**

---

### ✅ After: Superpowers 설치 후

Cline이 `brainstorming` 스킬을 자동으로 실행합니다.  
**코드를 한 줄도 쓰기 전에** 요구사항을 탐색하고 설계합니다.

> 📖 **실제 세션 전문**: [res/example_cline_session/session_export.md](./res/example_cline_session/session_export.md)  
> 아래는 해당 세션의 핵심 흐름을 요약한 것입니다.

> 📁 **예시 파일**
> - 설계 문서: [res/example_superpowers_plan_and_spec/2026-03-23-login-design.md](./res/example_superpowers_plan_and_spec/2026-03-23-login-design.md)
> - 구현 계획: [res/example_superpowers_plan_and_spec/2026-03-23-login.md](./res/example_superpowers_plan_and_spec/2026-03-23-login.md)

#### 1단계: 스킬 자동 인식 & 프로젝트 탐색

```
🤖 Cline:
  Using brainstorming skill to approach this feature request
  before writing any code.

  📖 Read: ~/.agents/skills/superpowers/brainstorming/SKILL.md

  프로젝트 탐색 중...
  - .clinerules ✅ (트리거 확인)
  - 프로젝트 상태: 빈 프로젝트 (커밋 없음)
```

- `.clinerules`의 트리거를 통해 `brainstorming` 스킬을 자동 인식
- `SKILL.md` 파일을 읽어 프로세스를 이해한 뒤, 프로젝트 상태 탐색

#### 2단계: Visual Companion 제안

```
🤖 Cline has a question:

  Some of what we're working on might be easier to explain
  if I can show it to you in a web browser. I can put together
  mockups, diagrams, comparisons, and other visuals as we go.
  Want to try it?

  ┌──────────────────────────────────────┐
  │  Yes, use the visual companion       │
  ├──────────────────────────────────────┤
  │  No, text-only is fine         ← 선택│
  └──────────────────────────────────────┘
```

- UI 관련 주제를 감지하고 시각적 도구를 먼저 제안
- 사용자 선택 존중 (text-only 선택 시 텍스트로 진행)

#### 3단계: 명확화 질문 — 한 번에 하나씩

기술적 결정을 사용자에게 맡기며, **한 번에 하나의 질문만** 합니다.

```
🤖 어떤 기술 스택으로 로그인 기능을 구현할까요?

  React (프론트엔드 SPA)
  Next.js (풀스택)
  Node.js + Express (백엔드 API)          ← 선택
  Python (Flask/FastAPI/Django)
  다른 스택 (직접 입력)

🤖 사용자 데이터는 어디에 저장할까요?

  인메모리 (Map/배열) — 데이터베이스 없이   ← 선택
  SQLite — 파일 기반 경량 DB
  PostgreSQL / MySQL — 본격적인 관계형 DB
  MongoDB — NoSQL

🤖 필요한 엔드포인트 범위는 어디까지인가요?

  로그인 + 로그아웃만 (POST /login, POST /logout)    ← 선택
  회원가입 + 로그인 + 로그아웃
  위에 더해 인증된 사용자만 접근 가능한 보호 라우트 예시 포함
```

#### 4단계: 접근 방식 제안 & 비교

수집한 요구사항을 바탕으로 **2~3가지 접근 방식**을 제안하고, 각각의 장단점을 분석합니다:

```
🤖 접근 방식 A (권장): Minimal Express 앱 — 단일 파일
  ✅ 가장 단순, 즉시 실행 가능
  ✅ 의존성 최소 (express, express-session, bcrypt)
  ⚠️ 코드가 늘어나면 분리 필요

  접근 방식 B: 계층 분리 구조 (routes / middleware / store)
  ✅ 확장성 좋음, 나중에 DB 교체 용이
  ⚠️ 현재 요구사항에 과잉

  접근 방식 C: express-session 없이 서명된 쿠키만 사용
  ✅ 외부 세션 저장소 불필요
  ⚠️ 세서 무효화(로그아웃 시 서버 측 취소)가 불완전

  권장: 접근 방식 A
```

**사용자가 접근 방식을 선택한 후에야** 구현이 시작됩니다.

#### 5단계: 설계 문서 → 구현 계획 → TDD 구현

설계 승인 후 자동으로 다음 스킬들이 순서대로 실행됩니다:

- 📄 설계 문서 생성
- 📄 구현 계획 생성 (위 `예시 파일` 박스에서 실제 예시 확인 가능)

🔴🟢🔵 TDD 사이클 (Red → Green → Refactor)

- Task 1: 프로젝트 초기화 + 의존성 설치
- Task 2: POST /login 필드 누락 (400) — 테스트 먼저 → 구현
- Task 3: POST /login 성공 + 인증 실패 (200, 401)
- Task 4: POST /logout (200, 401)

✅ 최종 결과: 7/7 테스트 통과, 4개 atomic 커밋

---

### 핵심 차이 요약

| | Before | After |
|--|--------|-------|
| 스킬 참조 | ❌ 없음 | ✅ brainstorming SKILL.md 자동 로드 |
| 질문 수 | 0개 | 4~6개 (한 번에 하나씩) |
| 기술 선택 | AI가 임의 결정 | **사용자가 선택** |
| 대안 제시 | 없음 | 2~3가지 비교 분석 |
| 설계 문서 | ❌ 없음 | `docs/superpowers/specs/` 에 저장 |
| 구현 계획 | ❌ 없음 | `docs/superpowers/plans/` 에 태스크 단위 작성 |
| 구현 시작 | 즉시 | 설계 승인 후 |
| 테스트 | ❌ 없거나 사후 작성 | RED → GREEN → REFACTOR (TDD) |
| 완료 검증 | ❌ "완성했습니다" 선언만 | 실제 테스트 + 시나리오 검증 후 선언 |
| 결과물 | 다시 만들어야 할 수 있음 | 처음부터 의도에 맞게 |

### Superpowers 작업 절차

Superpowers가 설치되면 Cline은 아래 절차를 자동으로 따릅니다:

```
1. 탐색 & 질문     요구사항·제약·기존 코드 구조를 탐색하고,
                    모호한 점은 먼저 질문해 명확히 함 (brainstorming)

2. 설계 문서 작성   탐색 결과를 docs/superpowers/specs/ 에 저장
                    파일명: YYYY-MM-DD-<topic>-design.md

3. 구현 계획 수립   docs/superpowers/plans/ 에 태스크 단위 계획을 저장
                    각 태스크에 대상 파일 경로·변경 범위·검증 방법 명시

4. TDD 구현         각 태스크는 테스트를 먼저 작성하고
                    RED → GREEN → REFACTOR 순서를 따름

5. 태스크별 검증    각 태스크 종료 시 설계/계획 대비 셀프 체크리스트 완료

6. 최종 검증        전체 작업 종료 전, 실제 시나리오와 테스트로 최종 검증
```

### 핵심 규칙

| 규칙 | 설명 |
|------|------|
| **설계 우선** | 설계/계획 문서 작성 전에는 코드나 파일을 변경하지 않는다 |
| **TDD 필수** | 테스트 없는 기능 추가는 금지한다 |
| **YAGNI** | 지금 당장 필요하지 않은 코드는 작성하지 않는다 |
| **스킬 동적 참조** | 파일명/날짜 형식 등 세부 규칙은 `~/.agents/skills/` 의 최신 스킬 문서를 따른다 |
| **검증 후 선언** | 완료 선언 전에 반드시 실제 테스트/시나리오 검증을 수행한다 |

> 💡 위 After 내용은 실제 Cline 세션을 export한 것입니다.  
> 전체 대화 내용(106 turns, 5500+ lines)은 아래에서 확인할 수 있습니다:  
> **[📖 실제 세션 전문 보기](./res/example_cline_session/session_export.md)**

---

## 설치

```bash
# 프로젝트 경로 지정 필수
bash install-superpowers-cline.sh /your/project
```

설치되는 것:
- `AGENTS.md` — 에이전트 공통 지시사항
- `.clinerules` — Cline이 자동으로 읽는 규칙 파일
- `docs/superpowers/{specs,plans}/` — 설계/계획 문서 디렉토리
- `.gitignore` — 아래 항목 자동 추가

`.gitignore`에 자동 추가되는 항목:
```
/AGENTS.md
/.clinerules
docs/superpowers/plans/
docs/superpowers/specs/
```

### 스킬 디렉토리 구성 (최초 1회)

```bash
git clone --depth=1 https://github.com/obra/superpowers.git /tmp/superpowers
mkdir -p ~/.agents/skills
cp -r /tmp/superpowers/skills ~/.agents/skills/superpowers
```

---

## 파일 구조

```
your-project/
├── .clinerules          ← Cline이 자동으로 읽는 규칙 파일
├── AGENTS.md            ← 에이전트 공통 지시사항
└── docs/
    └── superpowers/
        ├── specs/       ← 설계 문서 (brainstorming 결과)
        └── plans/       ← 구현 계획 (writing-plans 결과)

~/.agents/skills/superpowers/
├── brainstorming/SKILL.md
├── test-driven-development/SKILL.md
├── systematic-debugging/SKILL.md
├── writing-plans/SKILL.md
└── ... (14개 스킬)
```

---

## 사용법

스킬을 호출하려면 자연어로 요청하세요. `.clinerules`에 정의된 트리거가
Cline이 자동으로 적절한 스킬을 읽도록 유도합니다.

```
# 새 기능 개발 시작
"로그인 기능을 추가하고 싶어"
→ Cline이 brainstorming/SKILL.md를 읽고 설계 프로세스 시작

# 버그 수정
"테스트가 왜 실패하는지 모르겠어"
→ Cline이 systematic-debugging/SKILL.md를 읽고 4단계 디버깅 프로세스 시작

# 명시적 호출
"brainstorming 스킬을 사용해서 이 아이디어를 탐색해줘"
```

---

## 스킬 목록 & 사용 시점

| 스킬 | 사용 시점 |
|------|-----------|
| `brainstorming` | 모든 기능 개발 시작 전 — 설계 없이 코드 금지 |
| `writing-plans` | 설계 승인 후 — 구현 계획 작성 |
| `test-driven-development` | 코드 작성 전 항상 — RED→GREEN→REFACTOR |
| `systematic-debugging` | 버그/테스트 실패 발생 시 — 추측 수정 금지 |
| `executing-plans` | 계획 실행 (서브에이전트 없는 환경) |
| `subagent-driven-development` | 계획 실행 (서브에이전트 있는 환경) |
| `dispatching-parallel-agents` | 병렬 작업 분배 |
| `requesting-code-review` | PR 준비 완료 후 |
| `receiving-code-review` | 리뷰 피드백 반영 시 |
| `verification-before-completion` | 작업 완료 선언 전 항상 |
| `using-git-worktrees` | 새 기능 브랜치 시작 시 |
| `finishing-a-development-branch` | 브랜치 머지 준비 시 |
| `writing-skills` | 새 팀 전용 스킬 작성 시 |
| `using-superpowers` | 세션 시작 시 자동 (메타 스킬) |

---

## 제거

### 스크립트로 제거 (권장)

```bash
bash install-superpowers-cline.sh uninstall /path/to/project
```

제거 대상:
- `.clinerules`
- `AGENTS.md`
- `docs/superpowers/`
- `.gitignore`의 관련 항목

> `~/.agents/skills/superpowers`가 symlink인 경우(Copilot과 공유 중) 자동 삭제하지 않고 수동 제거 안내만 표시합니다.

### 수동 제거

```bash
rm -f  /path/to/project/.clinerules
rm -f  /path/to/project/AGENTS.md
rm -rf /path/to/project/docs/superpowers
rm -rf ~/.agents/skills/superpowers
```

