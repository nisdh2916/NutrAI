# NutrAI 시스템 아키텍처

캡스톤 발표용 기술 문서. 데이터 흐름·알고리즘·핵심 의사결정 정리.

---

## 1. 전체 시스템 구조

```mermaid
flowchart LR
  subgraph App["Flutter 앱"]
    UI[화면<br/>홈/기록/리포트/추천/설정]
    State[AppState<br/>Provider]
    SQLite[(SQLite<br/>로컬 DB)]
    UI <--> State
    State <--> SQLite
  end

  subgraph Server["FastAPI 서버"]
    R1[/recommend/]
    R2[/detect/]
    R3[/chat/stream/]
    Pipeline[recommendation_pipeline<br/>전처리·검증]
  end

  subgraph AI["AI 엔진"]
    RAG[rag_pipeline<br/>다중 쿼리 RAG]
    Chroma[(ChromaDB<br/>식품·건강기능식품)]
    Ollama[Ollama<br/>Qwen3:8B]
    YOLO[YOLO<br/>음식 탐지]
  end

  State -- HTTP --> R1
  State -- HTTP --> R2
  State -- SSE --> R3
  R1 --> Pipeline --> RAG
  R2 --> YOLO
  R3 --> RAG
  RAG --> Chroma
  RAG --> Ollama
```

**계층 분리 원칙**
- Flutter는 로컬 SQLite를 truth source로 사용 → 오프라인에서도 식사 기록·리포트 동작
- 서버는 stateless. 추천/탐지 호출 시 사용자 프로필·식단 이력을 요청 본문으로 전달
- AI 엔진은 서버에 임베드(서비스 레이어). 외부 API 호출 없음 → 비용/프라이버시 이점

---

## 2. RAG 추천 파이프라인

`POST /api/recommend` 호출 시 실행되는 파이프라인. 핵심 파일: [server/services/recommendation_pipeline.py](../server/services/recommendation_pipeline.py), [ai/rag_engine/rag_pipeline.py](../ai/rag_engine/rag_pipeline.py).

```mermaid
flowchart TD
  Q[사용자 질문<br/>+ 프로필 + 식단 이력] --> P1[전처리]
  P1 --> P1a[의도/시간대 감지<br/>아침/점심/저녁/간식]
  P1 --> P1b[목표 정규화<br/>weight_loss/gain/maintenance]
  P1 --> P1c[제약 추출<br/>저염/저당/고단백/알레르기]
  P1 --> P1d[남은 칼로리 계산<br/>target - consumed]

  P1a & P1b & P1c & P1d --> P2[다중 쿼리 재작성<br/>최대 6개]

  P2 --> R1[ChromaDB 검색<br/>쿼리당 k×2]
  R1 --> R2[문서별 최고 유사도 보존]
  R2 --> R3[L2 임계값 1.0 필터]
  R3 --> R4[알레르기 키워드 제거]
  R4 --> R5[카테고리 다양성<br/>최대 2개/카테고리]

  R5 --> L[LLM 입력 구성]
  L --> L1["[사용자 정보]"]
  L --> L2["[식단 현황]"]
  L --> L3["[참고 영양 정보]"]
  L1 & L2 & L3 --> Ollama[Ollama Qwen3:8B<br/>스트리밍]

  Ollama --> Post[후처리]
  Post --> Po1["<think> 태그 제거"]
  Post --> Po2[칼로리 검증<br/>50-2000kcal & 남은량 120%]
  Post --> Po3[알레르기 최종 검증<br/>**음식명** 라인만]
  Po1 & Po2 & Po3 --> Out[최종 응답]
```

**왜 다중 쿼리인가?** 단일 쿼리는 사용자 질문(예: "점심 추천")만 검색해 목표·제약·이력을 무시함. 다중 쿼리(`체중 감량 점심 메뉴 추천` + `남은 칼로리 800kcal 이하 점심 식사` + `당뇨 맞춤 식단` 등)로 결과를 합치면 컨텍스트 적합도가 크게 올라감.

