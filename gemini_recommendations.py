import os
import json
import argparse
import base64
from io import BytesIO

import requests
from PIL import Image
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()

# Segmentation labels mapping
segmentation_labels = {
    "0": "Unlabelled", "1": "shirt, blouse", "2": "top, t-shirt, sweatshirt", "3": "sweater", 
    "4": "cardigan", "5": "jacket", "6": "vest", "7": "pants", "8": "shorts", "9": "skirt", 
    "10": "coat", "11": "dress", "12": "jumpsuit", "13": "cape", "14": "glasses", "15": "hat", 
    "16": "headband, head covering, hair accessory", "17": "tie", "18": "glove", "19": "watch", 
    "20": "belt", "21": "leg warmer", "22": "tights, stockings", "23": "sock", "24": "shoe", 
    "25": "bag, wallet", "26": "scarf", "27": "umbrella", "28": "hood", "29": "collar", 
    "30": "lapel", "31": "epaulette", "32": "sleeve", "33": "pocket", "34": "neckline", 
    "35": "buckle", "36": "zipper", "37": "applique", "38": "bead", "39": "bow", "40": "flower", 
    "41": "fringe", "42": "ribbon", "43": "rivet", "44": "ruffle", "45": "sequin", "46": "tassel"
}

# Initialize Gemini
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise RuntimeError("Please set GEMINI_API_KEY in your .env file")

genai.configure(api_key=api_key)
model = genai.GenerativeModel('gemini-1.5-flash')


def image_to_base64(image: Image.Image) -> str:
    """Convert PIL Image to base64 string"""
    buffer = BytesIO()
    image.save(buffer, format='JPEG', quality=85)
    img_str = base64.b64encode(buffer.getvalue()).decode()
    return img_str


def clean_unicode_text(text: str) -> str:
    """Clean Unicode characters and replace with ASCII equivalents"""
    # Replace common Unicode characters with ASCII equivalents
    replacements = {
        '\u2013': '-',  # en-dash
        '\u2014': '-',  # em-dash
        '\u2018': "'",  # left single quote
        '\u2019': "'",  # right single quote
        '\u201c': '"',  # left double quote
        '\u201d': '"',  # right double quote
        '\u2026': '...',  # ellipsis
        '\u00a0': ' ',  # non-breaking space
        '\u00b0': ' degrees',  # degree symbol
        '\u00ae': '(R)',  # registered trademark
        '\u2122': '(TM)',  # trademark
        '\u00a9': '(C)',  # copyright
    }
    
    for unicode_char, ascii_replacement in replacements.items():
        text = text.replace(unicode_char, ascii_replacement)
    
    # Remove any other non-ASCII characters
    text = ''.join(char for char in text if ord(char) < 128)
    
    return text


