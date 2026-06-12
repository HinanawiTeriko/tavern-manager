"""Generate desk overlay via local SD WebUI API"""
import requests, base64, io, sys
from PIL import Image

OUTPUT = r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures\workspace\desk_overlay.png"
API = "http://127.0.0.1:7860"

print("Connecting to SD WebUI...")
try:
    r = requests.get(f"{API}/sdapi/v1/sd-models", timeout=10)
    print(f"WebUI status: {r.status_code}")
except Exception as e:
    print(f"WebUI not available: {e}")
    sys.exit(1)

PROMPT = (
    "oblique front top-down view of a vintage wooden bar counter surface, "
    "antique oak wood planks, warm amber brown tones, visible wood grain texture, "
    "slightly weathered and aged, clean empty surface, 2D game background art, "
    "tavern bar desk, no objects, seamless wood texture"
)
NEGATIVE = (
    "characters, people, items, bottles, glasses, food, modern, "
    "realistic photo, 3D render, blur, furniture, wall, ceiling, bright colors"
)

print("Generating image (1024x576, 20 steps)...")
payload = {
    "prompt": PROMPT,
    "negative_prompt": NEGATIVE,
    "width": 1024,
    "height": 576,
    "steps": 20,
    "cfg_scale": 7.5,
    "sampler_name": "Euler a",
    "batch_size": 1,
}

try:
    r = requests.post(f"{API}/sdapi/v1/txt2img", json=payload, timeout=600)
    if r.status_code != 200:
        print(f"API error: {r.status_code} - {r.text[:500]}")
        sys.exit(1)
    data = r.json()
    img_data = base64.b64decode(data["images"][0])
    img = Image.open(io.BytesIO(img_data))
    print(f"Generated: {img.size}")
    
    # Crop center strip: 960x256
    crop_x = (1024 - 960) // 2
    crop_y = (576 - 256) // 2
    cropped = img.crop((crop_x, crop_y, crop_x + 960, crop_y + 256))
    cropped.save(OUTPUT)
    print(f"Cropped to {cropped.size}, saved to: {OUTPUT}")
except Exception as e:
    print(f"Generation failed: {e}")
    sys.exit(1)
