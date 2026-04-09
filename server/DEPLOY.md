# 배포 체크리스트

`hk-imac`에 Tailscale Funnel로 올리는 일회성 세팅 메모. 상세 운영은 필요할 때 `docker compose` 커맨드로 직접 한다.

**URL:** `https://own-calendar.tailb2886a.ts.net` (API: `+/api`)

## Tailscale admin 콘솔 세팅 (한 번만)

1. **DNS** — MagicDNS ON, HTTPS Certificates ON
2. **Features** — Funnel Enabled
3. **Access Controls** — ACL JSON에 병합:
   ```json
   {
     "tagOwners": { "tag:funnel": ["<본인 이메일>"] },
     "nodeAttrs": [
       { "target": ["tag:funnel"], "attr": ["funnel"] }
     ]
   }
   ```
4. **Settings > Keys** — Auth key 발급 (Reusable ON, Ephemeral OFF, **Tags: tag:funnel**)

## hk-imac에서

```bash
# clone
git clone <origin-url> ~/own-calendar
cd ~/own-calendar/server

# env
cp .env.example .env
# TS_AUTHKEY, POSTGRES_PASSWORD, JWT_SECRET, GOOGLE_*, 편집
# 강한 랜덤값: openssl rand -base64 24 / openssl rand -hex 48

mkdir -p ~/own-calendar-data/pgdata

# 기동
docker compose up -d --build
docker compose logs -f tailscale  # own-calendar 노드 등록 확인
```

## Google OAuth

Google Cloud Console > OAuth 2.0 Client IDs > Authorized redirect URIs:
- `https://own-calendar.tailb2886a.ts.net/api/google/callback`

## 검증

tailnet 밖에서 (셀룰러/다른 네트워크):
```bash
curl -i https://own-calendar.tailb2886a.ts.net/health
nc -zv own-calendar.tailb2886a.ts.net 5432   # refused 가 정상 (postgres 외부 노출 X)
```

## Flutter 클라이언트

```bash
cd client
flutter run --dart-define-from-file=config/prod.json
flutter build ios --dart-define-from-file=config/prod.json
```

default baseUrl이 이미 Funnel URL이라 `--dart-define` 빼먹어도 동작한다.

## 알려진 한계

- **Google OAuth `state`가 단순 userId** (`routes/google.ts`) — 공격자가 임의 userId를 state로 넣어 본인 Google 계정을 피해자 계정에 연결할 수 있는 이론적 약점. 후속 작업으로 nonce + signed state 도입 권장.
