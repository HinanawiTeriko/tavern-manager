@echo off
chcp 65001 > nul
echo ============================================
echo  P1优先级美术资源批量生成脚本
echo  模型: pixel-art-xl
echo ============================================
echo.

cd /d "c:\Users\13422\Desktop\学习资料\code\IAmCBKing_r\sourse_code\tavern-manager"

echo 正在检查Python环境...
python --version
if errorlevel 1 (
    echo [错误] Python未安装或未添加到PATH
    pause
    exit /b 1
)

echo.
echo 正在启动生成脚本...
echo 提示: 每个资源生成需要3-8分钟，请耐心等待
echo.

python scripts/tools/generate_p1_complete.py

echo.
echo 脚本执行完成！
echo 请检查输出目录中的生成结果
echo 输出目录: assets\textures\
echo.
pause
