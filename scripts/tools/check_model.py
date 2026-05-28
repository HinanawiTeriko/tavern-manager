"""
检查 WebUI 当前加载的模型
"""
import requests
import json

url = "http://127.0.0.1:7860"

print("检查 WebUI 状态...")
try:
    # 获取当前选项（包含当前模型）
    r = requests.get(f"{url}/sdapi/v1/options", timeout=5)
    if r.status_code == 200:
        options = r.json()
        current_model = options.get("sd_model_checkpoint", "未知")
        print(f"当前模型: {current_model}")
    
    # 获取可用模型列表
    r = requests.get(f"{url}/sdapi/v1/sd-models", timeout=5)
    if r.status_code == 200:
        models = r.json()
        print(f"\n可用模型 ({len(models)} 个):")
        for i, m in enumerate(models[:10]):  # 只显示前10个
            print(f"  {i+1}. {m.get('title', m.get('model_name', '未知'))}")
        if len(models) > 10:
            print(f"  ... 还有 {len(models) - 10} 个模型")
            
except Exception as e:
    print(f"错误: {e}")
