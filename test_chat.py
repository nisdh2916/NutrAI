import urllib.request
import json

data = {
    "message": "오늘 점심 뭐 먹을까요? 다이어트 중입니다.",
    "user_profile": {
        "age": 25,
        "height": 170.0,
        "weight": 70.0,
        "goal": "다이어트",
        "condition": "",
        "allergy": ""
    },
    "detected_foods": []
}

body = json.dumps(data).encode("utf-8")
req = urllib.request.Request(
    "http://127.0.0.1:8000/chat",
    data=body,
    headers={"Content-Type": "application/json; charset=utf-8"},
    method="POST"
)

print("RAG 테스트 중... (첫 실행 시 벡터 DB 구축으로 시간이 걸립니다)")
with urllib.request.urlopen(req, timeout=120) as res:
    result = json.loads(res.read().decode("utf-8"))

print("\n=== 답변 ===")
print(result["answer"])
print("\n=== 참조한 문서 ===")
for src in result["sources"]:
    print(f"- {src}")
