# Superpowers for Cline

obra/superpowers 스킬 프레임워크를 Cline(VS Code)에서 사용하기 위한 설정 파일 모음입니다.

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

