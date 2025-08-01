@echo off
echo 🚀 Deploying Fashion Recommendation Pipeline...

REM Check if .env file exists
if not exist .env (
    echo ❌ Error: .env file not found!
    echo Please create a .env file with your GEMINI_API_KEY
    echo Example:
    echo GEMINI_API_KEY=your_api_key_here
    pause
    exit /b 1
)

REM Create output directory if it doesn't exist
if not exist output mkdir output

REM Build and run with docker-compose
echo 📦 Building Docker image...
docker-compose build

echo 🚀 Starting services...
docker-compose up -d

echo ⏳ Waiting for service to be ready...
timeout /t 10 /nobreak > nul

REM Check if service is healthy
curl -f http://localhost:5000/health > nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Service is running successfully!
    echo 📡 API Endpoints:
    echo    - Health check: http://localhost:5000/health
    echo    - Evaluate: http://localhost:5000/evaluate (POST)
    echo.
    echo 🔧 To stop the service: docker-compose down
    echo 📊 To view logs: docker-compose logs -f
) else (
    echo ❌ Service failed to start properly
    echo 📊 Checking logs...
    docker-compose logs
    pause
    exit /b 1
)

pause 