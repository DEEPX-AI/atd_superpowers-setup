# Login Feature Design Spec

**Date:** 2026-03-23
**Status:** Approved

## Overview

Node.js + Express 기반 백엔드 API에 세션 기반 로그인/로그아웃 기능을 추가한다.

## Approach

**접근 방식 A: 단일 파일** — `app.js` 하나에 모든 로직(라우트, 세션, 인메모리 스토어)을 포함하는 최소 구조.

## Project Structure

```
├── package.json
├── app.js          ← Express 앱 (라우트, 세션, 인메모리 스토어)
├── app.test.js     ← 테스트 (jest + supertest)
└── docs/
```

## Dependencies

**Production:**
- `express` — 웹 프레임워크
- `express-session` — 세션 관리
- `bcrypt` — 비밀번호 해싱

**Dev:**
- `jest` + `supertest` — 테스트

## API Design

| Endpoint | Method | Request Body | Success | Failure |
|----------|--------|-------------|---------|---------|
| `/login` | POST | `{ "username": "...", "password": "..." }` | `200 { "message": "로그인 성공" }` + 세션 쿠키 | `400` 필드 누락, `401` 인증 실패 |
| `/logout` | POST | 없음 (세션 쿠키로 식별) | `200 { "message": "로그아웃 성공" }` + 세션 파기 | `401` 미로그인 |

## In-Memory User Store

- `Map<string, { id, username, hashedPassword }>` 형태
- 앱 시작 시 시드 유저 1~2명 등록 (bcrypt 해시)
- 별도 회원가입 엔드포인트 없음

## Session Configuration

- `express-session` 기본 `MemoryStore` 사용 (개발/데모용)
- 쿠키: `httpOnly: true`, `secure: false` (로컬 개발)
- `secret`: 하드코딩 문자열 (데모용)

## Data Flow

### Login

```
POST /login { username, password }
  → 필드 검증 (빈 값 체크)
  → Map에서 username으로 유저 조회
  → bcrypt.compare(password, hashedPassword)
  → 성공: req.session.userId = user.id → 200
  → 실패: 401 ("아이디 또는 비밀번호가 올바르지 않습니다")
```

### Logout

```
POST /logout (세션 쿠키 포함)
  → req.session.userId 확인
  → 있으면: req.session.destroy() → 200
  → 없으면: 401 ("로그인되지 않았습니다")
```

## Error Handling

| Scenario | Status | Response |
|----------|--------|----------|
| 필드 누락 (username/password) | 400 | `{ "error": "username과 password를 입력해주세요" }` |
| 인증 실패 (잘못된 유저/비번) | 401 | `{ "error": "아이디 또는 비밀번호가 올바르지 않습니다" }` |
| 미로그인 상태에서 로그아웃 | 401 | `{ "error": "로그인되지 않았습니다" }` |
| JSON 파싱 실패 | 400 | Express 기본 에러 |

**보안 참고:** 유저 존재 여부를 노출하지 않기 위해, 유저가 없거나 비번이 틀려도 동일한 401 메시지를 반환한다.

## Test Plan

| # | 테스트 | 기대 결과 |
|---|--------|----------|
| 1 | 올바른 자격증명으로 로그인 | 200 + 세션 쿠키 |
| 2 | 잘못된 비밀번호로 로그인 | 401 |
| 3 | 존재하지 않는 유저로 로그인 | 401 (동일 메시지) |
| 4 | 필드 누락으로 로그인 | 400 |
| 5 | 로그인 후 로그아웃 | 200 |
| 6 | 미로그인 상태에서 로그아웃 | 401 |
| 7 | 로그아웃 후 재로그아웃 | 401 |