# -*- coding: utf-8 -*-
"""
批量生成P1优先级美术资源脚本（本地 Stable Diffusion WebUI）
基于AI提示词文件生成所有P1优先级美术资源
"""

import json
import os
import requests
import time
import base64
from pathlib import Path

# 配置
API_BASE = "http://127.0.0.1:7860"
ASSETS_DIR = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")
MODEL_NAME = "pixel-art-xl.safetensors"

# 通用负面提示词
NEGATIVE_PROMPT = """3D render, realistic photo, smooth gradients, anti-aliasing, blur, 
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

# P1优先级生成任务列表
TASKS = [
    # ========== 背景类 (2个) ==========
    {
        "id": "D1",
        "name": "daymap_bg",
        "output": "backgrounds/daymap_bg.png",
        "width": 1280,
        "height": 720,
        "prompt": """pixel art, crudely drawn MS Paint style, 
dungeon map on parchment paper, 1280x720,
flat parchment base (#D0C8B8), 
pixelated jagged torn edges,
Five labeled locations connected by dotted pixel paths:
- mushroom grotto (top left, simple mushroom shapes)
- abandoned mine tunnel (top center, minecart silhouette)
- underground river (right, wavy lines)
- grape vine terrace (bottom left, vine patterns)
- underground farm mill (bottom right, windmill silhouette)
Dark ink lines (#403020) on parchment,
pixel compass rose decoration in corner,
limited color palette, flat colors,
1px black outlines (#000000),
chunky pixel shapes, simple identifiable forms,
no UI elements, no gradient, no soft blur"""
    },
    {
        "id": "E1",
        "name": "ending_bg",
        "output": "backgrounds/ending_bg.png",
        "width": 1280,
        "height": 720,
        "prompt": """pixel art, crudely drawn MS Paint style,
closed tavern after hours, 1280x720,
same stone and wood tavern interior as B1,
using deeper dark colors (#1E1814 dominant),
heavy closed ledger book on bartop center-bottom,
flat amber (#E8A040) decorative pattern on cover,
wall sconces as dark flat blocks (extinguished),
lite from above center as subtle brighter pixel tones,
quiet, contemplative, end-of-journey mood,
limited color palette, flat colors,
1px black outlines (#000000),
chunky pixel shapes, simple identifiable forms,
no gradient, no soft glow, no characters"""
    },
    
    # ========== 角色类 (6个) ==========
    {
        "id": "C11a",
        "name": "guest_warrior",
        "output": "characters/guest_warrior.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male warrior head,
iron helmet visor, thick beard, rugged weathered face,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes,
simple identifiable forms, 8-bit style"""
    },
    {
        "id": "C11b",
        "name": "guest_mage",
        "output": "characters/guest_mage.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male mage head,
pointed wizard hat, long white beard,
mysterious look, magical aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
    },
    {
        "id": "C11c",
        "name": "guest_rogue",
        "output": "characters/guest_rogue.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, rogue character head,
hood pulled low, cloth mask covering lower face,
cunning eyes visible, stealthy look,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
    },
    {
        "id": "C11d",
        "name": "guest_archer",
        "output": "characters/guest_archer.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, archer character head,
feathered cap/hat, pointed elf-like ears,
sharp keen gaze, focused expression,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
    },
    {
        "id": "C11e",
        "name": "guest_cleric",
        "output": "characters/guest_cleric.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, cleric character head,
bald or short-cropped hair, holy symbol pendant,
kind gentle face, healing aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
    },
    {
        "id": "C11f",
        "name": "guest_barbarian",
        "output": "characters/guest_barbarian.png",
        "width": 72,
        "height": 72,
        "prompt": """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, barbarian character head,
wild unkempt hair, war paint stripes on face,
animal fur cloak visible on shoulders,
fierce look, battle-scarred,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
    },
    
    # ========== 采集点图标 (5个) ==========
    {
        "id": "D2a",
        "name": "icon_mushroom",
        "output": "icons/map/icon_mushroom.png",
        "width": 48,
        "height": 48,
        "prompt": """pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
cluster of glowing mushrooms,
caps emitting faint blue-white light,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style"""
    },
    {
        "id": "D2b",
        "name": "icon_mine",
        "output": "icons/map/icon_mine.png",
        "width": 48,
        "height": 48,
        "prompt": """pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
two crossed pickaxes with chunk of dark ore,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style"""
    },
    {
        "id": "D2c",
        "name": "icon_river",
        "output": "icons/map/icon_river.png",
        "width": 48,
        "height": 48,
        "prompt": """pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
water droplet with ripple rings beneath,
suggesting underground river,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style"""
    },
    {
        "id": "D2d",
        "name": "icon_vine",
        "output": "icons/map/icon_vine.png",
        "width": 48,
        "height": 48,
        "prompt": """pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
bunch of grapes with curling vine tendrils,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style"""
    },
    {
        "id": "D2e",
        "name": "icon_mill",
        "output": "icons/map/icon_mill.png",
        "width": 48,
        "height": 48,
        "prompt": """pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
small windmill/mill building silhouette,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style"""
    },
    
    # ========== 通用小图标 (5个) ==========
    {
        "id": "U1",
        "name": "icon_gold",
        "output": "ui/icon_gold.png",
        "width": 24,
        "height": 24,
        "prompt": """pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
round gold coin with serrated edge,
star mark in center, golden highlight,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms"""
    },
    {
        "id": "U2",
        "name": "icon_star",
        "output": "ui/icon_star.png",
        "width": 24,
        "height": 24,
        "prompt": """pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
five-pointed star, amber-gold fill (#E8A040),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms"""
    },
    {
        "id": "U3",
        "name": "icon_stamina",
        "output": "ui/icon_stamina.png",
        "width": 24,
        "height": 24,
        "prompt": """pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
small heart shape or lightning bolt,
bright green fill (#5A8A3A),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms"""
    },
    {
        "id": "U4",
        "name": "icon_close",
        "output": "ui/icon_close.png",
        "width": 24,
        "height": 24,
        "prompt": """pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
X/cross mark, 2px line width,
muted brown (#908878),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms"""
    },
    {
        "id": "U5",
        "name": "icon_check",
        "output": "ui/icon_check.png",
        "width": 24,
        "height": 24,
        "prompt": """pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
checkmark, 2px line width,
success green (#5A8A3A),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms"""
    },
    
    # ========== UI组件类 (9个) ==========
    {
        "id": "UI1",
        "name": "panel_parchment_9patch",
        "output": "ui/panel_parchment_9patch.png",
        "width": 96,
        "height": 96,
        "prompt": """pixel art UI element, crudely drawn MS Paint style,
96x96 canvas, 9-patch panel,
parchment texture look, warm pale brown base,
subtle fiber/paper grain texture (1px noise),
edges slightly darkened/burnt,
four sides: 2px dark brown border (#554334),
four corners have small darkened areas,
center fill area is plain parchment,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
designed for NinePatchRect stretching"""
    },
    {
        "id": "UI2",
        "name": "bubble_order_9patch",
        "output": "ui/bubble_order_9patch.png",
        "width": 96,
        "height": 96,
        "prompt": """pixel art UI element, crudely drawn MS Paint style,
96x96 canvas, 9-patch speech bubble,
light parchment-colored bubble interior (#393431),
2px border (#554334),
pointed tail on the left side (for pointing at customer),
slightly lighter than the panel for readability,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
designed for NinePatchRect stretching"""
    },
    {
        "id": "UI3",
        "name": "title_sign",
        "output": "ui/title_sign.png",
        "width": 1024,
        "height": 256,
        "prompt": """pixel art title sign, crudely drawn MS Paint style,
1024x256 canvas, pixel handwriting style,
Chinese characters "地下城酒馆",
amber-gold fill (#E8A040),
2px black outline (#000000),
drop shadow: offset 3px downward, dark color (#0d0b0a),
transparent background, clean pixel edges,
limited color palette, flat colors,
no anti-aliasing, no gradient"""
    },
    {
        "id": "UI4a",
        "name": "deco_candle_left",
        "output": "ui/deco_candle_left.png",
        "width": 128,
        "height": 128,
        "prompt": """pixel art decoration, crudely drawn MS Paint style,
128x128 canvas, metal candle holder base,
half-melted candle, small flame (#ff9500),
2-3 frame animation potential,
dark outline, transparent background,
limited color palette, flat colors,
1px black outlines (#000000),
no anti-aliasing, simple identifiable forms"""
    },
    {
        "id": "UI4b",
        "name": "deco_candle_right",
        "output": "ui/deco_candle_right.png",
        "width": 128,
        "height": 128,
        "prompt": """pixel art decoration, crudely drawn MS Paint style,
128x128 canvas, same as left candle but mirrored,
or slightly different wax shape,
metal candle holder base, half-melted candle,
small flame (#ff9500),
dark outline, transparent background,
limited color palette, flat colors,
1px black outlines (#000000),
no anti-aliasing, simple identifiable forms"""
    },
    {
        "id": "UI4c",
        "name": "deco_mug",
        "output": "ui/deco_mug.png",
        "width": 128,
        "height": 128,
        "prompt": """pixel art decoration, crudely drawn MS Paint style,
128x128 canvas, wooden beer mug on bartop,
foam overflowing, warm tones,
dark outline, transparent background,
limited color palette, flat colors,
1px black outlines (#000000),
no anti-aliasing, simple identifiable forms"""
    },
    {
        "id": "UI4d",
        "name": "deco_emblem",
        "output": "ui/deco_emblem.png",
        "width": 256,
        "height": 256,
        "prompt": """pixel art emblem, crudely drawn MS Paint style,
256x256 canvas, tavern crest,
shield shape + wheat stalks + drinking mug,
pixel art style, amber (#E8A040) on dark (#161311) shield,
transparent background,
limited color palette, flat colors,
1px black outlines (#000000),
no anti-aliasing, detailed but clean pixel work"""
    },
    {
        "id": "UI5",
        "name": "bar_stamina_segment",
        "output": "ui/bar_stamina_segment.png",
        "width": 96,
        "height": 64,
        "prompt": """pixel art UI element, crudely drawn MS Paint style,
96x64 canvas, stamina segment,
amber-colored (#ffbd7f) filled segment,
heart or lightning bolt shape,
empty version: same shape but dark outline only,
hollow inside (#1f1b19),
designed to be placed 5 segments side by side,
1px dark outline (#000000),
transparent background, no anti-aliasing,
limited color palette, flat colors"""
    },
    {
        "id": "UI6",
        "name": "divider_rope",
        "output": "ui/divider_rope.png",
        "width": 1000,
        "height": 8,
        "prompt": """pixel art UI divider, crudely drawn MS Paint style,
1000x8 canvas, horizontal thin line,
mimicking rope/chain texture,
color (#554334),
small spiral/knot decorations at both ends,
transparent background,
limited color palette, flat colors,
1px black outlines (#000000),
no anti-aliasing, simple pixel pattern"""
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
        print(f"[INFO] 生成中: {output_path} (预计需要3-8分钟，请耐心等待)")
        r = requests.post(f"{API_BASE}/sdapi/v1/txt2img", json=payload, timeout=600)
        
        if r.status_code == 200:
            data = r.json()
            if "images" in data and len(data["images"]) > 0:
                # 保存图片
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
            try:
                err_data = r.json()
                print(f"[ERR] 错误详情: {err_data}")
            except:
                print(f"[ERR] 响应内容: {r.text[:500]}")
            return False
    except Exception as e:
        print(f"[ERR] 生成异常: {e}")
        return False

def main():
    print("=" * 60)
    print("  P1优先级美术资源批量生成脚本 (本地Stable Diffusion)")
    print("=" * 60)
    print()
    
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
    print()
    
    success_count = 0
    fail_count = 0
    skip_count = 0
    
    for task in TASKS:
        task_id = task["id"]
        output_path = ASSETS_DIR / task["output"]
        
        # 检查是否已存在
        if output_path.exists():
            print(f"[SKIP] {task_id} 已存在: {output_path}")
            skip_count += 1
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
    
    print(f"\n{'='*60}")
    print(f"[DONE] 生成完成!")
    print(f"  成功生成: {success_count}")
    print(f"  失败: {fail_count}")
    print(f"  已跳过(已存在): {skip_count}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()