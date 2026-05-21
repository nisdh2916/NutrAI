# NutrAI 작업 진행 상황

마지막 업데이트: 2026-04-29

---

## 현재 브랜치: `feat/allergy-warning-and-features`

---

## 완료된 작업

### ✅ 1. 리포트 화면 실제 DB 연동
- **파일:** `app/lib/screens/report_screen.dart`
- **내용:** `MealSampleData` 하드코딩 → `AppState` DB 쿼리로 전면 교체
  - `_DailyTab`, `_WeeklyTab`, `_MonthlyTab` 모두 `StatefulWidget`으로 변환
  - `initState` + `didUpdateWidget`에서 `getMealsForDate()` / `getWeeklyKcal()` / `getMonthlyKcal()` 호출
  - `_toRecord()` 헬퍼로 `MealWithFoods` → `MealRecord` 변환
  - `.withOpacity()` deprecation → `.withValues(alpha: ...)` 수정
- **트러블슈팅:** `docs/troubleshooting.md` 14번 항목 추가

### ✅ 2. 설정 화면 알레르기/건강 정보 편집 UI
- **파일:** `app/lib/screens/settings_screen.dart`
- **내용:** 알레르기·질환 설정 UI 추가
  - 11개 알레르겐 (`유제품`, `견과류`, `갑각류` 등) 멀티셀렉트 칩
  - 7개 질환 (`당뇨`, `고혈압`, `고지혈증` 등) 멀티셀렉트 칩
  - `DraggableScrollableSheet` 바텀시트로 편집
  - 저장 시 `AppState.saveUser()` 호출 → DB 반영
- **트러블슈팅:** `docs/troubleshooting.md` 15번 항목 추가

### ✅ 3. RAG 파이프라인 개선 (이전 세션)
- 문서 기반 RAG 전면 개선 (커밋 `5a2fd34`)
- RAG 품질 개선 및 포스트 프로세싱 추가 (커밋 `1a6649a`)
- 건강기능식품 DB 추가 스크립트 (`ai/scripts/add_health_supplement_db.py`)

### ✅ 4. Claude Code 자동 승인 모드 설정
- **프로젝트:** `.claude/settings.json` → `"defaultMode": "auto"` 추가
- **글로벌:** `C:/Users/user/.claude/settings.json` → `"defaultMode": "auto"` 추가 (2026-04-27 완료)

### ✅ 5. 알레르기 경고 표시 (2026-04-29)
- **파일:** `app/lib/screens/food_add_screen.dart`
- **내용:** 사용자 알레르기 × 탐지 음식 교차 경고 UI 추가
  - `_allergenKeywords` 매핑 (11개 알레르겐 × 관련 키워드 목록)
  - `_detectAllergens()` 헬퍼 함수
  - `_AllergyWarningBanner` — 알레르기 음식 있을 때 빨간 배너
  - `_DetectedFoodRow`에 알레르기 뱃지 + 성분 텍스트 표시
- **트러블슈팅:** `docs/troubleshooting.md` 17번 항목 추가

### ✅ 6. 추천 카테고리 설명 배너 (2026-04-29)
- **파일:** `app/lib/screens/recommend_screen.dart`
- **내용:** 카테고리 선택 시 기준 설명 배너 추가
  - `_kCategoryMeta` — 5개 카테고리별 아이콘·설명·색상 메타데이터
  - `_CategoryBanner` — 선택된 카테고리 설명 배너 위젯
  - 백엔드는 이미 `category` 파라미터 처리 중 (변경 없음)
- **트러블슈팅:** `docs/troubleshooting.md` 18번 항목 추가

### ✅ 7. 주간/월간 리포트 인사이트 강화 (2026-04-29)
- **파일:** `app/lib/screens/report_screen.dart`
- **내용:** 주간·월간 탭에 영양소 분석 및 AI 인사이트 추가
  - `_WeeklyNutrAvg` — 탄/단/지 일 평균 + 목표 대비 진행 바
  - `_WeeklyTipCard` — 영양소 패턴 기반 AI 주간 인사이트
  - `_MonthlyInsightCard` — 월 평균 칼로리 평가 + 베스트 데이 하이라이트
- **트러블슈팅:** `docs/troubleshooting.md` 19번 항목 추가

---

## 미완료 / 남은 작업

### ⬜ 기술 문서화
- 알고리즘 흐름도, RAG 파이프라인 설명 (발표용)

### ⬜ 외부 로그인 연동 (선택)
- 네이버/카카오 OAuth (선택사항)

---

## 구현 예정 기능 (캡스톤 피드백 2026-04-20 기준)

| 기능 | 상태 | 비고 |
|------|------|------|
| 리포트 DB 연동 | ✅ 완료 | 일/주/월간 탭 모두 |
| 알레르기 설정 UI | ✅ 완료 | 바텀시트 멀티셀렉트 |
| 추천 카테고리 세분화 | ✅ 완료 | 카테고리별 설명 배너 + 백엔드 필터 |
| 주간/월간 리포트 상세 | ✅ 완료 | 영양소 평균 + AI 인사이트 카드 |
| 알레르기 성분 식품 연동 경고 | ✅ 완료 | 식품 등록 시 알레르기 경고 표시 |
| 기술 문서화 | ⬜ 미완료 | 알고리즘 흐름도, 발표용 자료 |
| 외부 로그인 | ⬜ 미완료 | 선택사항 |

---

## 관련 파일 경로

- 리포트 화면: `app/lib/screens/report_screen.dart`
- 설정 화면: `app/lib/screens/settings_screen.dart`
- DB 모델: `app/lib/models/db_models.dart`
- AppState: `app/lib/app_state.dart`
- RAG 엔진: `ai/rag_engine/`
- 트러블슈팅: `docs/troubleshooting.md`
