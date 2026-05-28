# -*- coding: utf-8 -*-
"""
简化版P1资源生成脚本
直接调用本地 Stable Diffusion WebUI API
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

# 读取AI提示词文件
def read_prompt_file(filepath):
    """读取提示词文件，提取AI提示词部分"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            # 查找AI提示词部分（在```之间的内容）
            import re
            matches = re.findall(r'```(.*?)```', content, re.DOTALL)
            if matches:
                # 返回第一个代码块的内容
                return matches[0].strip()
            return content
    except Exception as e:
        print(f"[ERR] 读取文件失败 {filepath}: {e}")
        return None

# P1任务列表（简化版，基于已读取的提示词）
TASKS = [
    # 背景类
    {
        "id": "D1",
        "name": "daymap_bg",
        "output": "backgrounds/daymap_bg.png",
        "width": 1280,
        "height": 720,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_backgrounds.txt",
        "prompt_key": "D1"
    },
    {
        "id": "E1", 
        "name": "ending_bg",
        "output": "backgrounds/ending_bg.png",
        "width": 1280,
        "height": 720,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_backgrounds.txt",
        "prompt_key": "E1"
    },
    # 角色类
    {
        "id": "C11a",
        "name": "guest_warrior",
        "output": "characters/guest_warrior.png",
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11a"
    },
    {
        "id": "C11b",
        "name": "guest_mage", 
        "output": "characters/guest_mage.png",
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11b"
    },
    {
        "id": "C11c",
        "name": "guest_rogue",
        "output": "characters/guest_rogue.png", 
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11c"
    },
    {
        "id": "C11d",
        "name": "guest_archer",
        "output": "characters/guest_archer.png",
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11d"
    },
    {
        "id": "C11e",
        "name": "guest_cleric",
        "output": "characters/guest_cleric.png",
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11e"
    },
    {
        "id": "C11f",
        "name": "guest_barbarian",
        "output": "characters/guest_barbarian.png",
        "width": 72,
        "height": 72,
        "prompt_file": r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\scripts\ai_prompts\p1_characters.txt",
        "prompt_key": "C11f"
    },
]

def check_webui():
    """检查WebUI状态"""
    try:
        r = requests.get(f"{API_BASE}/sdapi/v1/sd-models", timeout=5)
        if r.status_code == 200:
            print(f"[OK] WebUI 运行中")
            return True
        else:
            print(f"[ERR] WebUI 返回状态码: {r.status_code}")
            return False
    except Exception as e:
        print(f"[ERR] 无法连接到 WebUI: {e}")
        return False

def generate_image(prompt, negative_prompt, width, height, output_path):
    """调用WebUI API生成图片"""
    payload = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "width": width,
        "height": height,
        "steps": 30,
        "cfg_scale": 7.0,
        "sampler_name": "Euler a",
        "batch_size": 1,
        "n_iter": 1,
        "seed": -1,
        "restore_faces": False,
        "tiling": False,
        "enable_hr": False
    }
    
    try:
        print(f"[INFO] 生成中: {output_path} ({width}x{height})")
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
            return False
    except Exception as e:
        print(f"[ERR] 生成异常: {e}")
        return False

def main():
    print("=" * 60)
    print("  P1优先级美术资源批量生成脚本 (简化版)")
    print("=" * 60)
    print()
    
    # 检查WebUI状态
    if not check_webui():
        print("[INFO] 请先启动 Stable Diffusion WebUI")
        return
    
    print(f"[INFO] 开始批量生成...")
    print(f"[INFO] 资源目录: {ASSETS_DIR}")
    print(f"[INFO] 总任务数: {len(TASKS)}")
    print()
    
    success_count = 0
    fail_count = 0
    
    for task in TASKS:
        task_id = task["id"]
        output_path = ASSETS_DIR / task["output"]
        
        # 检查是否已存在
        if output_path.exists():
            print(f"[SKIP] {task_id} 已存在: {output_path}")
            continue
        
        # 使用预设的提示词（从原脚本）
        if task_id == "D1":
            prompt = """pixel art, crudely drawn MS Paint style, 
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
        elif task_id == "E1":
            prompt = """pixel art, crudely drawn MS Paint style,
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
        elif task_id == "C11a":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male warrior head,
iron helmet visor, thick beard, rugged weathered face,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes,
simple identifiable forms, 8-bit style"""
        elif task_id == "C11b":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, male mage head,
pointed wizard hat, long white beard,
mysterious look, magical aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
        elif task_id == "C11c":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, rogue character head,
hood pulled low, cloth mask covering lower face,
cunning eyes visible, stealthy look,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
        elif task_id == "C11d":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, archer character head,
feathered cap/hat, pointed elf-like ears,
sharp keen gaze, focused expression,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
        elif task_id == "C11e":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, cleric character head,
bald or short-cropped hair, holy symbol pendant,
kind gentle face, healing aura,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
        elif task_id == "C11f":
            prompt = """pixel art bust portrait, crudely drawn MS Paint style,
72x72 canvas, barbarian character head,
wild unkempt hair, war paint stripes on face,
animal fur cloak visible on shoulders,
fierce look, battle-scarred,
limited color palette, flat colors,
1px black outlines (#000000),
transparent background, no anti-aliasing,
neutral expression, chunky pixel shapes"""
        else:
            prompt = task.get("prompt", "pixel art")
        
        negative_prompt = """3D render, realistic photo, smooth gradients, 
anime style, manga style, photorealistic,
modern clothing, bright colors,
text, watermark, signature,
jpeg artifacts, distorted, deformed,
blurry, low quality, extra limbs"""
        
        # 生成图片
        if generate_image(
            prompt=prompt,
            negative_prompt=negative_prompt,
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
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
