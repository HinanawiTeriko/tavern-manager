# -*- coding: utf-8 -*-
"""
P1优先级美术资源生成脚本
调用本地pixel-art-xl模型批量生成资源
"""

import requests
import base64
import time
import os
from pathlib import Path

# 配置
API_BASE = "http://127.0.0.1:7860"
OUTPUT_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")

# 创建输出目录
for subdir in ["backgrounds", "characters", "icons/map", "ui"]:
    (OUTPUT_DIR / subdir).mkdir(parents=True, exist_ok=True)

# 通用负面提示词
NEGATIVE = """3D render, realistic photo, smooth gradients, anti-aliasing, blur, 
anime style, manga style, cartoon, modern architecture, neon lights, 
bright daylight, white background, text, watermark, signature, low quality, jpeg artifacts, 
distorted, deformed, blurry, out of focus, gradient, soft edges"""

def generate_image(prompt, output_path, width=512, height=512):
    """调用WebUI API生成图片"""
    payload = {
        "prompt": prompt,
        "negative_prompt": NEGATIVE,
        "width": width,
        "height": height,
        "steps": 30,
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
        print(f"[生成中] {output_path.name} ({width}x{height})...")
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

print("=" * 60)
print("  P1优先级美术资源生成脚本")
print("  模型: pixel-art-xl")
print("=" * 60)
print()

# 设置模型
print("[INFO] 设置模型为 pixel-art-xl...")
try:
    payload = {"sd_model_checkpoint": "pixel-art-xl.safetensors"}
    r = requests.post(f"{API_BASE}/sdapi/v1/options", json=payload, timeout=30)
    if r.status_code == 200:
        print("[OK] 模型设置成功")
    else:
        print(f"[WARN] 模型设置失败，将使用当前模型")
except Exception as e:
    print(f"[WARN] 无法设置模型: {e}")

time.sleep(2)

print("\n[INFO] 开始生成P1优先级资源...\n")

# ===== 1. 背景类 =====
print("=== 背景类 ===")

# D1 - 地牢地图背景
generate_image(
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
    output_path=OUTPUT_DIR / "backgrounds" / "daymap_bg.png",
    width=1280,
    height=720
)
time.sleep(3)

# E1 - 结局画面背景
generate_image(
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
    output_path=OUTPUT_DIR / "backgrounds" / "ending_bg.png",
    width=1280,
    height=720
)
time.sleep(3)

# ===== 2. 角色类 =====
print("\n=== 角色类 ===")

# C11a - 战士
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male warrior head,
iron helmet visor, thick beard, rugged weathered face,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes,
simple identifiable forms, 8-bit style""",
    output_path=OUTPUT_DIR / "characters" / "guest_warrior.png",
    width=72,
    height=72
)
time.sleep(2)

# C11b - 法师
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male mage head,
pointed wizard hat, long white beard,
mysterious look, magical aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    output_path=OUTPUT_DIR / "characters" / "guest_mage.png",
    width=72,
    height=72
)
time.sleep(2)

# C11c - 盗贼
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, rogue character head,
hood pulled low, cloth mask covering lower face,
cunning eyes visible, stealthy look,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    output_path=OUTPUT_DIR / "characters" / "guest_rogue.png",
    width=72,
    height=72
)
time.sleep(2)

# C11d - 弓箭手
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, archer character head,
feathered cap/hat, pointed elf-like ears,
sharp keen gaze, focused expression,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    output_path=OUTPUT_DIR / "characters" / "guest_archer.png",
    width=72,
    height=72
)
time.sleep(2)

# C11e - 牧师
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, cleric character head,
bald or short-cropped hair, holy symbol pendant,
kind gentle face, healing aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    output_path=OUTPUT_DIR / "characters" / "guest_cleric.png",
    width=72,
    height=72
)
time.sleep(2)

# C11f - 野蛮人
generate_image(
    prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, barbarian character head,
wild unkempt hair, war paint stripes on face,
animal fur cloak visible on shoulders,
fierce look, battle-scarred,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
    output_path=OUTPUT_DIR / "characters" / "guest_barbarian.png",
    width=72,
    height=72
)
time.sleep(2)

# ===== 3. 采集点图标 =====
print("\n=== 采集点图标 ===")

# D2a - 蘑菇
generate_image(
    prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
cluster of glowing mushrooms,
caps emitting faint blue-white light,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
    output_path=OUTPUT_DIR / "icons" / "map" / "icon_mushroom.png",
    width=48,
    height=48
)
time.sleep(2)

# D2b - 矿道
generate_image(
    prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
two crossed pickaxes with chunk of dark ore,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
    output_path=OUTPUT_DIR / "icons" / "map" / "icon_mine.png",
    width=48,
    height=48
)
time.sleep(2)

print(f"\n{'='*60}")
print("[DONE] P1优先级资源生成完成!")
print(f"生成位置: {OUTPUT_DIR}")
print(f"{'='*60}")
print("\n提示:")
print("1. 小尺寸图标可能需要手动调整")
print("2. 建议使用Aseprite进行像素级优化")
print("3. 确保所有资源符合技术规范（色板、描边等）")
