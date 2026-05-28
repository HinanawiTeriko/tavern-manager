#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P1优先级美术资源批量生成脚本
使用本地pixel-art-xl模型通过Stable Diffusion WebUI API生成资源
"""

import requests
import base64
import time
import os
from pathlib import Path
import json

# ========== 配置区域 ==========
API_BASE = "http://127.0.0.1:7860"
MODEL_NAME = "pixel-art-xl.safetensors"

# 输出目录
OUTPUT_BASE = Path(r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures")

# 通用负面提示词
NEGATIVE_PROMPT = """3D render, realistic photo, smooth gradients, anti-aliasing, blur, 
anime style, manga style, cartoon, modern architecture, neon lights, 
bright daylight, white background, text, watermark, signature, low quality, jpeg artifacts, 
distorted, deformed, blurry, out of focus, gradient, soft edges, high quality, 4k"""

# 通用生成参数
DEFAULT_PARAMS = {
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
# ==============================

def check_webui():
    """检查WebUI状态"""
    try:
        r = requests.get(f"{API_BASE}/sdapi/v1/sd-models", timeout=5)
        if r.status_code == 200:
            models = r.json()
            print(f"[OK] WebUI 运行中，可用模型数: {len(models)}")
            
            # 查找pixel-art模型
            pixel_models = [m for m in models if 'pixel' in m.get('title', '').lower()]
            if pixel_models:
                print(f"[OK] 找到pixel模型: {pixel_models[0]['title']}")
            else:
                print("[WARN] 未找到pixel相关模型，将使用默认模型")
            
            return True
        else:
            print(f"[ERR] WebUI 返回状态码: {r.status_code}")
            return False
    except Exception as e:
        print(f"[ERR] 无法连接到 WebUI: {e}")
        print("[INFO] 请确保Stable Diffusion WebUI已启动，且启用了--api参数")
        return False

def set_model(model_name):
    """设置使用的模型"""
    try:
        payload = {"sd_model_checkpoint": model_name}
        r = requests.post(f"{API_BASE}/sdapi/v1/options", json=payload, timeout=30)
        if r.status_code == 200:
            print(f"[OK] 模型已设置为: {model_name}")
            time.sleep(3)  # 等待模型加载
            return True
        else:
            print(f"[WARN] 设置模型失败: {r.status_code}, 将使用当前模型")
            return False
    except Exception as e:
        print(f"[WARN] 设置模型异常: {e}, 将使用当前模型")
        return False

def generate_image(prompt, output_path, width=512, height=512, **kwargs):
    """调用WebUI API生成图片"""
    params = {**DEFAULT_PARAMS, **kwargs}
    
    payload = {
        "prompt": prompt,
        "negative_prompt": NEGATIVE_PROMPT,
        "width": width,
        "height": height,
        **params
    }
    
    try:
        print(f"[生成中] {output_path.name} ({width}x{height})...")
        r = requests.post(f"{API_BASE}/sdapi/v1/txt2img", json=payload, timeout=600)
        
        if r.status_code == 200:
            data = r.json()
            if "images" in data and len(data["images"]) > 0:
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
                print(f"[ERR] 错误详情: {err_data.get('error', 'Unknown')}")
            except:
                print(f"[ERR] 响应内容: {r.text[:200]}")
            return False
    except Exception as e:
        print(f"[ERR] 生成异常: {e}")
        return False

def main():
    print("=" * 60)
    print("  P1优先级美术资源批量生成脚本")
    print("  模型: pixel-art-xl")
    print("=" * 60)
    print()
    
    # 检查WebUI状态
    if not check_webui():
        return
    
    # 设置模型
    set_model(MODEL_NAME)
    
    # 创建输出目录
    subdirs = ["backgrounds", "characters", "icons/map", "ui"]
    for subdir in subdirs:
        (OUTPUT_BASE / subdir).mkdir(parents=True, exist_ok=True)
    
    print(f"\n[INFO] 输出目录: {OUTPUT_BASE}")
    print(f"[INFO] 开始生成P1优先级资源...\n")
    
    success_count = 0
    fail_count = 0
    
    # ========== 1. 背景类 (2个) ==========
    print("=== 1. 背景类 ===")
    
    # D1 - 地牢地图背景
    if generate_image(
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
        output_path=OUTPUT_BASE / "backgrounds" / "daymap_bg.png",
        width=1280,
        height=720
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(3)
    
    # E1 - 结局画面背景
    if generate_image(
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
        output_path=OUTPUT_BASE / "backgrounds" / "ending_bg.png",
        width=1280,
        height=720
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(3)
    
    # ========== 2. 角色类 (6个) ==========
    print("\n=== 2. 角色类 ===")
    
    # C11a - 战士
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male warrior head,
iron helmet visor, thick beard, rugged weathered face,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "characters" / "guest_warrior.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # C11b - 法师
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male mage head,
pointed wizard hat, long white beard,
mysterious look, magical aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
        output_path=OUTPUT_BASE / "characters" / "guest_mage.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # C11c - 盗贼
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, rogue character head,
hood pulled low, cloth mask covering lower face,
cunning eyes visible, stealthy look,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
        output_path=OUTPUT_BASE / "characters" / "guest_rogue.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # C11d - 弓箭手
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, archer character head,
feathered cap/hat, pointed elf-like ears,
sharp keen gaze, focused expression,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
        output_path=OUTPUT_BASE / "characters" / "guest_archer.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # C11e - 牧师
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, cleric character head,
bald or short-cropped hair, holy symbol pendant,
kind gentle face, healing aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
        output_path=OUTPUT_BASE / "characters" / "guest_cleric.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # C11f - 野蛮人
    if generate_image(
        prompt="""pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, barbarian character head,
