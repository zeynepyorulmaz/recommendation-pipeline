#!/bin/bash

# Fashion Recommendation Pipeline Docker Deployment Script

echo "🚀 Deploying Fashion Recommendation Pipeline..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create a .env file with your GEMINI_API_KEY"
    echo "Example:"
    echo "GEMINI_API_KEY=your_api_key_here"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p output

# Build and run with docker-compose
echo "📦 Building Docker image..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

echo "⏳ Waiting for service to be ready..."
sleep 10

# Check if service is healthy
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Service is running successfully!"
    echo "📡 API Endpoints:"
    echo "   - Health check: http://localhost:5000/health"
    echo "   - Evaluate: http://localhost:5000/evaluate (POST)"
    echo ""
    echo "🔧 To stop the service: docker-compose down"
    echo "📊 To view logs: docker-compose logs -f"
else
    echo "❌ Service failed to start properly"
    echo "📊 Checking logs..."
    docker-compose logs
    exit 1
fi 