def get_gemini_recommendations(image: Image.Image, item_type: str) -> list[str]:
    """Get fashion recommendations from Gemini for a specific clothing item"""
    
    # Convert image to base64
    img_base64 = image_to_base64(image)
    
    prompt = f"""
    You are a fashion expert. Analyze this clothing item image and provide exactly 3 positive styling comments.
    
    Item type: {item_type}
    
    IMPORTANT: Focus on providing encouraging and positive styling advice regardless of image quality. Even with limited visual details, provide uplifting fashion comments based on the item type and any visible characteristics.
    
    Guidelines:
    - Provide exactly 3 positive and encouraging styling comments
    - Focus on the potential and versatility of this item type
    - Highlight styling opportunities and fashion possibilities
    - Use positive, uplifting language that celebrates personal style
    - Do not comment on image quality or request better images
    - Be encouraging and supportive even with limited visual information
    - Use only basic ASCII characters (a-z, A-Z, 0-9, spaces, and basic punctuation: . , ! ? - ' " ( ) )
    - Do not use any Unicode characters, emojis, or special symbols
    - Use regular hyphens (-) instead of en-dashes or em-dashes
    - Write in plain English with standard punctuation only
    
    Return your response as a JSON array with exactly 3 strings. For example:
    ["Comment 1", "Comment 2", "Comment 3"]
    
    Make sure your response is valid JSON and contains exactly 3 comments total.
    """
    
    try:
        # Create the image part for Gemini
        image_part = {
            "mime_type": "image/jpeg",
            "data": img_base64
        }
        
        response = model.generate_content([prompt, image_part])
        text = response.text.strip()
        
        # Clean Unicode characters from the response
        text = clean_unicode_text(text)
        
        # Try to parse as JSON
        try:
            # Remove any markdown formatting
            if text.startswith("```json"):
                text = text[7:]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()
            
            recommendations = json.loads(text)
            if isinstance(recommendations, list) and len(recommendations) >= 3:
                # Clean each recommendation
                cleaned_recommendations = [clean_unicode_text(rec) for rec in recommendations[:3]]
                return cleaned_recommendations
            else:
                raise ValueError("Response is not a list with at least 3 items")
                
        except (json.JSONDecodeError, ValueError):
            # Fallback: extract recommendations from text
            lines = [line.strip().strip('-•*').strip() for line in text.split('\n') if line.strip()]
            # Take first 3 non-empty lines that look like recommendations
            recommendations = []
            for line in lines:
                if len(line) > 10 and not line.startswith(('{', '[', ']', '}')):
                    recommendations.append(clean_unicode_text(line))
                if len(recommendations) >= 3:
                    break
            
            # If we don't have 3 recommendations, pad with generic ones
            while len(recommendations) < 3:
                recommendations.append(f"Consider pairing this {item_type} with complementary items for a complete look.")
            
            return recommendations[:3]
            
    except Exception as e:
        print(f"Error getting recommendations: {e}")
        return [
            f"This {item_type} offers wonderful styling versatility for any occasion!",
            f"The {item_type} can be beautifully paired with various complementary pieces to create stunning looks.",
            f"Accessorizing thoughtfully will elevate this {item_type} into a complete, polished ensemble."
        ]


def get_overall_outfit_recommendations(image: Image.Image, segments: list) -> list[str]:
    """Get overall outfit recommendations from Gemini for the complete look"""
    
    # Convert image to base64
    img_base64 = image_to_base64(image)
    
    # Get list of detected items
    detected_items = []
    for seg in segments:
        label = str(seg["label"])
        item_type = segmentation_labels.get(label, "Unknown item")
        detected_items.append(item_type)
    
    items_text = ", ".join(detected_items)
    
    prompt = f"""
    You are a fashion expert. Analyze this complete outfit image and provide exactly 3 positive overall styling comments.
    
    Detected items: {items_text}
    
    IMPORTANT: Focus on providing encouraging and positive overall outfit advice regardless of image quality. Even with limited visual details, provide uplifting fashion comments for the complete look.
    
    Guidelines:
    - Provide exactly 3 positive and encouraging overall outfit comments
    - Focus on how the items create a beautiful and cohesive look together
    - Celebrate the style choices and fashion sense shown
    - Highlight the versatility and potential of this outfit combination
    - Use positive, uplifting language that celebrates personal style
    - Do not comment on image quality or request better images
    - Be encouraging and supportive even with limited visual information
    - Use only basic ASCII characters (a-z, A-Z, 0-9, spaces, and basic punctuation: . , ! ? - ' " ( ) )
    - Do not use any Unicode characters, emojis, or special symbols
    - Use regular hyphens (-) instead of en-dashes or em-dashes
    - Write in plain English with standard punctuation only
    
    Return your response as a JSON array with exactly 3 strings. For example:
    ["Comment 1", "Comment 2", "Comment 3"]
    
    Make sure your response is valid JSON and contains exactly 3 comments total.
    """
    
    try:
        # Create the image part for Gemini
        image_part = {
            "mime_type": "image/jpeg",
            "data": img_base64
        }
        
        response = model.generate_content([prompt, image_part])
        text = response.text.strip()
        
        # Clean Unicode characters from the response
        text = clean_unicode_text(text)
        
        # Try to parse as JSON
        try:
            # Remove any markdown formatting
            if text.startswith("```json"):
                text = text[7:]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()
            
            recommendations = json.loads(text)
            if isinstance(recommendations, list) and len(recommendations) >= 3:
                # Clean each recommendation
                cleaned_recommendations = [clean_unicode_text(rec) for rec in recommendations[:3]]
                return cleaned_recommendations
            else:
                raise ValueError("Response is not a list with at least 3 items")
                
        except (json.JSONDecodeError, ValueError):
            # Fallback: extract recommendations from text
            lines = [line.strip().strip('-•*').strip() for line in text.split('\n') if line.strip()]
            # Take first 3 non-empty lines that look like recommendations
            recommendations = []
            for line in lines:
                if len(line) > 10 and not line.startswith(('{', '[', ']', '}')):
                    recommendations.append(clean_unicode_text(line))
                if len(recommendations) >= 3:
                    break
            
            # If we don't have 3 recommendations, pad with generic ones
            while len(recommendations) < 3:
                recommendations.append("The overall color palette and style create a beautiful, cohesive look that showcases great fashion sense.")
            
            return recommendations[:3]
            
    except Exception as e:
        print(f"Error getting overall recommendations: {e}")
        return [
            "This outfit creates a beautiful, cohesive look that showcases excellent fashion sense!",
            "The individual pieces complement each other beautifully, creating a harmonious and stylish ensemble.",
            "The overall ensemble works wonderfully together and can be elevated with thoughtful accessories to create a complete, polished look."
        ]


