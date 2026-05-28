@echo off
cd /d "c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager"
python -c "import requests; r = requests.get('http://127.0.0.1:7860/sdapi/v1/options', timeout=5); print('API Status:', r.status_code)"
pause
