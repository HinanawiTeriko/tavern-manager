"""
生成酒馆吧台背景 (B1) — AI 生图脚本
基于 docs/07_美术需求文档.md 和 docs/08_AI生图提示词.md
"""
import os
import json
import base64
import requests
from pathlib import Path

# API 配置 (来自 .codebuddy/models.json)
API_URL = "https://token-plan-sgp.xiaomimimo.com/v1/chat/completions"
API_KEY = "tp-sys4hr2t1na8h0pzfz75zddp0wm6hbatwf714b1g53t528y8"
MODEL = "MiMo-v2-Omni"  # supportsImages: true

# 输出路径
OUTPUT_DIR = Path(__file__).parent.parent.parent / "assets" / "textures" / "backgrounds"
OUTPUT_PATH = OUTPUT_DIR / "tavern_bg.png"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# 根据美术文档 B1 构建的精确生图提示词
PROMPT = """Pixel art background, 1280x720. Dark fantasy tavern interior — the view from behind the bar counter looking out.
Top section (upper 200px): rough stone brick wall in deep grey-purple tones, two iron wall sconces on the left emitting warm amber candlelight (#ffbd7f) with soft glow, an arched wooden door slightly open on the center-right revealing faint light, dark aged wooden ceiling beams with visible wood grain.
Middle section: wooden wine rack with 4-5 shelves behind the bar, colored bottle silhouettes in amber, deep-red, and green, a worn shield hanging on the right wall.
Mid-lower section: wide thick dark wood bartop counter stretching across the full width, ~60px tall, rich wood tones.
Bottom section: vertical wood plank front of the bar counter in darker tone, with a recessed dark groove area at the very bottom.
Lighting: main warm amber light from upper-left sconces and overhead hanging lamp. Lower bar area has cool purple shadows creating warm-cool contrast. Wine rack area is dim, bottles have small highlight reflections.
Darkest Dungeon meets VA-11 Hall-A atmosphere. Low saturation, high contrast between lit and shadow areas. No characters. No text. No letters."""

NEGATIVE_PROMPT = "people, characters, text, letters, modern furniture, neon lights, bright daylight, 3D render, realistic photo, smooth gradients, blur, anime style, watermark, signature"

print("=" * 60)
print(" 地下城酒馆 — B1 酒馆吧台背景 AI 生成")
print("=" * 60)
print(f"  模型: {MODEL}")
print(f"  输出: {OUTPUT_PATH}")
print(f"  尺寸: 1280×720 px")
print()

def generate_image(prompt: str, negative_prompt: str = "") -> str | None:
    """
    调用 MiMo-v2-Omni 模型生成图片
    该模型支持多模态输出（supportsImages: true）
    """
    messages = [
        {
            "role": "system",
            "content": "You are an expert pixel artist. Generate pixel art images. Always output images at exact requested resolution."
        },
        {
            "role": "user",
            "content": f"Generate a pixel art image with the following requirements:\n\n{prompt}\n\nAvoid: {negative_prompt}"
        }
    ]
    
    payload = {
        "model": MODEL,
        "messages": messages,
        "max_tokens": 4096,
        "temperature": 0.7
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    
    print(">> 正在调用 AI 生成接口...")
    try:
        response = requests.post(API_URL, json=payload, headers=headers, timeout=120)
        
        if response.status_code == 200:
            result = response.json()
            
            # 检查响应结构
            if "choices" in result and len(result["choices"]) > 0:
                choice = result["choices"][0]
                message = choice.get("message", {})
                content = message.get("content", "")
                
                # 检查是否有图片内容
                if isinstance(content, list):
                    # 多模态响应格式
                    for item in content:
                        if isinstance(item, dict):
                            if item.get("type") == "image_url":
                                image_url = item.get("image_url", {}).get("url", "")
                                if image_url:
                                    print(f"  [OK] 获取到图片 URL")
                                    return image_url
                            elif item.get("type") == "image":
                                image_data = item.get("image", "")
                                if image_data:
                                    print(f"  [OK] 获取到图片 Base64 数据")
                                    return image_data
                
                # 尝试从内容文本中提取 base64 图片
                if isinstance(content, str) and content:
                    print(f"  [TEXT] 模型返回文本: {content[:200]}...")
                    # 尝试匹配 base64 图片数据
                    if "data:image" in content or content.startswith("/9j/") or content.startswith("iVBOR"):
                        return content
            
            # 输出完整响应便于调试
            print(f"  [RAW] 完整响应: {json.dumps(result, indent=2, ensure_ascii=False)[:1000]}")
        else:
            print(f"  [ERR] API 错误: {response.status_code}")
            print(f"  {response.text[:500]}")
            
    except requests.exceptions.Timeout:
        print("  [TIMEOUT] 请求超时 (120s)")
    except Exception as e:
        print(f"  [ERR] 异常: {e}")
    
    return None


def download_image(url: str, save_path: Path) -> bool:
    """下载图片并保存"""
    try:
        if url.startswith("data:image"):
            # base64 图片
            header, encoded = url.split(",", 1)
            image_data = base64.b64decode(encoded)
        elif url.startswith("http"):
            resp = requests.get(url, timeout=60)
            if resp.status_code == 200:
                image_data = resp.content
            else:
                print(f"  [ERR] 下载失败: HTTP {resp.status_code}")
                return False
        else:
            # 可能是直接 base64
            image_data = base64.b64decode(url)
        
        with open(save_path, "wb") as f:
            f.write(image_data)
        
        file_size = save_path.stat().st_size
        print(f"  [SAVED] 已保存: {save_path} ({file_size / 1024:.1f} KB)")
        return True
        
    except Exception as e:
        print(f"  [ERR] 保存失败: {e}")
        return False


def main():
    # 1. 尝试生成图片
    image_url = generate_image(PROMPT, NEGATIVE_PROMPT)
    
    if image_url:
        success = download_image(image_url, OUTPUT_PATH)
        if success:
            print(f"\n[SUCCESS] 生成成功! 文件: {OUTPUT_PATH}")
        else:
            print(f"\n[WARN] 获取到图片 URL 但下载失败")
            print(f"  URL 预览: {str(image_url)[:200]}...")
    else:
        print(f"\n[WARN] 未获取到图片数据")
        print(f"\n[HINT] 可能原因:")
        print(f"  1. MiMo-v2-Omni 模型可能仅支持图片输入，而非图片生成")
        print(f"  2. 需要专用的图片生成端点")
        print(f"\n[DONE] 已准备就绪的提示词（可直接复制到其他生图工具）:")
        print(f"-" * 40)
        print(PROMPT)
        print(f"-" * 40)
        print(f"\nNegative Prompt:")
        print(NEGATIVE_PROMPT)

if __name__ == "__main__":
    main()
