# NutrAI UI 리디자인 진행 현황

> 기준 디자인: `c:\Users\user\Downloads\NturAI` (Toss TDS inspired 프로토타입)  
> 작업 브랜치: `feat/app-rag-chat`  
> 시작일: 2026-04-27

---

## 개요

Claude Design으로 생성한 JSX 프로토타입의 디자인을 Flutter/Dart 앱에 그대로 적용하는 작업입니다.

### 핵심 변경 요약

| 항목 | 기존 | 새 디자인 |
|------|------|----------|
| 배경색 | `#F5F6F3` | `#F2F4F6` |
| 브랜드 그린 | `#639922` | `#22A447` |
| 저녁 색상 | 오렌지 | 보라 `#8B5CF6` |
| 텍스트 primary | `#1A1A1A` | `#191F28` |
| 탭 활성 색상 | 그린 | 다크 텍스트 |
| 카드 스타일 | 보더 기반 | 소프트 섀도우 |

---

## 진행 상태

| # | 파일 | 상태 | 주요 변경 내용 |
|---|------|------|--------------|
| 1 | `app_theme.dart` | ✅ 완료 | Toss TDS 색상 팔레트, 섀도우, 반경 토큰 전면 교체 |
| 2 | `main_tab_screen.dart` | ✅ 완료 | 탭 활성색 → 다크 텍스트, FAB 그림자 업데이트 |
| 3 | `home_screen.dart` | ✅ 완료 | 인사 헤더(아바타+날짜+벨), DailyOverviewCard(그래디언트 탑바+도넛+예측 저녁 가이드), 맞춤 팁 배너, MealCard(색상 칩+매크로 바), EmptyMealCard(점선 테두리), 연속기록 카드 |
| 4 | `food_add_screen.dart` | ✅ 완료 | 끼니 3-버튼 선택기, 분석 완료 배너, DetectedFoodItem 색상 박스+수정/삭제, MacroPill 영양 요약, 하단 CTA(총 칼로리+추가 버튼) |
| 5 | `calendar_screen.dart` | ✅ 완료 | 헤더(날짜 대형+Today 버튼), SegmentedControl 탭, DayPicker, 3개 통계 카드(총섭취/끼니수/달성률), Timeline(컬러 도트+라인), MonthlyCalendar(도트 인디케이터+범례) |
| 6 | `report_screen.dart` | ✅ 완료 | BigDonut(180px), MealDotSummary, MacroDetailRow(진행 바), WeeklyChart(막대+목표선), AI 코치 인사이트 카드 |
| 7 | `recommend_screen.dart` | ✅ 완료 | FoodCard(그래디언트 이미지 영역+MacroPill), 필터 칩(가로 스크롤), AI 가이드 배너 |
| 8 | `ai_chat_screen.dart` | ✅ 완료 | ChatBubble(마스코트 아바타), SuggestionChips(가로 스크롤), 입력 바(필 형태+원형 전송) |

---

## 디자인 토큰 (app_theme.dart)

### 색상

```dart
// 배경
bg          = #F2F4F6
bgAlt       = #F9FAFB
surface     = #FFFFFF
line        = #E5E8EB
lineSoft    = #F2F4F6
lineStrong  = #D1D6DB

// 텍스트
text        = #191F28
textSub     = #4E5968
textMuted   = #8B95A1

// 브랜드
brand       = #22A447
brandDark   = #1E8E3E
brandSoft   = #E6F4EA
brandText   = #1A7F36

// 영양소 시맨틱
carb        = #3182F6 (파랑)
protein     = #22A447 (그린)
fat         = #FF9500 (오렌지)

// 끼니 시맨틱
breakfast   = #3182F6
lunch       = #22A447
dinner      = #8B5CF6 (보라)
```

### 반경

```dart
xs=6  sm=8  md=12  lg=16  xl=20  xxl=24  pill=999
```

### 섀도우

```dart
card   = 0 1px 2px rgba(0,0,0,0.04), 0 4px 12px rgba(0,0,0,0.04)
raised = 0 2px 4px rgba(0,0,0,0.06), 0 8px 24px rgba(0,0,0,0.08)
fab    = 0 6px 20px rgba(34,164,71,0.35), 0 2px 6px rgba(0,0,0,0.1)
```

---

## 화면별 변경 상세

### 홈 화면 (home_screen.dart)

- **헤더**: 이름 첫 글자 초록 아바타 + 날짜 + 이름 인사 + 벨 아이콘
- **DailyOverviewCard**: 상단 3색 그래디언트 줄, 도넛 차트(112px) + 영양소 행, 구분선, 남은 칼로리 + 달성률 칩, 저녁 예측 가이드 배너
- **맞춤 팁**: 노란 그래디언트 배경 카드 (`#FEF3C7 → #FEF9E7`)
- **MealCard**: 끼니별 색상 칩(아침=파랑/점심=그린/저녁=보라) + 매크로 미니 바
- **EmptyMealCard**: 점선 초록 테두리 + 진행 도트 + "기록" 버튼
- **연속기록 카드**: 불꽃 아이콘 + 요일 격자

### 식사 추가 화면 (food_add_screen.dart)

- **끼니 선택**: 3버튼 꽉 채운 배치, 활성 시 끼니 색상 배경
- **분석 완료 배너**: 초록 체크 + "사진 분석 완료!" + "다시 촬영" 링크
- **DetectedFoodItem**: 44×44 컬러 박스 + 이름/영양 + 수정/삭제 버튼
- **MacroPill 영양 요약**: 탄/단/지 pill 3개 가로 배치
- **하단 CTA**: 총 칼로리(좌) + "[끼니]에 N개 추가" 버튼(우)

### 기록 화면 (calendar_screen.dart)

- **헤더**: 큰 날짜 숫자 + Today 버튼
- **SegmentedControl**: 주간/월간 토글
- **주간 뷰**: DayPicker(7일) + 통계 3개 카드(총섭취/끼니수/달성률) + Timeline
- **Timeline**: 컬러 도트(12px) + 세로 연결선 + 끼니 카드(MacroMini 포함)
- **월간 뷰**: MonthlyCalendar(그린 도트/노란 도트/미기록) + 월간 요약

### 리포트 화면 (report_screen.dart)

- **헤더**: "건강 리포트" + "YYYY년 M월" + 새로고침 버튼
- **일간**: DayPicker + BigDonut(180px) + MealDotSummary 3개 + MacroDetailRow + AI 코치 카드
- **주간**: WeeklyChart(막대+점선 목표선+목표 근접 배지) + 영양소 주간 평균
- **월간**: 4월 30일 완료 예정 플레이스홀더

### 추천 화면 (recommend_screen.dart)

- **헤더**: "오늘의 추천 식단" + 2탭(AI맞춤/오늘의 식단) + 새로고침
- **AI 가이드 배너**: 초록 그래디언트 배경 + 스파클 아이콘
- **필터 칩**: 가로 스크롤 (전체/저GI/고단백/저나트륨/500kcal 이하)
- **FoodCard**: 140px 그래디언트 이미지 영역 + 하트 + 배지 + kcal 오버레이 + MacroPill + "식단에 추가" 버튼

### AI 챗봇 화면 (ai_chat_screen.dart)

- **상태 표시**: 초록 도트 + "RAG 기반 맞춤 식단 추천 · 온라인"
- **ChatBubble**: 봇=초록 아이콘 아바타, 사용자=오른쪽 초록 말풍선, 서로 다른 border-radius
- **SuggestionChips**: 가로 스크롤 빠른 질문 칩 (pill 형태)
- **입력 바**: pill 형태 텍스트 필드 + 원형 초록 전송 버튼
