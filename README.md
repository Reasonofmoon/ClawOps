# OpenClaw CLI 어시스턴트 시스템

Telegram/Discord 없이, 로컬 CLI만으로 OpenClaw를 쉽게 쓰기 위한 운영 시스템입니다.

## 핵심 명령

```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl help
bash /Users/soundfury37gmail.com/openclaw/scripts/bot help
```

## 가장 쉬운 사용법 (추천)

1. 인터랙티브 메뉴 실행:
```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl menu
```
2. 번호 선택 후 요청 한 줄 입력
3. 결과는 자동으로 `/Users/soundfury37gmail.com/openclaw/outputs/*.md`에 저장

## 명령형 사용법

### 1) 자동 모드 추론 (`ask`)
요청 문장을 보고 `crawl/research/doc/content/code`를 자동 선택합니다.

```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl ask "오픈소스 RAG 프레임워크 비교해줘"
bash /Users/soundfury37gmail.com/openclaw/scripts/bot ask "오픈소스 RAG 프레임워크 비교해줘"
```

### 2) 모드 지정 실행 (`run`)
모드를 직접 지정합니다.

```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl run code "현재 저장소 테스트 깨지는 원인 찾고 수정해줘"
```

### 3) 프리셋 실행 (`quick`)
자주 쓰는 작업을 템플릿으로 실행합니다.

프리셋 목록:
```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl presets
```

프리셋 실행:
```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl quick bugfix
```

### 4) 파일로 저장
```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl ask "시장 조사해줘" --out /Users/soundfury37gmail.com/openclaw/outputs/research.md
```

## 현재 시스템 구조

- `/Users/soundfury37gmail.com/openclaw/scripts/assistantctl`: 메인 컨트롤러
- `/Users/soundfury37gmail.com/openclaw/prompts/core.md`: 공통 운영 프롬프트
- `/Users/soundfury37gmail.com/openclaw/prompts/crawl.md`: 크롤링
- `/Users/soundfury37gmail.com/openclaw/prompts/research.md`: 리서치
- `/Users/soundfury37gmail.com/openclaw/prompts/doc.md`: 문서
- `/Users/soundfury37gmail.com/openclaw/prompts/content.md`: 콘텐츠
- `/Users/soundfury37gmail.com/openclaw/prompts/code.md`: 스마트 코딩
- `/Users/soundfury37gmail.com/openclaw/presets/default.tsv`: 프리셋 작업 목록

## 첫 세팅 체크

```bash
bash /Users/soundfury37gmail.com/openclaw/scripts/assistantctl check
```

권장 상태:
- 모델 제공자 인증 완료 (`openclaw configure`)
- `tools.web.fetch.enabled=true`
- 리서치 강화 시 `tools.web.search.enabled=true` + Brave API 키
