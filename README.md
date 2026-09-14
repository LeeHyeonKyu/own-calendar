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

Prerequisite: 서버는 직접 만들어야 하는 `server/.env` 설정 파일을 읽는다 — 채울 변수 이름은 [server/.env.example](server/.env.example)을 복사해서 쓰고, 배경은 [docs/TECHNICAL.md](docs/TECHNICAL.md)를 본다.

DB 접속 문자열은 `server/docker-compose.yml`이 컨테이너에 주입하므로 `server/.env.example`에는 없다 — 도커 없이 `npm run dev`로 띄우려면 같은 값을 직접 `server/.env`에 넣어야 한다.

Server (Node.js + TypeScript, PostgreSQL 필요):

```bash
cd server && npm ci && npm run db:generate && npm run db:migrate && npm run dev
```

`npm run db:generate`는 `server/src`가 import하는 Prisma 클라이언트를 만들고, `npm run db:migrate`는
`server/prisma/migrations/`의 스키마를 빈 DB에 적용한다. 둘 중 하나라도 건너뛰면 서버 프로세스는 뜨지만
첫 요청부터 "테이블이 없다"로 실패한다.

Client (Flutter) — 위에서 띄운 로컬 서버를 보게 하려면 `config/dev.json`을 넘긴다:

```bash
cd client && flutter pub get && flutter run --dart-define-from-file=config/dev.json
```

이 플래그를 빼면 클라이언트는 코드에 박힌 기본값, 즉 **운영 서버**에 붙는다 — 방금 띄운 로컬 서버는 놀고
가입·일정 추가가 실제 가족 데이터에 쓰인다. 운영 서버를 향하게 하려면 `config/prod.json`을 명시해서 쓴다.

배포는 직접 하지 말고 `scripts/deploy.sh` 파이프라인을 쓴다 (`CLAUDE.md` 참고).

## Test

Client:

```bash
cd client && flutter test
```

Server — 아래 명령을 복사하기 전에 이 두 문단을 먼저 읽는다.

스키마: 전용 테스트 DB도 빈 상태로는 스위트를 돌릴 수 없다 — `server/.env`를 그 DB로 맞춘 뒤
`cd server && npm run db:generate && npm run db:migrate`을 한 번 실행해 스키마를 만들고 나서
아래 명령을 돌린다.

주의: `cd server && npm test`는 `server/.env`가 가리키는 database의 모든 행을 **삭제**한다 —
`server/tests/setup.ts`가 전역 `beforeEach`에서 사용자·가족·캘린더·일정·토큰 테이블을 비우고,
실제 캘린더 데이터가 들어 있는 곳을 가리킨 채로 실행하면 되돌릴 수 없다.
실행 중인 PostgreSQL이 필요하며, 반드시 버려도 되는 전용 테스트 DB를 가리키게 한 뒤에 실행한다.

```bash
cd server && npm test
```

## Docs

- [docs/PROJECT.md](docs/PROJECT.md) — 제품 정의, 원칙, 기능 레지스트리
- [docs/TECHNICAL.md](docs/TECHNICAL.md) — 스택, 아키텍처, 데이터, 제약
- [docs/features/](docs/features/) — 기능별 스펙 (`NNN.md`)
- [docs/factory/CHARTER.md](docs/factory/CHARTER.md) — 자동화 에이전트 운영 헌장
