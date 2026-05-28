@echo off
chcp 65001 > nul
echo 正在启动P1资源生成脚本...
echo.

cd /d "c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager"

python.exe scripts\tools\quick_generate.py

echo.
echo 脚本执行完成！
pause
