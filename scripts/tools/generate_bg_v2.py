"""
优化版：酒馆吧台背景生成 + 后处理
"""
import sys, requests, urllib.parse
from pathlib import Path
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')

OUTPUT_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures\backgrounds")
OUTPUT_PATH = OUTPUT_DIR / "tavern_bg.png"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# 精确的 B1 提示词
PROMPT = (
    "pixel art, dark fantasy tavern interior, behind the bar view, "
    "stone brick walls with two iron wall sconces glowing warm amber, "
    "wooden wine rack on back wall with colorful bottles amber red green, "
    "arched wooden door slightly open on the right, "
    "wide dark wood bartop counter across the bottom, "
    "warm amber candlelight from above, cool purple shadows below, "
    "Darkest Dungeon gothic style, cozy tavern, high contrast, "
    "no people, no text, no letters, retro game background"
)

encoded_prompt = urllib.parse.quote(PROMPT)

# 使用 flux 模型获取更好质量
url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1280&height=720&model=flux&nologo=true&seed=42"

print("=" * 50)
print("B1 Tavern Background Generation v2")
print(f"Model: flux, Target: 1280x720")
print("=" * 50)

try:
    print("\nGenerating...")
    response = requests.get(url, timeout=180)
    
    print(f"Status: {response.status_code}")
    print(f"Content-Type: {response.headers.get('Content-Type')}")
    print(f"Size: {len(response.content)} bytes")
    
    if response.status_code == 200 and len(response.content) > 1000:
        # Save raw response
        raw_path = OUTPUT_PATH.with_suffix('.raw')
        with open(raw_path, "wb") as f:
            f.write(response.content)
        
        img = Image.open(raw_path)
        print(f"Raw image: {img.format}, {img.mode}, {img.size}")
        
        # Convert to RGB and resize with NEAREST (preserves pixel art sharpness)
        img = img.convert('RGB')
        
        if img.size != (1280, 720):
            print(f"Resizing from {img.size} to (1280, 720) with NEAREST...")
            img = img.resize((1280, 720), Image.NEAREST)
        
        img.save(OUTPUT_PATH, 'PNG')
        raw_path.unlink()  # Remove raw file
        
        size_kb = OUTPUT_PATH.stat().st_size / 1024
        print(f"\n[SUCCESS] Saved: {OUTPUT_PATH}")
        print(f"  Size: {size_kb:.1f} KB | Dimensions: 1280x720 | Format: PNG-24")
    else:
        print(f"\n[FAIL] Unexpected response")
        if response.text:
            print(f"  Text: {response.text[:200]}")
            
except Exception as e:
    print(f"\n[ERROR] {e}")
