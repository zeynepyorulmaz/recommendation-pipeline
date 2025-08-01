import argparse
import json
from io import BytesIO
import numpy as np
import pillow_heif
import requests
import torch
import torch.nn as nn
from PIL import Image, ImageDraw, UnidentifiedImageError
from transformers import SegformerImageProcessor, AutoModelForSemanticSegmentation

def load_image(input_path, max_size=1024):
    if input_path.startswith(("http://", "https://")):
        resp = requests.get(input_path)
        resp.raise_for_status()
        data = BytesIO(resp.content)
        try:
            img = Image.open(data).convert("RGB")
        except UnidentifiedImageError:
            heif_file = pillow_heif.read_heif(data)
            img = Image.frombytes(
                heif_file.mode, heif_file.size, heif_file.data,
                "raw", heif_file.mode, heif_file.stride
            ).convert("RGB")
    else:
        img = Image.open(input_path).convert("RGB")
    if max(img.size) > max_size:
        ratio = max_size / max(img.size)
        img = img.resize(tuple(int(d * ratio) for d in img.size),
                         Image.Resampling.LANCZOS)
    return img

def calculate_iou(box1, box2):
    """Calculate Intersection over Union (IoU) of two bounding boxes."""
    x1_1, y1_1, x2_1, y2_1 = box1
    x1_2, y1_2, x2_2, y2_2 = box2
    
    # Calculate intersection
    x1_i = max(x1_1, x1_2)
    y1_i = max(y1_1, y1_2)
    x2_i = min(x2_1, x2_2)
    y2_i = min(y2_1, y2_2)
    
    if x2_i <= x1_i or y2_i <= y1_i:
        return 0.0
    
    intersection = (x2_i - x1_i) * (y2_i - y1_i)
    area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
    area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
    union = area1 + area2 - intersection
    
    return intersection / union if union > 0 else 0.0

def merge_overlapping_boxes(segments, iou_threshold=0.3):
    """Merge segments with overlapping bounding boxes."""
    if not segments:
        return segments
    
    merged = []
    used = set()
    
    for i, seg1 in enumerate(segments):
        if i in used:
            continue
            
        # Start with current segment
        merged_box = seg1["bbox"][:]
        merged_labels = [seg1["label"]]
        used.add(i)
        
        # Find overlapping segments
        for j, seg2 in enumerate(segments[i+1:], i+1):
            if j in used:
                continue
                
            iou = calculate_iou(merged_box, seg2["bbox"])
            if iou > iou_threshold:
                # Merge boxes by taking the union
                x1 = min(merged_box[0], seg2["bbox"][0])
                y1 = min(merged_box[1], seg2["bbox"][1])
                x2 = max(merged_box[2], seg2["bbox"][2])
                y2 = max(merged_box[3], seg2["bbox"][3])
                merged_box = [x1, y1, x2, y2]
                merged_labels.append(seg2["label"])
                used.add(j)
        
        merged.append({
            "label": merged_labels[0],  # Use first label
            "merged_labels": merged_labels,  # Keep track of all merged labels
            "bbox": merged_box
        })
    
    return merged

def filter_small_segments(segments, min_area=1000, image_size=None):
    """Filter out segments that are too small."""
    if image_size:
        # Calculate minimum area as percentage of image
        img_area = image_size[0] * image_size[1]
        min_area = max(min_area, img_area * 0.01)  # At least 1% of image
    
    filtered = []
    for seg in segments:
        x1, y1, x2, y2 = seg["bbox"]
        area = (x2 - x1) * (y2 - y1)
        if area >= min_area:
            filtered.append(seg)
    
    return filtered

def segment_image(image, processor, model):
    inputs = processor(images=image, return_tensors="pt")
    with torch.no_grad():
        logits = model(**inputs).logits.cpu()  # (1, C, H', W')
    up = nn.functional.interpolate(
        logits,
        size=image.size[::-1],
        mode="bilinear",
        align_corners=False,
    )[0]  # (C, H, W)
    mask = up.argmax(dim=0).numpy()  # (H, W)
    
    segments = []
    for cls in sorted(set(mask.flatten())):
        if cls == 0:  # Skip background
            continue
        ys, xs = np.where(mask == cls)
        if not len(xs):
            continue
        x1, y1, x2, y2 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
        segments.append({"label": int(cls), "bbox": [x1, y1, x2, y2]})
    
    return segments

def draw_boxes(image: Image.Image, segments: list[dict], outline="red", width=3):
    draw = ImageDraw.Draw(image)
    for seg in segments:
        x1, y1, x2, y2 = seg["bbox"]
        draw.rectangle([x1, y1, x2, y2], outline=outline, width=width)
    return image

def main():
    p = argparse.ArgumentParser("Segment image → write segments JSON + annotated image")
    p.add_argument("input", help="Image path or URL")
    p.add_argument(
        "--segments-json",
        required=True,
        help="Where to write the segments JSON",
    )
    p.add_argument(
        "--annotated-output", "-a",
        help="If set, save a copy of the image with boxes drawn here (e.g. annotated.png)"
    )
    p.add_argument(
        "--iou-threshold",
        type=float,
        default=0.3,
        help="IoU threshold for merging overlapping segments (default: 0.3)"
    )
    p.add_argument(
        "--min-area",
        type=int,
        default=1000,
        help="Minimum area for segments to keep (default: 1000 pixels)"
    )
    p.add_argument(
        "--no-merge",
        action="store_true",
        help="Skip merging overlapping segments"
    )
    p.add_argument(
        "--no-filter",
        action="store_true",
        help="Skip filtering small segments"
    )
    args = p.parse_args()

    # 1) load & resize
    img = load_image(args.input)
    print(f"📷 Loaded image: {img.size}")

    # 2) model
    proc = SegformerImageProcessor.from_pretrained("sayeed99/segformer-b3-fashion")
    mdl = AutoModelForSemanticSegmentation.from_pretrained(
        "sayeed99/segformer-b3-fashion"
    )

    # 3) segment
    segs = segment_image(img, proc, mdl)
    print(f"🔍 Found {len(segs)} initial segments")

    # 4) Filter small segments
    if not args.no_filter:
        segs = filter_small_segments(segs, args.min_area, img.size)
        print(f"🧹 After filtering small segments: {len(segs)}")

    # 5) Merge overlapping segments
    if not args.no_merge:
        segs = merge_overlapping_boxes(segs, args.iou_threshold)
        print(f"🔗 After merging overlapping segments: {len(segs)}")

    # 6) write JSON
    with open(args.segments_json, "w") as f:
        json.dump({"segments": segs}, f, indent=2)
    print(f"✅ Wrote {len(segs)} segments to {args.segments_json}")

    # 7) optionally draw & save
    if args.annotated_output:
        annotated = img.copy()
        draw_boxes(annotated, segs, outline="lime", width=2)
        annotated.save(args.annotated_output)
        print(f"✅ Saved annotated image with boxes to {args.annotated_output}")

if __name__ == "__main__":
    main()