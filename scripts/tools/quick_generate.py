# -*- coding: utf-8 -*-
"""
快速生成P1资源 - 直接调用WebUI API
"""

import requests
import json
import base64
import time
from pathlib import Path
import os

API_BASE = "http://127.0.0.1:7860"
OUTPUT_BASE = r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures"

# 确保所有目录存在
dirs = [
    "backgrounds",
    "characters", 
    "icons/map",
    "ui"
]

for d in dirs:
    Path(os.path.join(OUTPUT_BASE, d)).mkdir(parents=True, exist_ok=True)

def set_model(model_name):
    """设置模型"""
    try:
        payload = {"sd_model_checkpoint": model_name}
        r = requests.post(f"{API_BASE}/sdapi/v1/options", json=payload, timeout=30)
        if r.status_code == 200:
            print(f"[OK] 模型已设置为: {model_name}")
            return True
        else:
            print(f"[WARN] 设置模型失败: {r.status_code}, 将使用当前模型")
            return False
    except Exception as e:
        print(f"[WARN] 设置模型异常: {e}")
        return False

def generate(prompt, negative_prompt, width, height, output_path, steps=30):
    """生成单张图片"""
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": steps,
        "cfg_scale": 7.5,
        "sampler_name": "Euler a",
        "batch_size": 1,
        "n_iter": 1,
        "seed": -1,
        "restore_faces": False,
        "tiling": False,
        "enable_hr": False
    }
    
    try:
        print(f"\n[生成中] {output_path} ({width}x{height})...")
        r = requests.post(f"{API_BASE}/sdapi/v1/txt2img", json=payload, timeout=600)
        
        if r.status_code == 200:
            data = r.json()
            if "images" in data and len(data["images"]) > 0:
                image_data = base64.b64decode(data["images"][0])
                
                with open(output_path, 'wb') as f:
                    f.write(image_data)
                
                print(f"[OK] 已保存: {output_path} ({len(image_data)/1024:.1f} KB)")
                return True
            else:
                print(f"[ERR] 返回数据中没有图片")
                return False
        else:
            print(f"[ERR] API 返回状态码: {r.status_code}")
            print(f"[ERR] 响应: {r.text[:200]}")
            return False
    except Exception as e:
        print(f"[ERR] 生成异常: {e}")
        return False

# 通用负面提示词
NEG = """3D render, realistic photo, smooth gradients, anti-aliasing, blur, 
anime style, manga style, cartoon, modern architecture, neon lights, 
bright daylight, white background, text, watermark, signature, low quality, jpeg artifacts, 
distorted, deformed, blurry, out of focus, gradient, soft edges"""

print("=" * 60)
print("  P1优先级美术资源批量生成")
print("=" * 60)

# 设置模型
set_model("pixel-art-xl.safetensors")
time.sleep(2)

print(f"\n[INFO] 开始生成...\n")

# 1. 背景 - D1 地牢地图
generate(
    prompt="""pixel art, crudely drawn MS Paint style, 
dungeon map on parchment paper, 1280x720,
flat parchment base (#D0C8B8), 
pixelated jagged torn edges,
Five labeled locations connected by dotted pixel paths:
mushroom grotto top left, abandoned mine tunnel top center,
underground river right, grape vine terrace bottom left,
underground farm mill bottom right,
Dark ink lines (#403020) on parchment,
pixel compass rose decoration in corner,
limited color palette, flat colors,
1px black outlines (#000000),
chunky pixel shapes, simple identifiable forms,
no UI elements, no gradient, no soft blur""",
    negative_prompt=NEG,
    width=1280,
    height=720,
    output_path=os.path.join(OUTPUT_BASE, "backgrounds", "daymap_bg.png")
)

time.sleep(3)

# 2. 背景 - E1 结局画面
generate(
    prompt="""pixel art, crudely drawn MS Paint style,
closed tavern after hours, 1280x720,
same stone and wood tavern interior,
using deeper dark colors (#1E1814 dominant),
heavy closed ledger book on bartop center-bottom,
flat amber (#E8A040) decorative pattern on cover,
wall sconces as dark flat blocks (extinguished),
light from above center as subtle brighter pixel tones,
quiet, contemplative, end-of-journey mood,
limited color palette, flat colors,
1px black outlines (#000000),
chunky pixel shapes, simple identifiable forms,
no gradient, no soft glow, no characters""",
    negative_prompt=NEG,
    width=1280,
    height=720,
    output_path=os.path.join(OUTPUT_BASE, "backgrounds", "ending_bg.png")
)

time.sleep(3)

# 3. 角色 - C11a 战士
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male warrior head,
iron helmet visor, thick beard, rugged weathered face,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes,
simple identifiable forms, 8-bit style""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_warrior.png")
)

time.sleep(2)

# 4. 角色 - C11b 法师
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male mage head,
pointed wizard hat, long white beard,
mysterious look, magical aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_mage.png")
)

time.sleep(2)

# 5. 角色 - C11c 盗贼
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, rogue character head,
hood pulled low, cloth mask covering lower face,
cunning eyes visible, stealthy look,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_rogue.png")
)

time.sleep(2)

# 6. 角色 - C11d 弓箭手
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, archer character head,
feathered cap/hat, pointed elf-like ears,
sharp keen gaze, focused expression,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_archer.png")
)

time.sleep(2)

# 7. 角色 - C11e 牧师
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, cleric character head,
bald or short-cropped hair, holy symbol pendant,
kind gentle face, healing aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_cleric.png")
)

time.sleep(2)

# 8. 角色 - C11f 野蛮人
generate(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, barbarian character head,
wild unkempt hair, war paint stripes on face,
animal fur cloak visible on shoulders,
fierce look, battle-scarred,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    negative_prompt=NEG,
    width=72,
    height=72,
    output_path=os.path.join(OUTPUT_BASE, "characters", "guest_barbarian.png")
)

time.sleep(2)

# 9. 采集点图标 - D2a 蘑菇
generate(
    prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
cluster of glowing mushrooms,
caps emitting faint blue-white light,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
    negative_prompt=NEG,
    width=48,
    height=48,
    output_path=os.path.join(OUTPUT_BASE, "icons", "map", "icon_mushroom.png")
)

print(f"\n{'='*60}")
print("[DONE] P1核心资源生成完成!")
print(f"{'='*60}")
print("\n提示: 图标类资源建议手动调整，AI生成的小尺寸图标可能不够清晰")
