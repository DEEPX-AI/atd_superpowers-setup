# Superpowers for OpenCode

[OpenCode.ai](https://opencode.ai)용 Superpowers 설치 스크립트.

## 설치

```bash
# 통합 설치 (Cline + Copilot + OpenCode)
bash install.sh all /path/to/project

# OpenCode만 설치
bash install.sh opencode /path/to/project
```

## 설치 내용

1. `~/.config/opencode/opencode.json`에 plugin 추가
2. 프로젝트에 `AGENTS.md`, `docs/superpowers/` 생성
3. `.gitignore` 업데이트

## 제거

```bash
bash uninstall.sh opencode /path/to/project
```

## 공식 방식

공식 설치 방법은 opencode.json에 plugin 배열을 추가하는 것입니다:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

이 스크립트는 자동으로 이 설정을 추가합니다.

## 검증

설치 후 OpenCode를 재시작하고 다음 명령으로 확인:

```
Tell me about your superpowers
```

## 참고

- [공식 superpowers 문서](https://github.com/obra/superpowers)
- [OpenCode 공식 plugin 가이드](https://github.com/obra/superpowers/blob/main/docs/README.opencode.md)