def analyze_segments_with_gemini(image_url: str, segments: list, output_path: str):
    """Analyze segments and get recommendations directly from Gemini"""
    
    # Download the full image
    print(f"📥 Downloading image from {image_url}...")
    resp = requests.get(image_url)
    resp.raise_for_status()
    full_img = Image.open(BytesIO(resp.content)).convert("RGB")
    
    result = {}
    
    for i, seg in enumerate(segments):
        label = str(seg["label"])
        item_type = segmentation_labels.get(label, "Unknown item")
        x1, y1, x2, y2 = seg["bbox"]
        
        print(f"🔍 Analyzing segment {i+1}/{len(segments)}: {item_type} (label {label})...")
        
        # Crop the segment
        crop = full_img.crop((x1, y1, x2, y2))
        
        # Get recommendations from Gemini
        recommendations = get_gemini_recommendations(crop, item_type)
        
        result[label] = {
            "type": item_type,
            "bbox": seg["bbox"],
            "recommendations": recommendations
        }
        
        print(f"✅ Segment {label}: {item_type}")
        for j, rec in enumerate(recommendations, 1):
            print(f"   {j}. {rec}")
        print()
    
    # Get overall outfit recommendations
    print("🎯 Analyzing complete outfit...")
    overall_recommendations = get_overall_outfit_recommendations(full_img, segments)
    result["overall_outfit"] = {
        "type": "Complete Outfit",
        "recommendations": overall_recommendations
    }
    
    print("✅ Overall outfit analysis:")
    for j, rec in enumerate(overall_recommendations, 1):
        print(f"   {j}. {rec}")
    print()
    
    # Save results
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    
    print(f"✅ Saved recommendations to {output_path}")


def main():
    parser = argparse.ArgumentParser("Get fashion recommendations from Gemini using segmentation")
    parser.add_argument("--input", required=True, help="Image URL or path")
    parser.add_argument("--segments-json", required=True, help="Path to segments JSON file")
    parser.add_argument("--output", "-o", default="gemini_recommendations.json", help="Output JSON file")
    args = parser.parse_args()
    
    # Load segments
    with open(args.segments_json, "r", encoding="utf-8") as f:
        data = json.load(f)
    segments = data.get("segments", [])
    
    if not segments:
        print("❌ No segments found in the JSON file")
        return
    
    print(f"🎯 Found {len(segments)} segments to analyze")
    
    # Analyze segments with Gemini
    analyze_segments_with_gemini(args.input, segments, args.output)


if __name__ == "__main__":
    main() 