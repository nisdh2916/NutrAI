# NutrAI 트러블슈팅 기록

---

## 1. LLM 응답이 빈 문자열로 반환되는 문제

**증상:** 채팅 또는 추천 요청 시 응답이 아예 안 나오거나 빈 값 반환

**원인:** `OllamaLLM` (generate API) 사용. gemma-4-IT, qwen3 같은 instruct 모델은 chat API를 써야 함. generate API는 응답을 `response.text`로 반환하는데, IT 모델은 이 필드가 비어 있음.

**해결:**
```python
# 변경 전
from langchain_ollama import OllamaLLM
llm = OllamaLLM(model=LLM_MODEL)
raw = llm.invoke(prompt)

# 변경 후
from langchain_ollama import ChatOllama
llm = ChatOllama(model=LLM_MODEL, think=False, keep_alive="1h")
response = llm.invoke([SystemMessage(...), HumanMessage(...)])
raw = response.content
```

**관련 파일:** `ai/rag_engine/rag_pipeline.py`, `server/api/routes_recommend.py`

---

## 2. 스트리밍 응답 chunk.content가 전부 빈 문자열

**증상:** `/chat/stream` 엔드포인트에서 `data: {"chunk": ""}` 만 계속 옴

**원인:** LangChain `ChatOllama.stream()` 이 qwen3:8b 스트리밍 시 `chunk.content`를 올바르게 매핑하지 못함. thinking 토큰과 실제 응답 토큰 구분 문제.

**해결:** LangChain 우회, Ollama HTTP API 직접 호출로 교체
```python
import requests, json as _json

payload = {
    "model": LLM_MODEL,
    "stream": True,
    "think": False,
    "options": {"temperature": 0.3, "num_predict": 2048},
    "messages": [...],
}
with requests.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload, stream=True) as r:
    for line in r.iter_lines():
        if line:
            data = _json.loads(line)
            text = data.get("message", {}).get("content", "")
            if text:
                yield text
```

**관련 파일:** `ai/rag_engine/rag_pipeline.py` → `stream_recommendation()`

---

## 3. 응답이 중간에 뚝 끊기는 문제

**증상:** "나트륨(1" 처럼 문장 중간에서 잘림

**원인:** `num_predict: 1024` 토큰 한도 초과. 한국어는 글자당 약 1.5토큰이라 500자 응답도 750토큰에 달함.

**해결:**
```python
# rag_pipeline.py _get_llm()
num_predict=2048

# stream_recommendation() payload
"options": {"temperature": 0.3, "num_predict": 2048}
```

**관련 파일:** `ai/rag_engine/rag_pipeline.py`

---

## 4. 추천 엔드포인트 JSON 파싱 실패 (500 에러)

**증상:** `/recommend` 500 Internal Server Error, `ValueError: JSON not found in response`

**원인:** LLM이 JSON 외에 설명 텍스트를 함께 출력하거나, think 토큰이 섞여 JSON 파싱 실패.

**해결:** Ollama `format: "json"` 강제 + 재시도 로직 추가
```python
payload = {
    "model": LLM_MODEL,
    "format": "json",   # JSON만 출력하도록 강제
    "stream": False,
    "think": False,
    ...
}
# 파싱 실패 시 최대 2회 재시도
for attempt in range(retries + 1):
    raw = call_ollama(payload)
    try:
        _extract_json(raw)
        return raw
    except (ValueError, JSONDecodeError):
        if attempt == retries:
            raise
```

**관련 파일:** `server/api/routes_recommend.py` → `_call_ollama_json()`

---

## 5. 추천 결과에 브랜드명/가공식품이 나오는 문제

**증상:** "고고단 다이어트 단백질 쉐이크", "CJ 비비고 김치찌개 1인분 (냉동)" 같은 제품명 추천

**원인:** ChromaDB에 가공식품 DB가 포함되어 있고, LLM이 RAG 검색 결과를 그대로 메뉴명으로 사용.

**해결:** 프롬프트에 명시적 금지 규칙 추가
```python
SYSTEM_PROMPT = """...
메뉴명은 반드시 일반 음식명(김치찌개, 된장찌개 등)만 사용하고
브랜드명·제품명·가공식품은 절대 사용하지 마세요.
아래 영양 정보는 칼로리·영양소 참고용으로만 사용하세요.
..."""
```

**관련 파일:** `ai/rag_engine/rag_pipeline.py`, `server/api/routes_recommend.py`

---

## 6. 채팅 음식 팝업이 라벨 단어에도 트리거되는 문제

**증상:** "메뉴명", "칼로리", "추천 이유", "코칭 메시지" 등 굵은 라벨 텍스트를 눌러도 팝업 열림

**원인:** `isFood` 판별 조건이 "한글 2자 이상"만 체크해서 라벨 단어도 음식명으로 오인

```dart
// 기존 (너무 단순)
final isFood = RegExp(r'[가-힣]{2,}').hasMatch(boldText) && boldText.length <= 20;
```

