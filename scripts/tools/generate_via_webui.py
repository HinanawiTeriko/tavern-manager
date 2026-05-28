"""
使用本地 Stable Diffusion WebUI API 生成酒馆背景图
"""
import requests
import json
import base64
from pathlib import Path

# WebUI API 地址
API_URL = "http://127.0.0.1:7860/sdapi/v1/txt2img"

# 输出路径
OUTPUT_DIR = Path(__file__).parent.parent.parent / "assets" / "textures" / "backgrounds"
OUTPUT_PATH = OUTPUT_DIR / "tavern_bg_webui.png"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# 生图参数
payload = {
    "prompt": "Pixel art background, 1280x720. Dark fantasy tavern interior — view from behind the bar counter. Top section: rough stone brick wall in deep grey-purple tones, two iron wall sconces with warm amber candlelight, arched wooden door slightly open. Middle section: wooden wine rack with 4-5 shelves, colored bottle silhouettes in amber/red/green. Bottom section: wide thick dark wood bartop counter. Darkest Dungeon meets VA-11 Hall-A atmosphere. Low saturation, high contrast. No characters. No text.",
    "negative_prompt": "people, characters, text, letters, modern furniture, neon lights, bright daylight, 3D render, realistic photo, smooth gradients, blur, anime style, watermark, signature",
    "steps": 30,
    "sampler_name": "DPM++ 2M Karras",
    "width": 1280,
    "height": 720,
    "cfg_scale": 7,
    "seed": -1,
    "n_iter": 1,
    "batch_size": 1
}

print("=" * 60)
print("  使用本地 WebUI API 生成酒馆背景")
print("=" * 60)
print(f"  API: {API_URL}")
print(f"  输出: {OUTPUT_PATH}")
print(f"  尺寸: 1280×720")
print()

try:
    print("正在生成图片...")
    response = requests.post(API_URL, json=payload, timeout=300)
    response.raise_for_status()
    
    result = response.json()
    
    if "images" in result and len(result["images"]) > 0:
        image_data = base64.b64decode(result["images"][0])
        with open(OUTPUT_PATH, "wb") as f:
            f.write(image_data)
        print(f"✓ 图片已保存: {OUTPUT_PATH}")
        
        # 同时保存到 stable-diffusion-webui 的 outputs 目录
        backup_path = Path("c:/Users/13422/Desktop/学习资料/code/IAmCBKing_r/AIGImageTool/stable-diffusion-webui/outputs/txt2img-images") / "tavern_bg_webui.png"
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        with open(backup_path, "wb") as f:
            f.write(image_data)
        print(f"✓ 备份已保存: {backup_path}")
    else:
        print("✗ 未收到图片数据")
        print(f"  响应: {result}")
        
except requests.exceptions.ConnectionError:
    print("✗ 无法连接到 WebUI")
    print("  请确保 WebUI 已启动: python launch.py --api")
except Exception as e:
    print(f"✗ 错误: {e}")
    import traceback
    traceback.print_exc()