**왜 알레르기 이중 검증인가?**
1. 검색 단계에서 키워드 매칭으로 후보 제거 (`_has_allergen` in [rag_pipeline.py:258](../ai/rag_engine/rag_pipeline.py#L258))
2. LLM 응답 후처리에서 `**음식명**` 라인만 재검사 (`_build_allergen_warning` in [rag_pipeline.py:461](../ai/rag_engine/rag_pipeline.py#L461))

LLM이 컨텍스트를 무시하고 환각을 일으켜도 사용자 화면에는 경고 배너가 추가됨. 코칭 메시지에서 알레르기를 *언급*하는 것은 정상이므로 음식명 라인만 검사함.

---

## 3. 알레르기 경고 흐름 (앱 측)

`food_add_screen.dart`에서 사진 분석/검색 결과에 알레르기 매칭. 핵심 파일: [app/lib/screens/food_add_screen.dart](../app/lib/screens/food_add_screen.dart).

```mermaid
flowchart LR
  A[사진 촬영/검색] --> B[YOLO 탐지<br/>음식명 리스트]
  B --> C[_detectAllergens]
  Profile[(UserProfile.allergy<br/>예: '유제품,견과류')] --> C
  Map[알레르겐→키워드 맵<br/>유제품→우유,치즈...] --> C
  C --> D{매칭?}
  D -- 있음 --> E[빨간 배너<br/>+ 뱃지 표시]
  D -- 없음 --> F[일반 표시]
```

**3-tier 검증 (서버 측과 합치면)**
| 단계 | 위치 | 역할 |
|---|---|---|
| 1. RAG 검색 필터 | `_retrieve_multi` | 알레르기 음식이 LLM에 안 들어가게 |
| 2. LLM 응답 검증 | `_build_allergen_warning` | LLM 환각 방지 |
| 3. 앱 표시 검증 | `_detectAllergens` | 사용자가 직접 등록할 때 경고 |

---

## 4. 일/주/월 리포트 데이터 흐름

핵심 파일: [app/lib/screens/report_screen.dart](../app/lib/screens/report_screen.dart), [app/lib/repositories/meal_repository.dart](../app/lib/repositories/meal_repository.dart).

```mermaid
flowchart TD
  Tab{탭 선택} --> Daily[일간]
  Tab --> Weekly[주간]
  Tab --> Monthly[월간]

  Daily --> Q1["AppState.getMealsForDate(date)"]
  Q1 --> SQL1["SELECT meal JOIN meal_food JOIN food<br/>WHERE eaten_at BETWEEN ?"]
  SQL1 --> M1[MealWithFoods 리스트]
  M1 --> R1[_toRecord 변환] --> View1[그래프 + 끼니별 카드]

  Weekly --> Q2["AppState.getWeeklyKcal(startOfWeek)"]
  Q2 --> SQL2["SELECT date, SUM(kcal)<br/>GROUP BY date"]
  SQL2 --> M2[Map&lt;date, kcal&gt;]
  M2 --> Avg[탄/단/지 평균 계산]
  Avg --> Tip[_WeeklyTipCard<br/>패턴 기반 인사이트]

  Monthly --> Q3["AppState.getMonthlyKcal(year, month)"]
  Q3 --> M3[일별 칼로리 맵]
  M3 --> Best[베스트 데이 추출]
  Best --> Insight[_MonthlyInsightCard<br/>월 평균 평가]
```

**왜 인사이트를 클라이언트에서 계산하나?** LLM 호출 없이도 즉시 표시 가능. 영양소 평균·베스트 데이는 결정론적 규칙(평균 ± 표준편차, 칼로리 ≤ 목표)이라 ML이 불필요.

---

## 5. 데이터 모델 (SQLite)

```mermaid
erDiagram
  user_profile ||--o{ meal : "1:N"
  meal ||--o{ meal_food : "1:N"
  food ||--o{ meal_food : "1:N"

  user_profile {
    int id PK
    string nickname
    int age
    real height_cm
    real weight_kg
    real target_kcal
    string goal "다이어트/근육증가/유지"
    string allergy "쉼표 구분"
    string condition "쉼표 구분"
  }
  meal {
    int id PK
    int user_id FK
    string meal_type "breakfast/lunch/dinner/snack"
    string eaten_at "ISO8601"
    string photo_path
    string memo
  }
  food {
    int id PK
    string food_name
    real kcal
    real carb_g
    real protein_g
    real fat_g
  }
  meal_food {
    int id PK
    int meal_id FK
    int food_id FK
    real serving_count
    real amount_g
  }
```

**정규화 결정**
- `food`를 별도 테이블로 분리 → 동일 음식 재사용, 식품 DB 마스터 데이터로 활용
- `meal_food.serving_count`로 양 표현 → 영양소 = food 값 × serving_count (`MealFoodJoin.totalKcal` 등)

---

## 6. 핵심 의사결정 요약

| 항목 | 선택 | 이유 |
|---|---|---|
| 임베딩 모델 | KR-SBERT (snunlp) | 한국어 음식명/영양 텍스트에 특화 |
| LLM | Qwen3:8B (Ollama) | 로컬 추론 → 비용 0, 프라이버시, 한국어 양호 |
| 벡터 DB | ChromaDB | 로컬 파일 기반, 서버 추가 인프라 불필요 |
| 클라이언트 DB | SQLite | 오프라인 동작, 식단 기록은 동기화 비필수 |
| 알레르기 검증 | 3중 (검색·응답·앱) | LLM 환각 방어 + 사용자 직접 입력 보호 |
| 추천 쿼리 | 다중 (최대 6개) | 단일 쿼리는 컨텍스트 부족 |
| 후처리 | think 제거·칼로리·알레르기 | Qwen3 CoT 잔여물 + 안전성 |
