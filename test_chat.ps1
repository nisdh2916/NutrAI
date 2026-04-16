$body = @{
  message = "오늘 점심 뭐 먹을까요? 다이어트 중입니다."
  user_profile = @{
    age = 25
    height = 170.0
    weight = 70.0
    goal = "다이어트"
    condition = ""
    allergy = ""
  }
  detected_foods = @()
} | ConvertTo-Json -Depth 5

Write-Host "RAG 테스트 중..." -ForegroundColor Cyan

$response = Invoke-RestMethod `
  -Uri "http://127.0.0.1:8000/chat" `
  -Method POST `
  -ContentType "application/json; charset=utf-8" `
  -Body ([System.Text.Encoding]::UTF8.GetBytes($body))

Write-Host "=== 답변 ===" -ForegroundColor Green
Write-Host $response.answer

Write-Host "=== 참조 문서 ===" -ForegroundColor Yellow
foreach ($src in $response.sources) {
    Write-Host $src
}
