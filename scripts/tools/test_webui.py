import requests
import sys

url = "http://127.0.0.1:7860"

print("Testing WebUI API...")
try:
    r = requests.get(f"{url}/sdapi/v1/options", timeout=10)
    print(f"Status: {r.status_code}")
    print("API is working!")
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
