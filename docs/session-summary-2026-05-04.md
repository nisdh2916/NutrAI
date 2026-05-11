# 2026-05-04 작업 정리

작성 기준: `main` 브랜치, `HEAD 7b7faf4`

이번 문서는 현재 대화에서 진행한 작업을 한눈에 확인하기 위한 세션 요약이다. 작업트리는 세션 시작 전부터 이미 수정/미추적 파일이 섞여 있었기 때문에, 아래 내용은 이번 대화에서 직접 진행한 작업과 확인한 상태를 중심으로 정리했다.

## 1. 프로젝트 실행 및 기본 상태 확인

- 백엔드 서버가 이미 `8000` 포트에서 실행 중인 것을 확인했다.
- `/health` 응답이 정상임을 확인했다.
- Android 에뮬레이터에서 로컬 서버에 접근할 수 있도록 `adb reverse tcp:8000 tcp:8000`을 실행했다.
- `flutter pub get`을 실행했고, 의존성 설치는 완료됐다.
  - pub advisory decode 관련 경고는 있었지만 설치 자체는 성공했다.
- Android 에뮬레이터 `emulator-5554`에서 Flutter 앱을 실행했다.
- 최초 DevTools URL:
  - `http://127.0.0.1:9101?uri=http://127.0.0.1:63076/uNmNI089_64=/`

## 2. Agent Skills 설치 상태 확인

- Matt Pocock skills가 이미 설치된 상태임을 확인했다.
- `.agents/skills` 아래에 프로젝트용 스킬들이 존재했다.
- `npx`는 현재 PATH에서 사용할 수 없어서 README의 `npx skills@latest ...` 설치 방식은 이 환경에서 바로 실행할 수 없었다.
- 사용자가 `to-issues`를 호출했지만, 이후 이 흐름은 진행하지 않기로 했다.

## 3. 팀 브랜치 분리

`main` 브랜치의 `7b7faf4` 기준으로 조원별 브랜치를 만들고 원격에 push했다.

생성 및 push 완료:

- `team/kim-youngseo`
- `team/kim-seohyeon`
- `team/shin-dongha`
- `team/lee-hoyeon`
- `team/choi-youngsu`

정정 사항:

- 처음에 `team/kim-seoyeon`으로 잘못 만든 브랜치는 로컬과 원격에서 삭제했다.
- 사용자 확인에 따라 이름을 `김서연`이 아니라 `김서현`으로 바로잡았다.

현재 작업 브랜치는 계속 `main`으로 유지했다.

## 4. README.md 정리

`README.md`를 전체적으로 다시 정리했다.

주요 변경:

- 팀원 이름을 `김서연`에서 `김서현`으로 수정했다.
- 프로젝트 개요, 핵심 기능, 기술 스택, 실행 방법, API 흐름, 디렉터리 구조, 협업 규칙을 읽기 쉽게 재구성했다.
- 팀 브랜치 목록에 `team/kim-seohyeon`을 반영했다.
- 실제로 비어 있는 `.github` 디렉터리를 제거하면서 README의 GitHub Actions 관련 표현도 정리했다.

검증:

- `git diff --check -- README.md` 통과.

## 5. 디렉터리와 생성 파일 정리

불필요한 placeholder와 생성 파일을 정리했다.

`.gitignore`에 추가한 항목:

- `__pycache__/`
- `.pytest_cache/`
- `.flutter-plugins`
- `**/build/`
- `*_out.txt`
- `*_err.txt`
- `ai/rag_engine/chroma_db/`

삭제한 캐시/로그/생성물:

- `.pytest_cache`
- `ai/rag_engine/__pycache__`
- `server/**/__pycache__`
- `app/flutter*.log`
- `app/flutter_err.txt`
- `app/flutter_out.txt`
- `server.log`
- `server_err.txt`
- `server_out.txt`

삭제한 불필요한 placeholder:

