# 로그인 API 설계 문서

**날짜:** 2026-03-24  
**상태:** 승인됨

---

## 개요

Node.js + Express 기반 REST API 서버에 이메일/비밀번호 로그인 기능을 구현한다.  
사용자 인증 토큰으로 JWT(Access Token)를 발급하며, SQLite를 사용자 정보 저장소로 사용한다.

---

## 기술 스택

| 항목 | 선택 |
|------|------|
| 런타임 | Node.js |
| 프레임워크 | Express |
| 인증 방식 | JWT (Access Token only) |
| 데이터베이스 | SQLite (`better-sqlite3`) |
| 비밀번호 해시 | bcrypt |
| JWT 라이브러리 | `jsonwebtoken` |

---

## 아키텍처

레이어드 아키텍처(Layered Architecture)를 채택한다.  
각 계층은 단일 책임을 가지며, 인접한 계층과만 통신한다.

```
클라이언트 → Router → Controller → Service → Repository → SQLite
```

### 계층 역할

| 계층 | 파일 | 역할 |
|------|------|------|
| Router | `routes/auth.routes.js` | URL 경로 정의, 미들웨어 연결 |
| Controller | `controllers/auth.controller.js` | HTTP 요청 파싱, 응답 직렬화 |
| Service | `services/auth.service.js` | 비즈니스 로직 (회원가입/로그인 처리) |
| Repository | `repositories/user.repository.js` | DB 쿼리 추상화 |
| Middleware | `middlewares/authenticate.js` | JWT 검증, `req.user` 주입 |
| Utils | `utils/jwt.js`, `utils/hash.js` | 토큰 서명/검증, bcrypt 래퍼 |

---

## 파일 구조

```
src/
├── app.js
├── db.js
├── routes/
│   └── auth.routes.js
├── controllers/
│   └── auth.controller.js
├── services/
│   └── auth.service.js
├── repositories/
│   └── user.repository.js
├── middlewares/
│   └── authenticate.js
└── utils/
    ├── jwt.js
    └── hash.js
```

---

## 데이터 모델

### `users` 테이블

```sql
CREATE TABLE IF NOT EXISTS users (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  email      TEXT    UNIQUE NOT NULL,
  password   TEXT    NOT NULL,
  created_at TEXT    DEFAULT (datetime('now'))
);
```

---

## API 엔드포인트

### POST `/api/auth/register` — 회원가입

**요청:**
```json
{ "email": "user@example.com", "password": "mypassword" }
```

**성공 응답 (201):**
```json
{ "id": 1, "email": "user@example.com" }
```

**유효성 검사:**
- `email`: 비어 있지 않아야 하며 유효한 이메일 형식이어야 함
- `password`: 최소 8자 이상

**에러 응답:**
- `400` — 필드 누락, 이메일 형식 오류, 비밀번호 8자 미만
- `409` — 이미 존재하는 이메일

---

### POST `/api/auth/login` — 로그인

**요청:**
```json
{ "email": "user@example.com", "password": "mypassword" }
```

**성공 응답 (200):**
```json
{ "token": "<JWT>" }
```

**에러 응답:**
- `400` — 필드 누락
- `401` — 이메일 또는 비밀번호 불일치

---

### GET `/api/auth/me` — 내 정보 조회 (인증 필요)

**헤더:** `Authorization: Bearer <token>`

**성공 응답 (200):**
```json
{ "id": 1, "email": "user@example.com", "created_at": "..." }
```

**에러 응답:**
- `401` — 토큰 없음 또는 유효하지 않은 토큰

---

## JWT 명세

| 항목 | 값 |
|------|----|
| 알고리즘 | HS256 |
| 만료 | 1시간 (`1h`) |
| 페이로드 | `{ sub: userId, email }` |
| 비밀키 | 환경 변수 `JWT_SECRET` |

---

## 에러 처리

- 컨트롤러에서 try/catch로 에러를 잡아 Express `next(err)`에 전달
- `app.js`에 전역 에러 핸들러 미들웨어 등록 (시그니처: `(err, req, res, next)`)
- 응답 형식: `{ "error": "<메시지>" }`
- 스택 트레이스는 프로덕션 환경에서 노출 금지 (`NODE_ENV` 기반 분기)

---

## 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `PORT` | 서버 포트 | `3000` |
| `JWT_SECRET` | JWT 서명 비밀키 | 없음 (필수, 미설정 시 서버 시작 즉시 종료) |
| `DB_PATH` | SQLite 파일 경로 | `./data/app.db` |

---

## 테스트 전략

- 서비스 계층 단위 테스트: repository를 목(mock)으로 대체
- 통합 테스트: `supertest`로 실제 Express 앱에 HTTP 요청
- 테스트 DB: 인메모리 SQLite (`:memory:`) 사용

---

## 스코프 외

- Refresh Token
- 이메일 인증
- 비밀번호 재설정
- OAuth / 소셜 로그인
- Rate limiting