**해결:** 라벨 단어 블랙리스트 추가
```dart
static const _nonFoodLabels = {
  '메뉴명', '칼로리', '추천 이유', '추천이유', '코칭 메시지', '코칭메시지',
  '추천', '성분', '영양', '식단', '이유', '메뉴', '기준',
};
final isFood = RegExp(r'[가-힣]{2,}').hasMatch(boldText)
    && boldText.length <= 20
    && !_nonFoodLabels.contains(boldText.trim());
```

**관련 파일:** `app/lib/screens/ai_chat_screen.dart` → `_RichBotText._buildRichLine()`

---

## 7. 음식 팝업이 추천한 메뉴와 다른 음식 정보를 보여주는 문제

**증상:** "김치찌개"를 누르면 "비비고 냉동 김치찌개 1인분" 같은 브랜드 제품 정보가 팝업에 표시됨

**원인:** 팝업이 `ChatService.searchFood(foodName)`로 ChromaDB를 유사도 검색 → DB는 가공식품 위주라 일반 음식명으로 검색하면 브랜드 제품이 가장 유사한 결과로 반환됨. LLM이 일반명으로 추천하면서 DB와 불일치 발생.

**해결:** DB 검색 제거, 채팅 메시지 텍스트에서 직접 kcal·추천이유 파싱
```dart
// 메시지에서 해당 음식의 정보 추출
static Map<String, String> _parseFoodInfo(String message, String foodName) {
  final lines = message.split('\n');
  for (int i = 0; i < lines.length; i++) {
    if (!lines[i].contains(foodName)) continue;
    for (int j = i; j < lines.length && j < i + 5; j++) {
      final kcalMatch = RegExp(r'칼로리[:\s]*(\d+)\s*kcal').firstMatch(lines[j]);
      if (kcalMatch != null) kcal = kcalMatch.group(1)!;
      // ... reason 파싱
    }
  }
}

// DB 검색 대신 파싱 결과로 팝업 표시
_showFoodPopup(context, foodName, fullMessage);
```

**관련 파일:** `app/lib/screens/ai_chat_screen.dart` → `_showFoodPopup()`, `_parseFoodInfo()`

---

## 8. Ollama Modelfile 경로 오류

**증상:** `Error: 400 Bad Request: invalid model name`

