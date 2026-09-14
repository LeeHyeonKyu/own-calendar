# own-calendar

## What

가족이 함께 쓰는 셀프호스팅 캘린더 허브. Flutter 클라이언트(iOS · Android · macOS · Web)와
Node.js(TypeScript) + PostgreSQL API 서버로 이루어져 있으며, 구글/네이버 등 외부 캘린더를
가져와 한 곳에서 보고 가족과 공유한다. 데이터는 외부 서비스가 아니라 우리가 운영하는 DB에
남는다. 제품 정의는 [docs/PROJECT.md](docs/PROJECT.md), 기술 결정은
[docs/TECHNICAL.md](docs/TECHNICAL.md)에 있다.

## Layout

| Path | What lives there |
|------|------------------|
| `client/` | Flutter 앱 (`lib/` 화면·프로바이더·서비스, `test/` 위젯/유닛 테스트) |
| `server/` | Node.js + TypeScript API 서버 (`src/` 라우트·서비스, `prisma/` 스키마와 마이그레이션, `tests/` vitest 스위트) |
| `altstore/` | AltStore 소스 매니페스트 (`apps.json`) — iOS 사이드로드 배포용 |
| `scripts/` | 운영 스크립트 — 배포(`deploy.sh`), DB 백업/복구, 클라우드 이전 |
| `docs/` | 프로젝트·기술 문서, 기능 스펙(`features/`), QA 체크리스트, factory 문서 |

## Run

Prerequisite: 서버는 직접 만들어야 하는 `server/.env` 설정 파일을 읽는다 — 필요한 변수 목록은 [docs/TECHNICAL.md](docs/TECHNICAL.md)를 본다.

Client (Flutter):

```bash
cd client && flutter pub get && flutter run
```

Server (Node.js + TypeScript, PostgreSQL 필요):

```bash
cd server && npm ci && npm run dev
```

배포는 직접 하지 말고 `scripts/deploy.sh` 파이프라인을 쓴다 (`CLAUDE.md` 참고).

## Test

Client:

```bash
cd client && flutter test
```

Server:

```bash
cd server && npm test
```

주의: `cd server && npm test`는 `server/.env`가 가리키는 database의 모든 행을 **삭제**한다.
(`server/tests/setup.ts`가 전역 `beforeEach`에서 전체 테이블을 비운다.) 실행 중인 PostgreSQL이
필요하며, 반드시 버려도 되는 전용 테스트 DB를 가리키게 한 뒤에 실행한다 — 실제 캘린더 데이터가
들어 있는 곳을 가리킨 채로 실행하면 되돌릴 수 없다.

## Docs

- [docs/PROJECT.md](docs/PROJECT.md) — 제품 정의, 원칙, 기능 레지스트리
- [docs/TECHNICAL.md](docs/TECHNICAL.md) — 스택, 아키텍처, 데이터, 제약
- [docs/features/](docs/features/) — 기능별 스펙 (`NNN.md`)
- [docs/factory/CHARTER.md](docs/factory/CHARTER.md) — 자동화 에이전트 운영 헌장
