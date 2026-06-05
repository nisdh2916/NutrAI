# 아키텍처 개선 진행 현황

마지막 업데이트: 2026-05-04

## 완료

### ✅ 1. 알레르기 감지 모듈 통합
- `app/lib/utils/allergy_checker.dart` 생성 — 정규 키워드 맵 + `detectAllergens()` 단일 구현
- `ai_chat_screen.dart`: 로컬 `_allergenKeywords` / `_detectAllergens` 제거 → import 교체
- `food_add_screen.dart`: 동일 교체
- `rag_pipeline.py`: 누락 키워드 동기화 (떡볶이, 스크램블, 순두부, 콩 추가)

### ✅ 끼니 5종 확장 (간식·야식 추가)
- `app_theme.dart`: `snack`, `lateNight` 색상 추가
- `db_models.dart`: `야식 ↔ late_night` 매핑 추가
- `food_add_screen.dart`: 끼니 칩 UI 가로 스크롤로 교체
- `main_tab_screen.dart`: 시간 자동 분류 로직 5종으로 확장

### ✅ 채팅 히스토리 저장 (30일)
- `database_helper.dart`: `chat_message` 테이블 추가 (DB v3)
- `repositories/chat_repository.dart` 신규 생성
- `ai_chat_screen.dart`: 앱 재시작 시 이전 대화 복원, 초기화 버튼 추가

### ✅ AI 채팅 버그 3건 수정
- 타이핑 인디케이터 말풍선 겹침 수정
- `_nonFoodLabels`에 `음식명` 추가 (잘못된 하이퍼링크 방지)
- 레거시 `_FoodDetailSheet` 제거

### ✅ 2. ChatMessageParser 분리
- `app/lib/utils/chat_message_parser.dart` 생성 — `foodBoldPattern`, `listNumPattern`, `dashPattern`, `nonFoodLabels`, `isFoodName()`, `parseFoodInfo()` 순수 함수로 추출
- `ai_chat_screen.dart`: 로컬 패턴/레이블/메서드 제거 → `ChatMessageParser.*` import 교체

### ✅ 3. 도메인 모델 → `chat_models.dart` 이동
- `app/lib/models/chat_models.dart` 생성 — `RecommendMenuItem`, `RecommendResult`, `ExtractedProfile`, `FoodNutrition`, `ChatResponse` 5개 모델 이동
- `chat_service.dart`: 모델 정의 제거, `import`·`export` 추가

### ✅ 4. RAG 파이프라인 단계 분리
- `_preprocess_query()` 추출 — 남은 칼로리 계산 → 시간대 감지 → 다중 쿼리 재작성
- `_stream_ollama_raw()` 추출 — Ollama HTTP 스트리밍 + `<think>` 실시간 제거
- `stream_recommendation()`: 오케스트레이터로 단순화 (전처리 → 검색 → 생성 → 후처리 경고)

### ✅ 5. AppState → UserState / MealState 분리
- `app/lib/providers/user_state.dart` 신규 — 사용자 도메인 (load, save, clear)
- `app/lib/providers/meal_state.dart` 신규 — 끼니/음식 도메인 (loadToday, saveMeal, deleteMeal, 리포트 쿼리 등)
- `app_state.dart`: 파사드 ChangeNotifier로 축소 — 모든 공개 메서드는 두 상태 객체에 위임
