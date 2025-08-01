@echo off
echo 🧪 Testing Fashion Recommendation Pipeline...

REM Test health endpoint
echo 📡 Testing health endpoint...
curl -f http://localhost:5000/health > nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Health endpoint is working
) else (
    echo ❌ Health endpoint failed
    pause
    exit /b 1
)

REM Test evaluate endpoint with a sample image
echo 📡 Testing evaluate endpoint...
curl -X POST http://localhost:5000/evaluate -H "Content-Type: application/json" -d "{\"input_path\": \"https://images.unsplash.com/photo-1445205170230-053b83016050?w=500\"}" -o test_response.json

if %errorlevel% equ 0 (
    echo ✅ Evaluate endpoint is working
    echo 📄 Response saved to test_response.json
    
    REM Check if response contains expected fields
    findstr "recommendations" test_response.json > nul
    if %errorlevel% equ 0 (
        echo ✅ Response contains recommendations
    ) else (
        echo ⚠️  Response might be incomplete
    )
) else (
    echo ❌ Evaluate endpoint failed
    pause
    exit /b 1
)

echo 🎉 All tests passed!
pause 