# NutrAI 아키텍처 개선 후보

`/improve-codebase-architecture` 세션에서 도출된 심화 기회 목록.

---

## 1. 알레르기 감지 모듈 삼중 복제 ✅ 완료

**파일:** `ai_chat_screen.dart`, `food_add_screen.dart`, `rag_pipeline.py`

**문제:** `_allergenKeywords` 맵과 `_detectAllergens()` 로직이 3곳에서 독립적으로 구현. 키워드 목록도 각각 달라 불일치 위험.

**해결:** `app/lib/utils/allergy_checker.dart` 단일 모듈 생성. Flutter 2곳은 import로 교체, Python 키워드 맵 동기화.

**효과:** 키워드 추가 시 1곳만 수정. 테스트 대상 명확.

---

## 2. ai_chat_screen의 파싱/포맷팅 로직

**파일:** `app/lib/screens/ai_chat_screen.dart` (790줄)

**문제:** `_parseFoodInfo()`, `_RichBotText`, `_nonFoodLabels` 등 비즈니스 로직이 UI 계층에 묻혀 있음. 화면 없이는 테스트 불가.

**해결:** `ChatMessageParser` 클래스 분리 (`_parseFoodInfo`, 볼드 텍스트→음식 이름 판별, `_nonFoodLabels` 포함).

**효과:** 순수 함수로 단위 테스트 가능. 화면은 표시만 담당.

---

## 3. ChatService 내 도메인 모델 정의

**파일:** `app/lib/services/chat_service.dart` (337줄)

**문제:** `RecommendMenuItem`, `FoodNutrition`, `ChatResponse` 등 5개 모델이 HTTP 통신 계층 안에 정의. 다른 화면에서 이 모델을 쓰려면 `chat_service.dart`를 import해야 함.

**해결:** 모델을 `app/lib/models/chat_models.dart`로 이동. `ChatService`는 통신만 담당.

**효과:** 모델 위치 명확. 통신과 모델의 결합 해소.

---

## 4. RAG 파이프라인의 stream_recommendation()

**파일:** `ai/rag_engine/rag_pipeline.py` (`stream_recommendation`: 85줄)

**문제:** 쿼리 재작성 → 검색 → LLM 호출 → 스트리밍 → 후처리를 한 함수가 모두 처리. 중간 단계를 독립적으로 테스트하거나 교체 불가.

**해결:** retrieve, rerank, generate를 독립 함수로 분리. `stream_recommendation`은 조합 오케스트레이터만 담당.

**효과:** 각 단계 단위 테스트 가능. LLM 교체 시 retrieve 로직 불변.

---

## 5. AppState의 과부하

**파일:** `app/lib/providers/app_state.dart` (220줄)

**문제:** 사용자·끼니·음식·집계·초기화 등 모든 도메인 연산이 하나의 ChangeNotifier에 집중. 어떤 값이 `notifyListeners`를 트리거하는지 추적 어려움.

**해결:** 도메인별 `UserState`, `MealState`로 분리. `AppState`는 facade만.

**효과:** 리빌드 범위 축소. 각 상태 독립 테스트 가능.
