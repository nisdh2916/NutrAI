# NutrAI Docker 배포 가이드

## 구성

```text
[Android 앱] ---- HTTP ----> [nutrai-server :8000]
                                  |
                         FastAPI / YOLO / RAG
                                  |
                 [host.docker.internal:11434]
                         기존 Ollama 서버
```

현재 `docker-compose.yml`은 FastAPI 서버와 ChromaDB 볼륨을 관리합니다. Ollama는 같은 compose 안에서 띄우지 않고, 호스트 또는 기존 컨테이너의 `http://host.docker.internal:11434` 주소를 사용합니다.

## 1. 최초 배포

```bash
cp .env.example .env

docker compose build
docker compose --profile init run --rm init-chroma
docker compose up -d nutrai-server
```

`init-chroma`는 `ai/scripts/db/build_full_db.py`를 실행해서 `chroma_data` 볼륨에 `detection`과 `nutrition` 컬렉션을 생성합니다. 새 서버나 빈 볼륨에서는 이 단계를 먼저 실행해야 `/food/search`, `/detect` 영양 매핑, 추천 RAG가 최신 영양 DB를 사용합니다.

## 2. 일반 재배포

ChromaDB 볼륨을 지우지 않았다면 서버만 재빌드하면 됩니다.

```bash
docker compose up -d --build nutrai-server
```

영양 엑셀, 가이드라인, 스크래핑 데이터가 바뀐 경우에는 ChromaDB를 다시 빌드하세요.

```bash
docker compose --profile init run --rm init-chroma
docker compose restart nutrai-server
```

## 3. 전체 초기화

`docker compose down -v`는 `chroma_data` 볼륨도 삭제합니다. 이후에는 반드시 초기화 서비스를 다시 실행해야 합니다.

```bash
docker compose down -v
docker compose build
docker compose --profile init run --rm init-chroma
docker compose up -d nutrai-server
```

## 4. 로그와 상태 확인

```bash
docker compose logs -f nutrai-server
docker compose ps
```

헬스체크:

```bash
curl http://localhost:8001/health
```

## 5. Android 앱 빌드

```bash
flutter build apk --dart-define=API_BASE_URL=http://<서버IP>:8001
```

USB 개발 중 로컬 터널을 쓸 때:

```bash
adb reverse tcp:8001 tcp:8001
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

## 볼륨 용량 참고

| 볼륨 | 내용 | 용량 |
|------|------|------|
| `chroma_data` | ChromaDB 벡터 DB | 수백 MB 이상 |
