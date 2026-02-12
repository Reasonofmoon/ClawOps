# OpenClawControlApp (SwiftUI macOS)

OpenClaw CLI를 GUI로 조종하는 macOS SwiftUI 앱입니다.

## 기능

- 모드 선택 실행: auto/crawl/research/doc/content/code
- 프리셋 로딩 및 즉시 실행 (`$HOME/openclaw/presets/default.tsv`)
- 프로필 관리 (적용/현재값 저장)
- 스킬팩 관리 (적용/현재값 저장)
- 정책 관리 (Remote 허용, Preflight 강제, 요청 길이 제한)
- Preflight 점검 (명령/스크립트/경로/상태)
- 실패 시 런북 추천 표시
- 스킬 지시 체크박스 결합 실행
- 상태 체크 / 실행 / 중단 / 로그 보기
- 결과 파일 자동 저장 (`$HOME/openclaw/outputs`)

## 설정 파일

아래 JSON 파일을 수정하면 앱 동작 정책과 운영 구성을 바꿀 수 있습니다.

- `$HOME/openclaw/OpenClawControlApp/config/profiles.json`
- `$HOME/openclaw/OpenClawControlApp/config/skillpacks.json`
- `$HOME/openclaw/OpenClawControlApp/config/policy.json`
- `$HOME/openclaw/OpenClawControlApp/config/runbooks.json`

## 실행 방법

1. Xcode에서 `$HOME/openclaw/OpenClawControlApp/Package.swift` 열기
2. 실행 대상(target) `OpenClawControlApp` 선택
3. Scheme를 `Release`로 바꾼 뒤 Run (개발 중이 아니면 권장)

## 운영 권장 방식

- 실사용은 CLI(`scripts/bot`, `scripts/assistantctl`) 중심으로 운영
- 앱은 프로필/스킬팩/정책 설정과 실행 트리거 용도로 사용
- 긴 로그는 앱에서 자동으로 일부 생략(성능 보호)

## 로컬 CLI 의존성

앱은 내부적으로 다음 스크립트를 호출합니다.

- `$HOME/openclaw/scripts/bot`

따라서 OpenClaw와 bot 스크립트가 정상 동작해야 합니다.

## 참고

현재 Codex 실행 환경에서는 Swift 툴체인/권한 제한으로 `swift build` 검증이 제한될 수 있습니다.
실제 Mac 환경에서 Xcode Run으로 확인하는 방식이 가장 안정적입니다.