**원인:** Modelfile의 `FROM` 경로에 Unix 슬래시(`/`) 사용. Windows Ollama는 백슬래시(`\`) 필요.

**해결:**
```
# 잘못된 예
FROM C:/Users/user/.ollama/models/...

# 올바른 예
FROM C:\Users\user\.ollama\models\...
```

---

## 9. 포트 8000 좀비 프로세스

**증상:** 서버 재시작 시 `Address already in use: port 8000`

**원인:** Spyder IDE의 Python 프로세스가 이전 uvicorn 워커를 좀비로 유지

**해결:**
```powershell
# 점유 프로세스 확인 및 강제 종료
Get-NetTCPConnection -LocalPort 8000 -State Listen |
  Select-Object -ExpandProperty OwningProcess |
  ForEach-Object { Stop-Process -Id $_ -Force }
```

또는 `start.bat`에 자동 정리 로직 포함:
```bat
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000 " ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)
```

---

## 10. GitHub push 거부 (branch protection)

**증상:** `remote: error: GH006: Protected branch update failed`

**원인:** main 브랜치에 PR 없이 직접 push 금지 규칙 적용됨

**해결:** 별도 브랜치 생성 후 PR 경유
```bash
git checkout -b feature/branch-name
git push origin feature/branch-name
# GitHub에서 PR 생성 후 merge
```

---

## 11. Android 실기기에서 서버 연결 실패

**증상:** 에뮬레이터에서는 서버 통신이 되는데 실기기에서는 `Connection refused` 또는 응답 없음. 빌드 시 NDK 버전 호환 오류도 함께 발생.

**원인:** 
- 에뮬레이터용 주소 `10.0.2.2`는 실기기에서 사용 불가 (호스트 PC를 가리키는 에뮬레이터 전용 주소)
- `ndkVersion = flutter.ndkVersion`이 프로젝트에서 요구하는 NDK 버전과 불일치

**해결:**
```bash
# adb reverse로 PC 포트를 기기에 터널링
adb reverse tcp:8000 tcp:8000
```
```dart
// 변경 전 (chat_service.dart)
static const String _baseUrl = 'http://10.0.2.2:8000'; // Android 에뮬레이터

// 변경 후
static const String _baseUrl = 'http://127.0.0.1:8000'; // adb reverse 터널링
```
```kotlin
// 변경 전 (build.gradle.kts)
ndkVersion = flutter.ndkVersion

// 변경 후
ndkVersion = "27.0.12077973"
```

**관련 파일:** `app/lib/services/chat_service.dart`, `app/android/app/build.gradle.kts`

---

## 12. AppColors.green700 컴파일 에러

**증상:** Flutter 빌드 시 `Error: Getter not found: 'green700'` 컴파일 에러

**원인:** `AppColors`에 `green700`이 정의되어 있지 않음. `green600`까지만 존재하는데 잘못된 색상 코드 사용.

**해결:**
```dart
// 변경 전 (ai_chat_screen.dart)
color: AppColors.green700

// 변경 후
color: AppColors.green600
```

**관련 파일:** `app/lib/screens/ai_chat_screen.dart`

---

## 13. RAG 검색 품질 저하 및 알레르기 안전성 문제

**증상:** 추천 결과가 사용자 건강 조건과 무관하거나, 알레르기 식품이 추천에 포함됨. LLM이 `<think>` 태그를 응답에 남기거나 비현실적 칼로리(예: 5kcal)를 출력하는 경우가 있음.

**원인:**
1. `k=3` 고정으로 검색 후보가 너무 적고 유사도 임계값 없어 무관한 문서가 컨텍스트에 포함됨
2. 알레르기 필터가 프롬프트 텍스트에만 의존 → 검색 단계에서 알레르기 식품 문서가 그대로 전달됨
3. 쿼리에 자연어+건강조건+목표를 단순 연결하여 임베딩 희석
4. 검색 문서가 `|` 구분 원본 그대로 전달되어 LLM 이해도 낮음
5. `get_recommendation`과 `stream_recommendation`의 검색 로직 중복

**해결:**
```python
# 변경 전 (k=3, 단순 쿼리, 중복 코드)
search_query = f"{', '.join(detected_foods)} {user_query} {condition} {goal}"
results = collection.query(query_embeddings=[...], n_results=k)  # k=3
retrieved_docs = results["documents"][0]
context = "\n".join([doc.replace("|", ",") for doc in retrieved_docs])

# 변경 후 (공통 _retrieve() 함수로 통합)
# 1. 키워드 중심 짧은 쿼리
search_query = " ".join([*detected_foods[:3], condition, goal])

# 2. k*4 후보 → 유사도 임계값(L2 ≤ 1.0) → 알레르기 키워드 필터 → 상위 k개
results = collection.query(..., n_results=k * FETCH_MULTIPLIER, include=["documents","distances"])
filtered = [(doc, dist) for doc, dist in zip(docs, dists) if dist <= SIMILARITY_THRESHOLD and not _has_allergen(doc)]

# 3. 번호 목록 포맷
context = "\n".join(f"{i}. {doc.replace('|', ', ')}" for i, doc in enumerate(docs, 1))

# 4. post_process(): <think> 제거, 칼로리 경고, 알레르기 이중 확인
answer = post_process(llm_response, user_profile)
```

**관련 파일:** `ai/rag_engine/rag_pipeline.py` → `_retrieve()`, `post_process()`, `_strip_think_streaming()`

## 14. 리포트 화면에 샘플 데이터만 표시

**증상:** 리포트 탭(일/주/월)에서 실제 식단 기록과 무관하게 항상 같은 데모 데이터가 표시됨

**원인:** `report_screen.dart`의 모든 탭이 `MealSampleData.forDate(d)` (하드코딩 정적 데이터)를 사용하고, 실제 AppState DB와 연동되지 않음

**해결:**
```dart
// 변경 전 - 하드코딩 샘플
final meals = MealSampleData.forDate(selected);

// 변경 후 - DB 실데이터 (StatefulWidget + initState 로딩)
final data = await context.read<AppState>().getMealsForDate(date);
final meals = data.map(_toRecord).toList();
```

`_toRecord(MealWithFoods)` 변환 헬퍼로 DB 모델 → UI 모델 변환.
주간 탭은 `getWeeklyKcal()` + `Future.wait(7 getMealsForDate 호출)`,
월간 탭은 `getMonthlyKcal()` + 날짜 선택 시 `getMealsForDate()` 사용.

**관련 파일:** `app/lib/screens/report_screen.dart` → `_DailyTabState`, `_WeeklyTabState`, `_MonthlyTabState`

## 15. 설정 화면에서 알레르기·질환 편집 불가

**증상:** 온보딩에서 설정한 알레르기/질환을 나중에 변경할 방법이 없음. 설정 화면에 표시만 되고 편집 UI 없음

**원인:** `settings_screen.dart`에 건강 정보 표시 및 편집 UI 미구현

**해결:**
```dart
// 설정 화면에 건강 정보 섹션 추가
// 알레르기 11종 + 질환 7종 멀티셀렉트 바텀시트(_HealthEditSheet)
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _HealthEditSheet(
    initialAllergies: allergies,
    onSave: (a, c) => appState.saveUser(
      nickname: user.nickname,
      allergy: a.join(','),
      condition: c.join(','),
    ),
  ),
);
```

저장 시 `AppState.saveUser()`의 `copyWith` 로직으로 나머지 프로필 필드는 유지됨.

**관련 파일:** `app/lib/screens/settings_screen.dart` → `_editHealthInfo()`, `_HealthEditSheet`
