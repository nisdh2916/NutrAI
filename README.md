#  NutrAI (nutrition + AI)
> **Shoot for your health, NutrAI for your diet.**
> 
> **"식단 기록의 번거로움을 혁신으로, NutrAI가 스마트한 건강 관리를 현실화합니다."**

<div align="center">
  <br/>
  <img src="https://capsule-render.vercel.app/api?type=waving&color=auto&height=200&section=header&text=NutrAI&fontSize=90" width="100%">
</div>

---

##  목차
1. [팀 소개](#-팀-소개)
2. [프로젝트 소개](#-프로젝트-소개)
3. [주요 기능](#-주요-기능)
4. [기술 스택](#-기술-스택)
5. [시스템 아키텍처](#-시스템-아키텍처)
6. [협업 컨벤션](#-협업-컨벤션)
7. [설치 및 실행 방법](#-설치-및-실행-방법)

---

## 팀 소개 (Team Moonshot)

| 이름 | 직책 | 역할 | 담당 업무 |
| :---: | :---: | :--- | :--- |
| **김영서** | 팀장 | **App / PM** | Flutter 앱 개발, UI/UX 설계, 전체 일정 관리 |
| **김서연** | 팀원 | **BackEnd** | FastAPI 서버 구축, DB 설계, API 명세서 작성 |
| **신동하** | 팀원 | **AI / Data** | YOLOv11 모델 학습, 영양 DB 전처리, RAG 엔진 최적화 |
| **이호연** | 팀원 | **BackEnd** | FastAPI 서버 구축, DB 설계, API 명세서 작성 |
| **최영수** | 팀원 | **AI / Data** | YOLOv11 모델 학습, 영양 DB 전처리, RAG 엔진 최적화 |
---

##  프로젝트 소개

### 1. 기획 배경
- **Pain Point**: 식단 관리의 핵심은 '기록'이지만, 수기 입력의 번거로움과 부정확한 영양 정보로 인해 다이어터와 당뇨 환자들이 쉽게 중도 포기하는 문제가 발생합니다.
- **Solution**: 사진 촬영 한 번으로 식단을 자동 인식하고, 공신력 있는 DB를 바탕으로 정밀한 분석과 개인 맞춤형 AI 피드백을 제공하여 지속 가능한 식단 관리를 돕습니다.
- 
### 2. 주요 타겟
-  **만성질환자** : 식단 기록이 필수적인 당뇨 및 고혈압 환자.
-  **헬스 및 자기관리를 위한 사용자** : 체계적인 영양 섭취와 데이터 기반 성장을 원하는 사용자.

---

##  주요 기능 (Features)

<details>
<summary><b> AI 식단 자동 기록 (Smart Capture)</b></summary>
<br/>

- **YOLOv11** 객체 탐지 기술을 활용하여 이미지 내 음식의 종류와 수량을 실시간으로 분석합니다.
- 한국식품영양성분표 DB와 연동하여 칼로리 및 탄단지 즉시 분석.
</details>

<details>
<summary><b> 지능형 대시보드 (Dashboard)</b></summary>
<br/>

- 오늘 남은 권장 섭취량 시각화.
- 일별/주별 기록 추이를 통한 건강 상태 트래킹.
</details>

<details>
<summary><b> 맞춤형 AI 코칭 (RAG Engine)</b></summary>
<br/>

- 사용자 건강 데이터(키, 몸무게, 활동량) 기반 맞춤 영양 가이드.
- **RAG(검색 증강 생성)** 를 통해 최신 영양학 근거에 기반한 챗봇 답변 제공.
</details>

---

## 🛠 기술 스택

###  Frontend
<p align="left">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=Flutter&logoColor=white">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=Dart&logoColor=white">
</p>

###  Backend
<p align="left">
  <img src="https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=FastAPI&logoColor=white">
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=Python&logoColor=white">
  <img src="https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=SQLite&logoColor=white">
</p>

###  AI & Data
<p align="left">
  <img src="https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=PyTorch&logoColor=white">
  <img src="https://img.shields.io/badge/YOLOv11-FF6F00?style=for-the-badge&logo=fastapi&logoColor=white">
  <img src="https://img.shields.io/badge/Ollama-000000?style=for-the-badge&logo=ollama&logoColor=white">
  <img src="https://img.shields.io/badge/ChromaDB-FF6B35?style=for-the-badge&logo=databricks&logoColor=white">
</p>

###  DevOps & Tools
<p align="left">
  <img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=GitHub%20Actions&logoColor=white">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=Docker&logoColor=white">
  <img src="https://img.shields.io/badge/Notion-000000?style=for-the-badge&logo=Notion&logoColor=white">
</p>

---

##  시스템 아키텍처

<img width="1326" height="889" alt="NutrAI 시스템 아키텍처" src="https://github.com/user-attachments/assets/3961caa2-3412-45be-b132-ec4797a85579" />















##  협업 컨벤션 (Convention)

<details>
<summary><b> Git Commit Message 규칙</b></summary>
<br/>

> **"태그: 상세 내용"** 형식을 준수합니다. (예: `feat: 로그인 기능 추가`)

| 태그 | 의미 |
| :--- | :--- |
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서 수정 (README 등) |
| `design` | UI 디자인 변경 |
| `chore` | 빌드 업무, 패키지 설정 수정 |
| `refactor` | 코드 리팩토링 |
</details>

<details>
<summary><b> Branch 전략</b></summary>
<br/>

- `main`: 배포 가능한 최종 코드
- `develop`: 개발 중인 코드들이 모이는 곳
- `feat/app`: 앱 관련 기능 개발
- `feat/server`: 서버 API 개발
- `feat/ai`: AI 모델 학습 및 데이터 처리
</details>

---

##  설치 및 실행 방법 (Installation)

### 1. 프로젝트 클론
```bash
git clone https://github.com/nisdh2916/NutrAI.git
cd NutrAI
```

### 2. Frontend (Flutter) 실행
```Bash
cd app
flutter pub get
flutter run
```
### 3. AI (Ollama) 실행
```bash
# Ollama 설치 후 모델 실행 (별도 터미널)
ollama serve
ollama pull qwen3:8b
```

### 4. Backend (FastAPI) 실행
```bash
# 프로젝트 루트(NutrAI/)에서 실행
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r server/requirements.txt
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
```

### 5. API 동작 확인
```bash
curl http://127.0.0.1:8000/health
```

###  프로젝트 구조
```Plaintext
NutrAI/
├── .github/                # GitHub Actions CI/CD 워크플로우
├── app/                    # Flutter 프론트엔드 (Dart)
│   ├── lib/
│   │   ├── core/           # 알레르기·영양 상수
│   │   ├── database/       # SQLite DatabaseHelper
│   │   ├── models/         # 데이터 모델 (User, Meal, Food 등)
│   │   ├── providers/      # AppState, MealState, UserState (Provider)
│   │   ├── repositories/   # DB CRUD (user, meal, food, chat)
│   │   ├── screens/        # 화면 (홈, 캘린더, 채팅, 리포트 등)
│   │   ├── services/       # 서버 API 통신 (chat, allergen)
│   │   ├── theme/          # 앱 테마
│   │   └── utils/          # 알레르기 체커, 채팅 파서
│   └── pubspec.yaml
├── server/                 # FastAPI 백엔드 (Python)
│   ├── api/                # API 엔드포인트 (/chat, /detect, /recommend 등)
│   ├── services/           # 비즈니스 로직 (meal_service 등)
│   ├── tests/              # pytest 테스트
│   └── requirements.txt
├── ai/                     # AI 모델 및 추론 로직
│   ├── rag_engine/         # RAG 파이프라인 + ChromaDB
│   └── scripts/            # 영양 DB 전처리, YOLO 학습 스크립트
├── data/                   # 영양 DB (한국식품영양성분표)
├── docs/                   # 기획서, 발표자료, 트러블슈팅
├── .gitignore
└── README.md
```

<div align="center">
Copyright © 2026 <b>Team Moonshot</b>. All rights reserved.
</div>