- `.github/.gitkeep`
- `ai/.gitkeep`
- `ai/rag_engine/.gitkeep`
- `ai/scripts/.gitkeep`
- `app/.gitkeep`
- `app/android/.gitkeep`
- `app/lib/core/.gitkeep`
- `app/lib/data/.gitkeep`
- `app/lib/features/.gitkeep`
- `app/lib/models/.gitkeep`
- `data/nutrition_db/.gitkeep`
- `docs/.gitkeep`
- `server/.gitkeep`
- `server/api/.gitkeep`
- `server/core/.gitkeep`
- `server/db/.gitkeep`
- `server/services/.gitkeep`

삭제한 빈/생성 디렉터리:

- `.github`
- `app/lib/core`
- `app/lib/data`
- `app/lib/features`
- `server/core`
- `app/linux`
- `app/macos`

주의:

- `app/build/`는 Flutter/Dart 프로세스가 실행 중이어서 물리 삭제하지 않고 ignore 처리했다.
- `ai/rag_engine/chroma_db/`도 물리 삭제하지 않고 ignore 처리했다.
- `app/.flutter-plugins`는 Flutter 실행 시 재생성될 수 있어 다시 삭제 상태로 유지했다.

## 6. 디자인 컨텍스트 설정

`polish` 스킬을 사용하기 전에 `impeccable` 컨텍스트가 필요해서 `.impeccable.md`를 생성했다.

정리한 디자인 방향:

- 사용자: 식단 기록, 건강 관리, 다이어트, 질환/알레르기 기반 식단 관리 사용자.
- 브랜드 톤: 차분하고 신뢰감 있고 친근한 건강 동반자.
- 미학: 현재 Toss TDS inspired light theme 유지.
- 원칙:
  - 전체 리디자인이 아니라 기존 정체성을 유지하며 polish.
  - `app/lib/theme/app_theme.dart`의 토큰 우선 사용.
  - 건강 정보는 차분하고 빠르게 훑어볼 수 있게 유지.
  - 인터랙션, 빈 상태, 오류 상태를 명확히 표현.

사용자가 디자인 시스템 문서가 필요한지 물었고, 현재 단계에서는 기존 테마와 코드만으로 충분하다고 안내했다.

## 7. Polish 작업

`polish` 스킬 기준으로 UI 마감 품질을 정리했다.

공통 변경:

- `app/lib/**/*.dart`의 음수 `letterSpacing`을 모두 `0`으로 정리했다.
- `app/lib/theme/app_theme.dart`에 전역 터치/상태 테마를 보강했다.
  - `splashColor`
  - `highlightColor`
  - `IconButtonTheme`
  - `TextButtonTheme`
  - `FloatingActionButtonTheme`
  - `SnackBarTheme`

화면별 변경:

- `main_tab_screen.dart`
  - 하단 내비게이션을 `Semantics + Material + InkWell` 기반으로 변경.
  - FAB tooltip과 아이콘 색상 정리.
- `ai_chat_screen.dart`
  - 빠른 질문 칩의 터치 영역을 44px 이상으로 조정.
  - 입력창에 `TextInputAction.send` 적용.
  - 전송 버튼을 `Semantics + Material + InkWell` 기반으로 정리.
- `food_add_screen.dart`
  - 직접 추가 버튼, 식사 선택, 사진 버튼의 터치 패턴을 정리.
  - 사용하지 않는 `_FoodDB.search()`와 `_FoodDB.all` 샘플 리스트 제거.

검증:

- `dart format` 실행.
- `flutter analyze --no-fatal-infos` 통과.
- `flutter test`는 처음 실패했고, 아래 테스트 수정을 통해 통과시켰다.

## 8. Widget Test 수정

문제:

- `app/test/widget_test.dart`가 `NutrAIApp`을 `AppState` Provider 없이 렌더링했다.
- 이 때문에 `ProviderNotFoundException`이 발생했다.
- Provider를 추가해도 사용자 없는 상태에서는 온보딩 타이머가 남아 테스트가 종료되지 않을 수 있었다.

해결:

- `_ReadyAppState extends AppState`를 추가했다.
- `loading=false`, `user=UserProfileEntity(...)`를 오버라이드했다.
- `ChangeNotifierProvider<AppState>`로 감싸서 `NutrAIApp`을 렌더링했다.
- Provider generic을 명시해 `_RootRouter`가 `AppState` 타입을 정상적으로 찾게 했다.

