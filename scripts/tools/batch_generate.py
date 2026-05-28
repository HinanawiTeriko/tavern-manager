# -*- coding: utf-8 -*-
"""
批量生成美术资源脚本
使用 buddy-cloud.py 调用腾讯混元生图 API
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

# 配置
SCRIPT_DIR = Path(r"d:\program\CodeBuddy CN\resources\app\extensions\genie\out\extension\builtin\buddy-multimodal-generation\scripts")
BUDDY_CLOUD = SCRIPT_DIR / "buddy-cloud.py"
PYTHON = r"C:\Users\13422\.workbuddy\binaries\python\versions\3.11.9\python.exe"
ASSETS_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")

# Token (从 connect_cloud_service 获取)
TOKEN = os.environ.get("BUDDY_CLOUD_TOKEN", "")

# 通用后缀
COMMON_SUFFIX = """
pixel art style, dark fantasy tavern, warm amber lighting, deep purple shadows, 
low saturation background, high contrast foreground, Darkest Dungeon meets VA-11 Hall-A aesthetic,
no blur, no anti-aliasing, crisp pixel edges
Negative prompt: 3D render, realistic photo, photorealism, smooth gradients, anti-aliasing, blur, 
anime style, manga style, cartoon, modern architecture, neon lights, 
bright daylight, white background, text, watermark, signature, low quality, jpeg artifacts
"""

# 生成任务列表
TASKS = [
    # B1 酒馆吧台背景
    {
        "id": "B1",
        "name": "tavern_bg",
        "output": "backgrounds/tavern_bg.png",
        "prompt": """Pixel art background, 1280x720. Dark fantasy tavern interior — the view from behind the bar counter looking out.
