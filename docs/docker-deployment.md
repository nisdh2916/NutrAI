# NutrAI Docker 배포 가이드

## 구성

```
[Android 앱] ──── HTTP ────▶ [nutrai-server :8000]
                                      │
                              ┌───────┴────────┐
                         YOLOv11m          FastAPI
                                      │
                             [ollama :11434]
                               qwen3:8b
                             (같은 compose)
```

모든 서비스가 Docker 안에서 동작합니다. 호스트에 별도로 설치할 것이 없습니다.

---

## 1. Portainer에서 배포

**Stacks → Add stack → Web editor**에 `docker-compose.yml` 내용을 붙여넣고 **Deploy** 클릭.

시작 순서는 자동으로 처리됩니다:
1. `ollama` 컨테이너 기동
2. `ollama-pull`이 `qwen3:8b` 자동 다운로드 (~5GB, 최초 1회만)
3. `nutrai-server` 기동

> **GPU 없는 서버라면** `docker-compose.yml`의 `deploy.resources` 블록을 주석처리하세요.

---

## 2. 일반 서버 (CLI)

```bash
cp .env.example .env

docker compose up -d --build

# 로그 확인 (모델 다운로드 진행 상황)
docker compose logs -f ollama-pull
docker compose logs -f nutrai-server
```

---

## 3. Android 앱 빌드

```bash
# 서버 IP로 APK 빌드
flutter build apk --dart-define=API_BASE_URL=http://<서버IP>:8000

# USB 연결 (adb reverse 터널)
adb reverse tcp:8000 tcp:8000
flutter run
```

---

## 4. 자주 쓰는 명령어

```bash
# 재시작
docker compose restart

# 중지
docker compose down

# 코드 변경 후 서버만 재빌드
docker compose up -d --build nutrai-server

# 모델/DB 포함 전체 초기화
docker compose down -v
```

---

## 볼륨 용량 참고

| 볼륨 | 내용 | 용량 |
|------|------|------|
| `ollama_data` | qwen3:8b 모델 | ~5GB |
| `chroma_data` | ChromaDB 벡터 DB | 수백MB |