문서화:

- `docs/troubleshooting.md`에 `20. Flutter 위젯 테스트가 AppState Provider 없이 앱을 렌더링함` 항목을 추가했다.

검증:

- `flutter test` 통과.

## 9. Critique 작업

`critique` 스킬을 사용해 현재 디자인을 평가했다.

자동/수동 확인:

- `npx impeccable --json ...` 시도:
  - 현재 환경에서 `npx`를 찾을 수 없어 실패.
- Android 에뮬레이터 스크린샷 캡처:
  - `C:\Users\user\AppData\Local\Temp\nutrai-critique\nutrai-critique.png`

주요 평가:

- 강한 의미의 AI slop은 아니었다.
  - 어두운 글로우, 과한 그라디언트 텍스트, 무분별한 glassmorphism은 없었다.
- 다만 card + metric + donut + recommendation 구조가 반복되어 템플릿처럼 느껴질 수 있었다.
- Design Health Score: `25/40`
- Cognitive load: `3/8` 실패, 중간 수준.

우선순위 문제:

- P1: 홈 AI coach FAB가 콘텐츠를 가림.
- P1: 홈 헤더가 SafeArea를 고려하지 않아 상태바와 겹침.
- P1: 홈 화면이 실제 데이터 대신 static demo meals를 표시.
- P2: 추천/리포트 사용자명 fallback이 `00`.
- P2: 추천/리포트에 `GestureDetector` 기반 커스텀 터치 표면이 많이 남아 있음.

## 10. Critique 이후 UX 수정

사용자의 “싹 다 고쳐줘” 요청에 따라 `layout`과 `adapt` 기준으로 수정했다.

홈 화면:

- `HomeScreen`에서 하드코딩된 `_meals` 샘플 데이터를 제거했다.
- `context.watch<AppState>()`로 `todayMeals`를 구독하도록 변경했다.
- `MealWithFoods`를 홈 카드용 `MealRecord`로 변환하는 `_toMealRecord()`를 추가했다.
- 사용자 목표 칼로리는 `appState.user?.targetKcal`을 우선 사용하고, 없으면 `profile.bmr` fallback을 사용하도록 했다.
- 상단 헤더를 `SafeArea` 안에 넣어 상태바 겹침을 해결했다.
- 기존 홈 내부 AI coach FAB를 제거했다.
- AI 코치 진입점은 헤더의 `IconButton`으로 이동했다.
- 설정 진입점도 헤더 `IconButton`으로 명확히 정리했다.
- 비어 있는 다음 끼니 카드가 실제 기록 상태에 맞춰 `아침`, `점심`, `저녁` 중 다음 항목을 보여주도록 변경했다.
- 빈 끼니 카드의 기록 버튼을 `Material + InkWell` 기반으로 바꿨다.
- “오늘 걸음 수”, “저녁은 ...”처럼 실제 데이터가 아닌 데모성 문구를 제거했다.
- “연속 기록 7일째”처럼 실제 streak가 아닌 표현을 `기록 흐름`, `오늘 기록 전/완료`로 정리했다.

추천 화면:

- 기본 사용자명 fallback을 `사용자`로 변경했다.
- 새로고침 버튼을 `IconButton`으로 변경했다.
- 카테고리 칩을 44px 터치 영역과 `Semantics + Material + InkWell` 구조로 변경했다.
- 추천 카드 전체를 `Material + InkWell` 기반으로 바꿨다.
- 즐겨찾기/피드백/닫기 버튼을 `IconButton` 또는 `TextButton`/`ElevatedButton` 기반으로 정리했다.
- 피드백 바텀시트의 선택 항목과 제출/건너뛰기 버튼도 Material 계열 위젯으로 통일했다.
- `recommend_screen.dart`에서 남아 있던 `GestureDetector`를 제거했다.

리포트 화면:

