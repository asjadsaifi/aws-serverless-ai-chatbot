$keyId = aws apigateway get-api-keys --region us-east-1 --query "items[?name=='ai-chatbot-dev-api-key'].id" --output text
$apiKey = aws apigateway get-api-key --region us-east-1 --api-key $keyId --include-value --query "value" --output text
$baseUrl = "https://efg7cnu890.execute-api.us-east-1.amazonaws.com/dev"
$headers = @{"x-api-key"=$apiKey; "Content-Type"="application/json"}

Write-Host "========================================="
Write-Host "TEST 1: POST /chat"
Write-Host "========================================="
try {
    $body = '{"session_id":"test-session-1","message":"What is AWS Lambda? Explain in 2 sentences."}'
    $r = Invoke-RestMethod -Uri "$baseUrl/chat" -Method POST -Headers $headers -Body $body
    Write-Host "Status  : SUCCESS"
    Write-Host "Session : $($r.session_id)"
    Write-Host "Response: $($r.response)"
} catch {
    Write-Host "FAILED: $($_.ErrorDetails.Message)"
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST 2: POST /chat (second message, same session)"
Write-Host "========================================="
try {
    $body = '{"session_id":"test-session-1","message":"Give me one example use case for it."}'
    $r = Invoke-RestMethod -Uri "$baseUrl/chat" -Method POST -Headers $headers -Body $body
    Write-Host "Status  : SUCCESS"
    Write-Host "Session : $($r.session_id)"
    Write-Host "Response: $($r.response)"
} catch {
    Write-Host "FAILED: $($_.ErrorDetails.Message)"
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST 3: GET /history"
Write-Host "========================================="
try {
    $r = Invoke-RestMethod -Uri "$baseUrl/history?session_id=test-session-1" -Method GET -Headers $headers
    Write-Host "Status  : SUCCESS"
    Write-Host "Messages: $($r.count) found"
    foreach ($msg in $r.messages) {
        Write-Host "  [$($msg.role)] $($msg.content.Substring(0, [Math]::Min(80, $msg.content.Length)))..."
    }
} catch {
    Write-Host "FAILED: $($_.ErrorDetails.Message)"
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST 4: Validation - empty message should return 400"
Write-Host "========================================="
try {
    $body = '{"session_id":"test-session-1","message":""}'
    $r = Invoke-RestMethod -Uri "$baseUrl/chat" -Method POST -Headers $headers -Body $body
    Write-Host "UNEXPECTED SUCCESS - should have failed"
} catch {
    Write-Host "Correctly rejected: $($_.ErrorDetails.Message)"
}

Write-Host ""
Write-Host "========================================="
Write-Host "TEST 5: Security - missing API key should return 403"
Write-Host "========================================="
try {
    $body = '{"session_id":"test-session-1","message":"hello"}'
    $r = Invoke-RestMethod -Uri "$baseUrl/chat" -Method POST -Headers @{"Content-Type"="application/json"} -Body $body
    Write-Host "UNEXPECTED SUCCESS - should have been blocked"
} catch {
    Write-Host "Correctly blocked: $($_.ErrorDetails.Message)"
}

Write-Host ""
Write-Host "All tests complete."
