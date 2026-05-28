# -*- coding: utf-8 -*-
"""
批量生成美术资源脚本（本地 Stable Diffusion WebUI）
使用本地 API 调用 Stable Diffusion 生成像素风图片
"""

import json
import os
import requests
import time
from pathlib import Path

# 配置
API_BASE = "http://127.0.0.1:7860"
ASSETS_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")
MODEL_NAME = "pixel-art-xl.safetensors"

# 通用负面提示词
NEGATIVE_PROMPT = """3D render, realistic photo, photorealism, smooth gradients, anti-aliasing, blur, 
anime style, manga style, cartoon, modern architecture, neon lights, 
bright daylight, white background, text, watermark, signature, low quality, jpeg artifacts, 
distorted, deformed, blurry, out of focus"""

# 通用参数
DEFAULT_PARAMS = {
    "steps": 30,
    "cfg_scale": 7.0,
    "sampler_name": "Euler a",
    "batch_size": 1,
    "n_iter": 1,
    "seed": -1,
    "restore_faces": False,
    "tiling": False,
    "enable_hr": False,
    "denoising_strength": 0.75,
}

# 生成任务列表
TASKS = [
    # B1 酒馆吧台背景
    {
        "id": "B1",
        "name": "tavern_bg",
        "output": "backgrounds/tavern_bg.png",
        "width": 1280,
        "height": 720,
        "prompt": """Pixel art background, 1280x720, dark fantasy tavern interior — the view from behind the bar counter looking out.
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 400,
        "height": 500,
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
        "width": 64,
        "height": 64,
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
        "width": 64,
        "height": 64,
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
        "width": 64,
        "height": 64,
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
        "width": 64,
        "height": 64,
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
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A small bundle of fresh green leaves, 3-4 leaves tied together, visible leaf veins.
Fresh vibrant green color (#33B333).
Top lighting, highlight on upper leaves. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I6 麦芽酒
    {
        "id": "I6",
        "name": "ale_product",
        "output": "icons/products/ale.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A thick sturdy wooden beer mug overflowing with frothy foam spilling down the sides.
Amber-colored liquid (#ffbd7f) visible through the foam.
Wooden mug in dark brown (#5c3d2e).
Top lighting, highlight on foam top. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I7 葡萄酒
    {
        "id": "I7",
        "name": "wine_product",
        "output": "icons/products/wine.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
An elegant stemmed wine glass half-filled with deep red wine (#991A33).
Visible wine legs/tears on the inner glass wall.
Glass has subtle white reflection highlights.
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I8 面包
    {
        "id": "I8",
        "name": "bread_product",
        "output": "icons/products/bread.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A round rustic European country loaf with golden-brown crust (#B38C4D).
Cross-shaped scoring cut on top, revealing lighter inner crumb color (#e8c9a0).
Top lighting, highlight on the domed top. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I9 烤肉
    {
        "id": "I9",
        "name": "meat_product",
        "output": "icons/products/meat.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
Meat chunks skewered on an iron skewer, surface oily and golden-brown with slight charred edges.
Meat color (#A6331A), iron skewer in grey (#c0c8d0).
Small wisp of steam rising from hot meat.
Top lighting, slight oil gloss. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I10 草药茶
    {
        "id": "I10",
        "name": "herb_tea",
        "output": "icons/products/herb_tea.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A rustic clay/ceramic cup filled with green-tinted tea (#33B333).
A single fresh mint leaf resting on the cup rim as garnish.
Small steam wisp rising.
Clay cup in warm earthy brown.
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I11 草药麦酒
    {
        "id": "I11",
        "name": "herbal_ale",
        "output": "icons/products/herbal_ale.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A wooden beer mug with an herb leaf tucked diagonally at the rim.
Amber-green liquid (#ffbd7f mixed with #33B333).
Wooden mug in dark brown.
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I12 肉汤
    {
        "id": "I12",
        "name": "meat_stew",
        "output": "icons/products/meat_stew.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A small clay pot or deep bowl filled with rich brown meat stew.
Visible chunks of meat and carrot pieces floating in thick brown broth (#A6331A dominant).
Small steam wisps rising from the hot stew.
Clay pot in warm earthy brown.
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I13 肉夹面包
    {
        "id": "I13",
        "name": "meat_sand",
        "output": "icons/products/meat_sand.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
A rustic bread roll sliced in half horizontally, with thick slices of roasted meat sandwiched between.
A lettuce leaf peeking out from the side.
Bread in golden brown (#B38C4D), meat in red-brown (#A6331A), lettuce in green (#33B333).
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
    # I14 香料红酒
    {
        "id": "I14",
        "name": "spiced_wine",
        "output": "icons/products/spiced_wine.png",
        "width": 64,
        "height": 64,
        "prompt": """Pixel art item icon, 32x32 canvas for 2x export to 64x64.
An elegant wine glass with deep red wine (#991A33).
A cinnamon stick and a star anise pod floating/steeping inside the wine.
Glass has subtle white reflection highlights.
Top lighting. 1px dark outline (#0d0b0a).
Transparent background. RPG inventory icon style."""
    },
]

def check_webui_status():
    """检查 WebUI 状态"""
    try:
        r = requests.get(f"{API_BASE}/sdapi/v1/sd-models", timeout=5)
        if r.status_code == 200:
            models = r.json()
            print(f"[OK] WebUI 运行中，可用模型数量: {len(models)}")
            return True
        else:
            print(f"[ERR] WebUI 返回状态码: {r.status_code}")
            return False
    except Exception as e:
        print(f"[ERR] 无法连接到 WebUI: {e}")
        return False

def set_model(model_name):
    """设置使用的模型"""
    try:
        payload = {"sd_model_checkpoint": model_name}
        r = requests.post(f"{API_BASE}/sdapi/v1/options", json=payload, timeout=30)
        if r.status_code == 200:
            print(f"[OK] 模型已设置为: {model_name}")
            return True
        else:
            print(f"[ERR] 设置模型失败: {r.status_code}")
            return False
    except Exception as e:
        print(f"[ERR] 设置模型异常: {e}")
        return False

def generate_image(prompt, negative_prompt, width, height, output_path, **kwargs):
    """调用 WebUI API 生成图片"""
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        **DEFAULT_PARAMS,
        **kwargs
    }
    
    try:
        print(f"[INFO] 生成中: {output_path}")
        r = requests.post(f"{API_BASE}/sdapi/v1/txt2img", json=payload, timeout=300)
        
        if r.status_code == 200:
            data = r.json()
            if "images" in data and len(data["images"]) > 0:
                # 保存图片
                import base64
                image_data = base64.b64decode(data["images"][0])
                
                output_path = Path(output_path)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                with open(output_path, 'wb') as f:
                    f.write(image_data)
                
                print(f"[OK] 已保存: {output_path} ({len(image_data)/1024:.1f} KB)")
                return True
            else:
                print(f"[ERR] 返回数据中没有图片")
                return False
        else:
            print(f"[ERR] API 返回状态码: {r.status_code}")
            return False
    except Exception as e:
        print(f"[ERR] 生成异常: {e}")
        return False

def main():
    # 检查 WebUI 状态
    if not check_webui_status():
        print("[INFO] 请先启动 Stable Diffusion WebUI:")
        print('[INFO] cd "C:\\Users\\13422\\Desktop\\学习资料\\code\\IAmCBKing_r\\AIGImageTool\\stable-diffusion-webui"')
        print("[INFO] webui-user.bat --api")
        return
    
    # 设置模型
    if not set_model(MODEL_NAME):
        print(f"[WARN] 无法设置模型 {MODEL_NAME}，将使用默认模型")
    
    print(f"[INFO] 开始批量生成...")
    print(f"[INFO] 资源目录: {ASSETS_DIR}")
    print(f"[INFO] 总任务数: {len(TASKS)}")
    
    success_count = 0
    fail_count = 0
    
    for task in TASKS:
        task_id = task["id"]
        output_path = ASSETS_DIR / task["output"]
        
        # 检查是否已存在（可选择跳过或覆盖）
        if output_path.exists():
            print(f"[SKIP] {task_id} 已存在: {output_path}")
            success_count += 1
            continue
        
        # 生成图片
        prompt = task["prompt"] + "\n\npixel art style, dark fantasy tavern, warm amber lighting, deep purple shadows, no blur, no anti-aliasing, crisp pixel edges"
        
        if generate_image(
            prompt=prompt,
            negative_prompt=NEGATIVE_PROMPT,
            width=task["width"],
            height=task["height"],
            output_path=output_path
        ):
            success_count += 1
        else:
            fail_count += 1
        
        # 等待一下避免过载
        time.sleep(2)
    
    print(f"\n[DONE] 生成完成!")
    print(f"  成功: {success_count}")
    print(f"  失败: {fail_count}")

if __name__ == "__main__":
    main()