- 기본 사용자명 fallback을 `사용자`로 변경했다.
- 주간 날짜 스트립을 `Semantics + Material + InkWell` 구조로 바꿨다.
- 주간 막대 그래프의 날짜 선택 영역을 접근 가능한 터치 표면으로 변경했다.
- 월간 달력 날짜 셀도 `Semantics + Material + InkWell` 구조로 변경했다.
- `report_screen.dart`에서 남아 있던 `GestureDetector`를 제거했다.

메인 탭:

- `main_tab_screen.dart`의 사용자명 fallback을 `00`에서 `사용자`로 변경했다.

문서화:

- `docs/troubleshooting.md`에 `21. 홈 화면이 데모 식단과 플로팅 AI 버튼으로 실제 상태를 가림` 항목을 추가했다.

## 11. 최종 검증

실행한 검증:

- `flutter analyze --no-fatal-infos`
  - 종료 코드 `0`.
  - 기존 info lint 44개는 남아 있음.
  - warning/error는 없음.
- `flutter test`
  - `00:00 +1: All tests passed!`
- `flutter run -d emulator-5554 --debug --no-resident`
  - Android 에뮬레이터에 debug APK 빌드 및 설치 성공.
- `git diff --check`
  - 통과.
  - 일부 파일의 LF -> CRLF 경고만 표시됨.

에뮬레이터 스크린샷 확인:

- 수정 후 홈 화면 스크린샷:
  - `C:\Users\user\AppData\Local\Temp\nutrai-fix-verify\home-after-2.png`
- 확인한 내용:
  - 상단 상태바와 헤더가 겹치지 않음.
  - 홈 AI FAB가 카드 위에 겹치지 않음.
  - 홈 화면이 실제 기록 없음 상태를 기준으로 표시됨.
  - 데모성 걸음 수/7일 연속 문구가 제거됨.

## 12. 현재 남은 주의사항

- `app/build/`와 `ai/rag_engine/chroma_db/`는 ignore 처리했지만 물리적으로는 남아 있을 수 있다.
- `app/.flutter-plugins`는 삭제 상태로 유지했지만, Flutter 명령 실행 시 다시 생성될 수 있다.
- 이번 세션에서는 commit이나 PR 생성은 하지 않았다.
- 현재 작업트리에는 이번 작업 외에도 기존 수정/미추적 파일이 함께 보인다.

## 13. 하단바 레이아웃 추가 수정

사용자가 하단바 스크린샷을 공유하며 어색함을 지적했다.

확인한 문제:

- 하단바가 `홈`, `기록`, 중앙 `+`, `리포트`, `추천`, `설정` 구조로 보여 좌우 균형이 깨졌다.
- `설정`까지 하단 primary nav에 포함되어 오른쪽 탭이 3개로 몰렸다.
- 중앙 `+`가 `Scaffold.floatingActionButton`으로 떠 있어 홈 화면의 `기록 흐름` 카드 요일 라벨을 덮었다.

수정:

- 하단 primary nav를 `홈`, `기록`, 중앙 `+`, `리포트`, `추천` 구조로 정리했다.
- `설정`은 이미 홈 헤더에서 접근 가능하므로 하단 primary nav에서 제거했다.
- 중앙 `+`를 떠 있는 FAB가 아니라 하단바 내부의 `_AddNavAction`으로 옮겼다.
- `Scaffold.floatingActionButton`과 `FloatingActionButtonLocation.centerDocked`를 제거했다.
- 홈/기록/추천/리포트 화면의 하단 스크롤 padding을 `100`에서 `144`로 늘렸다.

검증:

- `flutter analyze --no-fatal-infos` 통과.
- `flutter test` 통과.
- `flutter run -d emulator-5554 --debug --no-resident`로 에뮬레이터 실행 확인.
- 수정 후 스크린샷:
  - `C:\Users\user\AppData\Local\Temp\nutrai-bottom-nav-verify\bottom-nav-fixed.png`
- `docs/troubleshooting.md`에 `22. 하단바 중앙 추가 버튼이 탭 균형을 깨고 콘텐츠를 덮음` 항목을 추가했다.

## 14. Audit 후 전체 품질 수정

사용자가 `/audit` 결과를 이어서 “전부 수정” 요청했다.

