#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""测试WebUI连接"""
import requests
import sys

print("测试WebUI连接...")
print("=" * 50)

try:
    r = requests.get("http://127.0.0.1:7860/sdapi/v1/sd-models", timeout=5)
    if r.status_code == 200:
        models = r.json()
        print(f"[OK] WebUI运行中")
        print(f"[OK] 可用模型数: {len(models)}")
        
        # 查找pixel-art模型
        for m in models:
            title = m.get('title', '')
            if 'pixel' in title.lower():
                print(f"[OK] 找到pixel模型: {title}")
        
        sys.exit(0)
    else:
        print(f"[ERR] WebUI返回状态码: {r.status_code}")
        sys.exit(1)
except Exception as e:
    print(f"[ERR] 无法连接WebUI: {e}")
    sys.exit(1)
