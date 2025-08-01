import subprocess
import sys
import argparse
import json
import os
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# ─────────────────────────────────────────────────────────────
# Hard-coded output filenames
# ─────────────────────────────────────────────────────────────
SEGMENTS_JSON          = "segments.json"
GEMINI_RECOMMENDATIONS_JSON = "gemini_recommendations.json"
ANNOTATED_IMAGE_OUTPUT = "annotated.png"  # only this is hard-coded

def run_segmentation(input_path: str):
    subprocess.run([
        sys.executable, "segmentation.py",
        input_path,
        "--segments-json", SEGMENTS_JSON,
        "--annotated-output", ANNOTATED_IMAGE_OUTPUT
    ], check=True)
    print(f"✅ Segments written to {SEGMENTS_JSON}")
    print(f"✅ Annotated image saved to {ANNOTATED_IMAGE_OUTPUT}")

def run_gemini_recommendations(input_path: str):
    subprocess.run([
        sys.executable, "gemini_recommendations.py",
        "--input", input_path,
        "--segments-json", SEGMENTS_JSON,
        "--output", GEMINI_RECOMMENDATIONS_JSON
    ], check=True)
    print(f"✅ Gemini recommendations written to {GEMINI_RECOMMENDATIONS_JSON}")

def run_pipeline(input_path: str):
    """Run the complete pipeline and return results"""
    try:
        print("🎯 Starting Gemini pipeline...")
        print("Step 1: Running segmentation...")
        run_segmentation(input_path)
        
        print("Step 2: Getting Gemini recommendations...")
        run_gemini_recommendations(input_path)

        print("🚀 Gemini pipeline complete!")
        
        # Read and return the results
        results = {}
        
        # Read segments
        segments_data = {}
        if os.path.exists(SEGMENTS_JSON):
            with open(SEGMENTS_JSON, 'r', encoding='utf-8') as f:
                segments_data = json.load(f)
        
        # Read Gemini recommendations
        recommendations_data = {}
        if os.path.exists(GEMINI_RECOMMENDATIONS_JSON):
            with open(GEMINI_RECOMMENDATIONS_JSON, 'r', encoding='utf-8') as f:
                recommendations_data = json.load(f)
        
        # Return the exact same format as gemini_recommendations.py
        results = {}
        
        # Add individual segment recommendations
        if 'segments' in segments_data:
            processed_labels = set()
            for segment in segments_data['segments']:
                label = str(segment['label'])
                
                # Skip if we've already processed this label
                if label in processed_labels:
                    continue
                
                processed_labels.add(label)
                
                # Add recommendations if available
                if label in recommendations_data:
                    rec_data = recommendations_data[label]
                    results[label] = {
                        'type': rec_data.get('type', 'Unknown item'),
                        'bbox': segment['bbox'],
                        'recommendations': rec_data.get('recommendations', [])
                    }
        
        # Add overall outfit recommendations if available
        if 'overall_outfit' in recommendations_data:
            overall_data = recommendations_data['overall_outfit']
            results['overall_outfit'] = {
                'type': overall_data.get('type', 'Complete Outfit'),
                'recommendations': overall_data.get('recommendations', [])
            }
        
        # Add annotated image path if it exists
        if os.path.exists(ANNOTATED_IMAGE_OUTPUT):
            results['annotated_image'] = ANNOTATED_IMAGE_OUTPUT
        
        return results
        
    except Exception as e:
        print(f"❌ Pipeline failed: {e}")
        return {"error": str(e)}


@app.route('/evaluate', methods=['POST'])
def evaluate():
    """Evaluate endpoint for fashion analysis"""
    try:
        # Get input from request
        data = request.get_json()
        
        if not data or 'input_path' not in data:
            return jsonify({
                "error": "Missing 'input_path' in request body"
            }), 400
        
        input_path = data['input_path']
        
        # Validate input path
        if not input_path:
            return jsonify({
                "error": "Input path cannot be empty"
            }), 400
        
        # Run the pipeline
        results = run_pipeline(input_path)
        
        if "error" in results:
            return jsonify(results), 500
        
        return jsonify(results)
        
    except Exception as e:
        return jsonify({
            "error": f"Server error: {str(e)}"
        }), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "fashion-recommendation-pipeline"
    })


def main():
    p = argparse.ArgumentParser("Gemini pipeline: segment → gemini recommendations")
    p.add_argument(
        "--input", "-i",
        help="Path or URL of the input image (for CLI mode)"
    )
    p.add_argument(
        "--server", "-s",
        action="store_true",
        help="Run as Flask server instead of CLI"
    )
    p.add_argument(
        "--host",
        default="0.0.0.0",
        help="Host to bind the server to (default: 0.0.0.0)"
    )
    p.add_argument(
        "--port",
        type=int,
        default=5000,
        help="Port to bind the server to (default: 5000)"
    )
    args = p.parse_args()

    if args.server:
        print(f"🚀 Starting Flask server on {args.host}:{args.port}")
        print("📡 Available endpoints:")
        print("   - POST /evaluate - Analyze fashion image")
        print("   - GET  /health   - Health check")
        app.run(host=args.host, port=args.port, debug=False)
    else:
        if not args.input:
            print("❌ Error: --input is required when not running as server")
            sys.exit(1)
        
        print("🎯 Starting Gemini pipeline...")
        print("Step 1: Running segmentation...")
        run_segmentation(args.input)
        
        print("Step 2: Getting Gemini recommendations...")
        run_gemini_recommendations(args.input)

        print("🚀 Gemini pipeline complete!")
        print("📁 Output files:")
        print(f"   - Segments: {SEGMENTS_JSON}")
        print(f"   - Annotated image: {ANNOTATED_IMAGE_OUTPUT}")
        print(f"   - Gemini recommendations: {GEMINI_RECOMMENDATIONS_JSON}")

if __name__ == "__main__":
    main() 