컴파일/테스트 차단 문제:

- `food_add_screen.dart`의 `_FoodDB.search()`가 존재하지 않는 `all` 목록을 참조하던 문제를 제거했다.
- `detectAllergens()`가 `core/allergens.dart`와 `utils/allergy_checker.dart` 양쪽에서 import되어 충돌하던 문제를 정리했다.
- 음식 추가 화면은 `core/allergens.dart`의 알레르기 판정만 사용하도록 했다.

접근성/터치 영역:

- `food_add_screen.dart`, `calendar_screen.dart`, `user_setup_screen.dart`, `settings_screen.dart`, `onboarding_chat_screen.dart`에 남아 있던 `GestureDetector` 기반 터치 표면을 `InkWell` 중심으로 바꿨다.
- 삭제/수정/칩/날짜/전송 버튼 등 작은 터치 영역을 44px 기준에 맞게 보정했다.
- 캘린더 Today 버튼과 빈 식단 추가 버튼의 높이를 44px로 조정했다.

색상 대비:

- `AppColors.textMuted`, `textDisabled`, `brand`, `brandDark`, `brandText`, `blue`, `red`, `orange`, `dinner` 토큰을 더 높은 대비로 조정했다.
- 영양/끼니 의미 색상은 공통 색상 토큰을 참조하도록 정리했다.
- 음식 추가 화면의 알레르기 경고 색상을 `AppColors.red`/`redSoft` 토큰으로 통일했다.

성능:

- `food_add_screen.dart`의 촬영 완료 이미지에 `cacheWidth`/`cacheHeight`를 지정했다.
- `calendar_screen.dart`의 식단 상세 이미지에도 `cacheWidth`/`cacheHeight`를 지정했다.

Lint/포맷:

- `dart fix --apply`로 `prefer_const_constructors`, `unnecessary_brace_in_string_interps`, `curly_braces_in_flow_control_structures` 등 info lint를 정리했다.
- `meal_models.dart`, `meal_repository.dart`, `report_screen.dart`, `settings_screen.dart`, `user_setup_screen.dart`, `onboarding_chat_screen.dart` 일부가 자동 포맷/린트 수정됐다.

검증:

- `flutter analyze`
  - `No issues found!`
- `flutter test`
  - `All tests passed!`

문서화:

- `docs/troubleshooting.md`에 `23. 감사 후 flutter analyze/flutter test가 음식 추가 화면에서 실패함` 항목을 추가했다.

## 15. 주요 변경 파일

문서:

- `README.md`
- `.impeccable.md`
- `docs/troubleshooting.md`
- `docs/session-summary-2026-05-04.md`

설정/정리:

- `.gitignore`
- 여러 `.gitkeep` placeholder 삭제
- `app/.flutter-plugins` 삭제 상태 유지

Flutter UI:

- `app/lib/theme/app_theme.dart`
- `app/lib/screens/home_screen.dart`
- `app/lib/screens/main_tab_screen.dart`
- `app/lib/screens/ai_chat_screen.dart`
- `app/lib/screens/food_add_screen.dart`
- `app/lib/screens/calendar_screen.dart`
- `app/lib/screens/recommend_screen.dart`
- `app/lib/screens/report_screen.dart`
- `app/lib/screens/settings_screen.dart`
- `app/lib/screens/user_setup_screen.dart`
- `app/lib/screens/onboarding_chat_screen.dart`
- `app/lib/models/meal_models.dart`
- `app/lib/repositories/meal_repository.dart`

테스트:

- `app/test/widget_test.dart`

기존 작업트리에 함께 존재하는 변경/추가 파일:

- `ai/rag_engine/rag_pipeline.py`
- `app/lib/database/database_helper.dart`
- `app/lib/models/db_models.dart`
- `app/lib/providers/app_state.dart`
- `app/lib/providers/meal_state.dart`
- `app/lib/providers/user_state.dart`
- `app/lib/services/chat_service.dart`
- `app/lib/repositories/chat_repository.dart`
- `app/lib/utils/*`
- `docs/architecture-improvements.md`
- `docs/architecture-progress.md`