Top section (upper 200px): rough stone brick wall in deep grey-purple (#1a1518~#231f1d), 
two iron wall sconces on the left emitting warm amber candlelight (#ffbd7f) with ~80px radius glow, 
an arched wooden door slightly open on the center-right revealing faint light, 
dark aged wooden ceiling beams (#2e2927) with visible wood grain.
Middle section (y:200-440): wooden wine rack with 4-5 shelves behind the bar, 
colored bottle silhouettes in amber/deep-red/green, a worn shield or old map hanging on the right wall.
Mid-lower section (y:440-505): wide thick dark wood bartop counter stretching across the full width (#2e2927 base + #554334 wood grain), ~60px tall.
Bottom section (y:505-720): vertical wood plank front of the bar counter in darker tone (#231f1d), 
with a recessed dark groove area at the very bottom (y:675-720).
Lighting: main warm amber light (#ffbd7f) from upper-left sconces + overhead hanging lamp (off-screen).
Lower bar area has cool purple shadows (#1a151c) creating warm-cool contrast. Wine rack area is dim, bottles have small highlight reflections.
No characters. No text. Low saturation overall. High contrast between lit and shadow areas."""
    },
    # C1 莱恩主立绘
    {
        "id": "C1",
        "name": "ryan_neutral",
        "output": "characters/ryan_neutral.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500. 
Full body standing portrait, front-facing, slight 3/4 angle.
Young male knight, age 18-20. Lean build, not yet fully developed warrior physique.
Short messy brown hair (#6b4c3b), a few stray locks on forehead.
Bright blue-grey eyes (#7b9eb3), clear and earnest gaze.
Slight confident smile, mouth corners slightly upturned.
Silver light armor — not full plate, but leather base with metal shoulder pauldrons and chest plates (#c0c8d0).
Dark blue cloth (#2a3a4a) visible underneath the armor.
Long sword resting on right shoulder (not drawn from sheath), held casually.
Light skin tone (#e8c9a0), youthful.
Relaxed but upright standing posture, shoulders back.
Top-down warm lighting, highlight on top of head and shoulders.
Dark 2px outer outline (#0d0b0a). Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C2 莱恩坚定
    {
        "id": "C2",
        "name": "ryan_determined",
        "output": "characters/ryan_determined.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500. 
Full body standing portrait, front-facing, slight 3/4 angle.
Young male knight, age 18-20. Lean build. Short messy brown hair (#6b4c3b).
Bright blue-grey eyes (#7b9eb3). Silver light armor with dark blue cloth underneath.
Expression: broader confident smile, eyebrows slightly furrowed with determination.
Right hand gripping the sword hilt (still sheathed). Eyes brighter, more intense. Jaw slightly clenched.
Light skin tone (#e8c9a0). Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C3 莱恩忧虑
    {
        "id": "C3",
        "name": "ryan_worried",
        "output": "characters/ryan_worried.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500. 
Full body standing portrait, front-facing, slight 3/4 angle.
Young male knight, age 18-20. Lean build. Short messy brown hair (#6b4c3b).
Blue-grey eyes (#7b9eb3). Silver light armor with dark blue cloth underneath.
Expression: eyebrows tightly knit with worry, lips pressed into a thin line.
Eyes looking downward, avoiding eye contact. Shoulders slightly hunched inward.
Dimmer eye highlight, less confident posture. Light skin tone (#e8c9a0).
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C4 莱恩崩坏
    {
        "id": "C4",
        "name": "ryan_broken",
        "output": "characters/ryan_broken.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500. 
Full body standing portrait, front-facing, slight 3/4 angle.
Young male knight, age 18-20. Lean build. Short messy brown hair (#6b4c3b).
Blue-grey eyes (#7b9eb3). Silver light armor with dark blue cloth underneath.
Expression: eyes hollow and unfocused, eyelids half-lowered, vacant stare.
Mouth corners drooping downward. Head slightly lowered.
A faint shadow or tear-streak mark under one eye. Darkened overall, gloomier.
Light skin tone (#e8c9a0). Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C5 米拉主立绘
    {
        "id": "C5",
        "name": "mira_neutral",
        "output": "characters/mira_neutral.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500.
Full body standing portrait, front-facing, slight 3/4 angle.
Female traveling merchant, age 25-28. Medium build, capable and lean.
Dark brown hair (#4a3020) tied in a high ponytail, a few loose strands near ears.
Sharp amber eyes (#c89040), slightly narrow and keen, looking directly at viewer.
Professional slight smile — polite but reserved, mouth corners slightly up, not showing teeth.
One hand resting on hip.
Dark brown leather vest (#5c3d2e) over a cream-colored linen shirt (#d4c5a9).
Multi-pocket utility belt worn diagonally across waist, with small pouches and scrolls hanging from it.
Large leather travel bag slung over right shoulder.
Light wheat-tone skin (#d4b896).
Top-down warm lighting, highlight on top of ponytail and shoulders.
Dark 2px outer outline (#0d0b0a). Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C6 米拉微笑
    {
        "id": "C6",
        "name": "mira_smile",
        "output": "characters/mira_smile.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500.
Full body standing portrait. Female traveling merchant, age 25-28.
Dark brown high ponytail (#4a3020). Sharp amber eyes (#c89040).
Dark brown leather vest (#5c3d2e) over cream linen shirt (#d4c5a9). Utility belt, travel bag.
Expression: genuine warm smile — eye corners slightly crinkled, mouth naturally upturned.
Warmer, more open feeling. Light wheat-tone skin (#d4b896).
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C7 米拉惊讶
    {
        "id": "C7",
        "name": "mira_surprised",
        "output": "characters/mira_surprised.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500.
Full body standing portrait. Female traveling merchant, age 25-28.
Dark brown high ponytail (#4a3020). Sharp amber eyes (#c89040).
Dark brown leather vest (#5c3d2e) over cream linen shirt (#d4c5a9). Utility belt, travel bag.
Expression: eyebrows raised high, eyes slightly widened, mouth slightly open in surprise.
Head tilted back very slightly. Light wheat-tone skin (#d4b896).
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # C8 米拉严肃
    {
        "id": "C8",
        "name": "mira_serious",
        "output": "characters/mira_serious.png",
        "prompt": """Pixel art character sprite, 200x250 canvas for 2x export to 400x500.
Full body standing portrait. Female traveling merchant, age 25-28.
Dark brown high ponytail (#4a3020). Sharp amber eyes (#c89040).
Dark brown leather vest (#5c3d2e) over cream linen shirt (#d4c5a9). Utility belt, travel bag.
Expression: no smile, eyebrows slightly furrowed, direct intense stare at viewer.
Mouth closed in a firm line. Serious, business-like demeanor.
Light wheat-tone skin (#d4b896).
Top-down warm lighting. Dark 2px outline. Transparent background.
Darkest Dungeon character portrait style."""
    },
    # I1 麦芽
    {
        "id": "I1",
        "name": "ale_material",
        "output": "icons/materials/ale.png",
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A bundle of golden wheat/barley stalks, 3-4 stalks tied together with twine.
Ripe heavy grain heads drooping downward naturally.
Warm amber-gold color (#ffbd7f).
Top lighting, highlight on upper grains. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I2 葡萄
    {
        "id": "I2",
        "name": "wine_material",
        "output": "icons/materials/wine.png",
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A small cluster of deep purple grapes, 3-5 berries, with a short vine tendril and one green leaf attached.
Deep purple-red color (#991A33) for grapes, muted green for leaf.
Top lighting, small highlight on top berry. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I3 面粉
    {
        "id": "I3",
        "name": "bread_material",
        "output": "icons/materials/bread.png",
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A small burlap sack tied at the top with rope, a few white powder particles leaking from the opening.
Warm brown sack color (#B38C4D), white powder (#eae1dd).
Top lighting, highlight on top of sack. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I4 生肉
    {
        "id": "I4",
        "name": "meat_material",
        "output": "icons/materials/meat.png",
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A T-bone cut of raw meat — pinkish-red meat cross-section (#A6331A) with white bone cross-section in center.
Meat has visible marbling. Classic steakhouse T-bone shape.
Top lighting, slight gloss on meat surface. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I5 草药
    {
        "id": "I5",
        "name": "herb_material",
        "output": "icons/materials/herb.png",
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A small bundle of fresh green leaves, 3-4 leaves tied together, visible leaf veins.
Fresh vibrant green color (#33B333).
Top lighting, highlight on upper leaves. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
]

def run_buddy_cloud(prompt, output_path):
    """调用 buddy-cloud.py 生成图片"""
    cmd = [
        PYTHON,
        str(BUDDY_CLOUD),
        "image",
        prompt,
        "--token", TOKEN
    ]
    
    print(f"[INFO] Generating {output_path}...")
    
    # 重试机制，等待并发槽位释放
    max_retries = 5
    for retry in range(max_retries):
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            print(f"[ERR] Failed: {result.stderr}")
            return None
        
        # 解析 JSON 输出
        try:
            output = result.stdout
            json_start = output.find('{')
            if json_start == -1:
                print(f"[ERR] No JSON in output: {output[:200]}")
                return None
            
            data = json.loads(output[json_start:])
            
            # 检查是否是并发限制错误
            if "concurrent slot limit exceeded" in str(data):
                wait_time = 10 * (retry + 1)
                print(f"[WARN] Concurrent limit hit, waiting {wait_time}s... (retry {retry+1}/{max_retries})")
                time.sleep(wait_time)
                continue
            
            if data.get("status") == "DONE" and data.get("result_url"):
                return data["result_url"][0] if isinstance(data["result_url"], list) else data["result_url"]
            else:
                print(f"[ERR] Job not done: {data}")
                return None
        except Exception as e:
            print(f"[ERR] Parse error: {e}")
            return None
    
    print(f"[ERR] Max retries reached")
    return None

def download_image(url, save_path):
    """下载图片"""
    import requests
    
    save_path = Path(save_path)
    save_path.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"[INFO] Downloading to {save_path}...")
    resp = requests.get(url, timeout=60)
    
    if resp.status_code == 200:
        with open(save_path, 'wb') as f:
            f.write(resp.content)
        print(f"[OK] Saved: {save_path} ({len(resp.content)/1024:.1f} KB)")
        return True
    else:
        print(f"[ERR] HTTP {resp.status_code}")
        return False

def main():
    if not TOKEN:
        print("[ERR] No token set. Please set BUDDY_CLOUD_TOKEN environment variable.")
        return
    
    print(f"[INFO] Starting batch generation...")
    print(f"[INFO] Assets dir: {ASSETS_DIR}")
    print(f"[INFO] Total tasks: {len(TASKS)}")
    
    success_count = 0
    fail_count = 0
    
    for task in TASKS:
        task_id = task["id"]
        output_path = ASSETS_DIR / task["output"]
        
        # 检查是否已存在
        if output_path.exists():
            print(f"[SKIP] {task_id} already exists: {output_path}")
            success_count += 1
            continue
        
        # 生成图片
        prompt = task["prompt"] + COMMON_SUFFIX
        url = run_buddy_cloud(prompt, task["output"])
        
        if url:
            if download_image(url, output_path):
                success_count += 1
            else:
                fail_count += 1
        else:
            fail_count += 1
        
        # 等待一下避免限流
        time.sleep(2)
    
    print(f"\n[DONE] Generation complete!")
    print(f"  Success: {success_count}")
    print(f"  Failed: {fail_count}")

if __name__ == "__main__":
    main()
