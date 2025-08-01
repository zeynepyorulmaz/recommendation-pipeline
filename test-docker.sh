#!/bin/bash

# Test script for Fashion Recommendation Pipeline Docker deployment

echo "🧪 Testing Fashion Recommendation Pipeline..."

# Test health endpoint
echo "📡 Testing health endpoint..."
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Health endpoint is working"
else
    echo "❌ Health endpoint failed"
    exit 1
fi

# Test evaluate endpoint with a sample image
echo "📡 Testing evaluate endpoint..."
curl -X POST http://localhost:5000/evaluate \
  -H "Content-Type: application/json" \
  -d '{"input_path": "https://images.unsplash.com/photo-1445205170230-053b83016050?w=500"}' \
  -o test_response.json

if [ $? -eq 0 ]; then
    echo "✅ Evaluate endpoint is working"
    echo "📄 Response saved to test_response.json"
    
    # Check if response contains expected fields
    if grep -q "recommendations" test_response.json; then
        echo "✅ Response contains recommendations"
    else
        echo "⚠️  Response might be incomplete"
    fi
else
    echo "❌ Evaluate endpoint failed"
    exit 1
fi

echo "�� All tests passed!" 