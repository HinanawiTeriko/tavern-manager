"""Check Stable Diffusion WebUI status"""
import requests
import sys

API_BASE = "http://127.0.0.1:7860"

try:
    r = requests.get(f"{API_BASE}/sdapi/v1/sd-models", timeout=5)
    if r.status_code == 200:
        models = r.json()
        print(f"[OK] WebUI is running!")
        print(f"[OK] Available models: {len(models)}")
        for m in models:
            print(f"  - {m['model_name']}")
        sys.exit(0)
    else:
        print(f"[ERR] API returned status: {r.status_code}")
        sys.exit(1)
except requests.exceptions.ConnectionError:
    print(f"[ERR] Cannot connect to {API_BASE}")
    print(f"[HINT] Please start Stable Diffusion WebUI with --api flag:")
    print(f'  cd "C:\\Users\\13422\\Desktop\\学习资料\\code\\IAmCBKing_r\\AIGImageTool\\stable-diffusion-webui"')
    print(f'  webui-user.bat --api')
    sys.exit(1)
except Exception as e:
    print(f"[ERR] {e}")
    sys.exit(1)