wild unkempt hair, war paint stripes on face,
animal fur cloak visible on shoulders,
fierce look, battle-scarred,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes""",
        output_path=OUTPUT_BASE / "characters" / "guest_barbarian.png",
        width=72,
        height=72
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # ========== 3. 采集点图标 (5个) ==========
    print("\n=== 3. 采集点图标 ===")
    
    # D2a - 蘑菇
    if generate_image(
        prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
cluster of glowing mushrooms,
caps emitting faint blue-white light,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "icons" / "map" / "icon_mushroom.png",
        width=48,
        height=48
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # D2b - 矿道
    if generate_image(
        prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
two crossed pickaxes with chunk of dark ore,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "icons" / "map" / "icon_mine.png",
        width=48,
        height=48
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # D2c - 河流
    if generate_image(
        prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
water droplet with ripple rings beneath,
suggesting underground river,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "icons" / "map" / "icon_river.png",
        width=48,
        height=48
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # D2d - 葡萄藤
    if generate_image(
        prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
bunch of grapes with curling vine tendrils,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "icons" / "map" / "icon_vine.png",
        width=48,
        height=48
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # D2e - 磨坊
    if generate_image(
        prompt="""pixel art icon, crudely drawn MS Paint style,
48x48 canvas, 1px black outlines,
small windmill/mill building silhouette,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms, 8-bit style""",
        output_path=OUTPUT_BASE / "icons" / "map" / "icon_mill.png",
        width=48,
        height=48
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # ========== 4. 通用小图标 (5个) ==========
    print("\n=== 4. 通用小图标 ===")
    
    # U1 - 金币
    if generate_image(
        prompt="""pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
round gold coin with serrated edge,
star mark in center, golden highlight,
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms""",
        output_path=OUTPUT_BASE / "ui" / "icon_gold.png",
        width=24,
        height=24
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # U2 - 星星
    if generate_image(
        prompt="""pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
five-pointed star, amber-gold fill (#E8A040),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms""",
        output_path=OUTPUT_BASE / "ui" / "icon_star.png",
        width=24,
        height=24
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # U3 - 体力
    if generate_image(
        prompt="""pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
small heart shape or lightning bolt,
bright green fill (#5A8A3A),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms""",
        output_path=OUTPUT_BASE / "ui" / "icon_stamina.png",
        width=24,
        height=24
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # U4 - 关闭
    if generate_image(
        prompt="""pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
X/cross mark, 2px line width,
muted brown (#908878),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms""",
        output_path=OUTPUT_BASE / "ui" / "icon_close.png",
        width=24,
        height=24
    ):
        success_count += 1
    else:
        fail_count += 1
    
    time.sleep(2)
    
    # U5 - 勾号
    if generate_image(
        prompt="""pixel art tiny icon, crudely drawn MS Paint style,
24x24 canvas, 1px black outlines,
checkmark, 2px line width,
success green (#5A8A3A),
limited color palette, flat colors,
transparent background, no anti-aliasing,
simple identifiable forms""",
        output_path=OUTPUT_BASE / "ui" / "icon_check.png",
        width=24,
        height=24
    ):
        success_count += 1
    else:
        fail_count += 1
    
    # ========== 完成统计 ==========
    print(f"\n{'='*60}")
    print(f"[完成] P1优先级资源生成完成!")
    print(f"  成功: {success_count}")
    print(f"  失败: {fail_count}")
    print(f"  总计: {success_count + fail_count}")
    print(f"  输出目录: {OUTPUT_BASE}")
    print(f"{'='*60}")
    print("\n提示:")
    print("1. 小尺寸图标可能需要手动调整")
    print("2. 建议使用Aseprite进行像素级优化")
    print("3. 确保所有资源符合技术规范（色板、描边等）")
    print("4. 检查所有文件的透明背景是否正确")

if __name__ == "__main__":
    main()
