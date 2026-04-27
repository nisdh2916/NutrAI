# NutrAI 작업 진행 상황

마지막 업데이트: 2026-04-27

---

## 현재 브랜치: `feat/rag-improvements`

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

---

## 미완료 / 남은 작업

### ⬜ 5. `feat/rag-improvements` PR 머지
- **방법:** GitHub에서 직접 PR 생성 및 머지
  - URL: `https://github.com/nisdh2916/NutrAI/compare/main...feat/rag-improvements`
- **이유:** `gh` CLI 미설치, branch protection으로 직접 push 불가

---

## 구현 예정 기능 (캡스톤 피드백 2026-04-20 기준)

| 기능 | 상태 | 비고 |
|------|------|------|
| 리포트 DB 연동 | ✅ 완료 | 일/주/월간 탭 모두 |
| 알레르기 설정 UI | ✅ 완료 | 바텀시트 멀티셀렉트 |
| 추천 카테고리 세분화 | ⬜ 미완료 | RAG 추천 결과 카테고리 분류 |
| 주간/월간 리포트 상세 | ⬜ 미완료 | 현재 기본 차트만 표시 |
| 알레르기 성분 식품 연동 경고 | ⬜ 미완료 | 식품 등록 시 알레르기 경고 표시 |

---

## 관련 파일 경로

- 리포트 화면: `app/lib/screens/report_screen.dart`
- 설정 화면: `app/lib/screens/settings_screen.dart`
- DB 모델: `app/lib/models/db_models.dart`
- AppState: `app/lib/app_state.dart`
- RAG 엔진: `ai/rag_engine/`
- 트러블슈팅: `docs/troubleshooting.md`
