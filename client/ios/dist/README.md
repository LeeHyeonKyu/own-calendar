# iOS 위젯 설치 가이드

Own Calendar iOS 앱 + 홈 화면 위젯을 iPhone에 설치하는 방법.

## 필요한 것

- Mac (iMac, MacBook 등)
- iPhone (USB 케이블 — 초기 1회만)
- Apple ID (무료 계정 OK)

## 파일 설명

| 파일 | 용도 |
|------|------|
| `OwnCalendar.ipa` | Own Calendar 앱 + 위젯 |
| `SideStore.ipa` | 앱 자동 갱신 도구 (선택) |

---

## 방법 1: AltStore (추천)

집 Wi-Fi에서 Mac이 켜져있으면 7일마다 자동 갱신됩니다.

### 초기 설정 (1회)

#### 1. Mac에서 AltServer 설치
- https://altstore.io 에서 AltServer for Mac 다운로드
- 실행하면 메뉴바에 ◇ 아이콘 생김

#### 2. iPhone에 AltStore 설치
- iPhone을 USB로 Mac에 연결
- 메뉴바 ◇ 아이콘 → "Install AltStore" → iPhone 선택
- Apple ID 로그인
- iPhone에서: 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 **신뢰**

#### 3. Own Calendar 설치
- `OwnCalendar.ipa` 파일을 iPhone으로 AirDrop
- iPhone에서 받은 파일 → **AltStore로 열기**
- 또는: AltStore 앱 → My Apps → **+** → 파일 선택

#### 4. 위젯 추가
- 홈 화면 길게 꾹 → 좌측 상단 **+** 
- "Own Calendar" 검색
- 원하는 크기(Small/Medium/Large) 선택 → 추가

### 이후 사용

- **같은 Wi-Fi에 있으면** AltStore가 백그라운드에서 자동 갱신 (7일마다)
- USB 연결 불필요
- 갱신 확인: AltStore 앱 → My Apps → "Expires in X DAYS" 확인

### 수동 갱신 (필요 시)

AltStore 앱 → My Apps → **Refresh All**
(Mac에서 AltServer가 실행 중이어야 함)

---

## 방법 2: SideStore (Mac 없이 갱신)

Mac 없이 iPhone 혼자서 앱을 갱신할 수 있습니다. 장기 여행 시 유용.

### 추가 설정

#### 1. JitterbugPair로 pairing file 생성
- https://github.com/osy/Jitterbug/releases 에서 macOS용 다운로드
- iPhone USB 연결 + 잠금 해제 상태에서:
  ```
  chmod +x jitterbugpair && ./jitterbugpair
  ```
- 보안 차단 시: `xattr -d com.apple.quarantine jitterbugpair`
- `*.mobiledevicepairing` 파일 생성됨

#### 2. SideStore 설치
- AltStore에서 `SideStore.ipa`를 설치 (AirDrop → AltStore로 열기)
- iPhone에서: 설정 → 기기 관리 → SideStore 신뢰

#### 3. Pairing file 등록
- `.mobiledevicepairing` 파일을 iPhone으로 AirDrop
- SideStore로 열기

#### 4. Own Calendar을 SideStore로 관리
- SideStore → My Apps → + → `OwnCalendar.ipa`
- 이후 SideStore가 자동 갱신 (Mac 불필요)

---

## 가족 iPhone에 설치하기

1. 가족 iPhone을 **1회만 USB로 Mac에 연결**
2. AltServer로 AltStore 설치
3. `OwnCalendar.ipa`를 **AirDrop**으로 전송
4. AltStore에서 설치
5. 같은 Wi-Fi에서 자동 갱신

**IPA 파일은 기종 무관** — 같은 파일로 모든 iPhone에 설치 가능.

---

## 앱 업데이트 (코드 변경 시)

### IPA 재빌드
```bash
cd client/ios && pod install
cd .. && flutter build ios --release
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa && zip -r OwnCalendar.ipa Payload/
```

### 배포
- 새 `OwnCalendar.ipa`를 각 iPhone으로 AirDrop
- AltStore/SideStore에서 재설치 (기존 데이터 유지)

---

## 주의사항

- **무료 Apple ID**: 앱이 7일 후 만료됩니다. AltStore/SideStore가 자동 갱신해줍니다.
- **Apple Developer Program ($99/년)**: 만료 없음 + TestFlight로 간편 배포. 가족 전원 배포 시 추천.
- **서버 코드만 변경**: IPA 재빌드 불필요 (서버 hot-reload).
- **위젯 데이터**: 앱을 한 번 실행해야 위젯에 일정이 표시됩니다.

---

## 트러블슈팅

| 증상 | 해결 |
|------|------|
| "Untrusted Developer" | 설정 → 일반 → VPN 및 기기 관리 → 신뢰 |
| 위젯에 일정 안 보임 | 앱 실행 → 로그인 → 일정 로드 후 위젯 갱신 |
| AltStore에서 앱 안 보임 | AltStore 재시작, AirDrop으로 IPA 재전송 |
| 만료됨 (앱 실행 불가) | AltStore → Refresh All (Mac + 같은 Wi-Fi 필요) |
