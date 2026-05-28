#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""简单测试 - 生成单个测试图片"""
import requests
import base64
import os

API = "http://127.0.0.1:7860"
OUT = r"c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager\assets\textures\test_output.png"

print("测试WebUI连接并生成测试图片...")
print("=" * 50)

try:
    # 测试连接
    r = requests.get(f"{API}/sdapi/v1/sd-models", timeout=5)
    print(f"[OK] WebUI运行中，模型数: {len(r.json())}")
    
    # 生成测试图片
    payload = {
        "prompt": "pixel art, simple test icon, 64x64",
        "negative_prompt": "3D, realistic, blurry",
        "width": 64,
        "height": 64,
        "steps": 20,
        "cfg_scale": 7.5,
        "sampler_name": "Euler a"
    }
    
    print("\n[生成中] 测试图片 (64x64)...")
    r = requests.post(f"{API}/sdapi/v1/txt2img", json=payload, timeout=300)
    
    if r.status_code == 200:
        data = r.json()
        if "images" in data and data["images"]:
            img_data = base64.b64decode(data["images"][0])
            os.makedirs(os.path.dirname(OUT), exist_ok=True)
            with open(OUT, 'wb') as f:
                f.write(img_data)
            print(f"[OK] 测试图片已保存: {OUT}")
            print(f"[OK] 文件大小: {len(img_data)/1024:.1f} KB")
        else:
            print("[ERR] 返回数据中没有图片")
    else:
        print(f"[ERR] API错误: {r.status_code}")
        
except Exception as e:
    print(f"[ERR] 异常: {e}")

print("\n测试完成")
