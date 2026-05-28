# AI美术素材生成工具设置指南

## 概述
本指南将帮助您设置用于生成tavern-manager项目美术素材的AI工具链。

## 方案一：Stable Diffusion WebUI（推荐）

### 1. 安装Stable Diffusion WebUI
```bash
# 克隆仓库
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui

# 运行安装脚本
# Windows:
webui-user.bat
# Linux/Mac:
./webui-user.sh
```

### 2. 下载像素艺术模型
推荐模型：
- **8bitPixelArt** (Civitai): 专为像素艺术训练
- **PixelArt Diffusion** (Hugging Face): 通用像素艺术模型
- **HDLocalPixel** (Civitai): 高清像素风格

将模型文件(.safetensors或.ckpt)放入 `models/Stable-diffusion/` 目录

### 3. 推荐设置
```
采样器: DPM++ 2M Karras
采样步数: 30-50
CFG Scale: 7-10
尺寸: 512x512 或 768x768 (根据需求调整)
```

### 4. 像素艺术提示词模板
```
pixel art, retro game style, 8-bit, 
limited color palette, clean pixel lines,
[具体描述], [颜色指定],
flat lighting, no anti-aliasing
```

---

## 方案二：在线AI工具（无需本地安装）

### 1. Midjourney (Discord)
- 优点: 质量高，操作简单
- 缺点: 需要付费订阅
- 提示词示例:
```
/imagine pixel art style, tavern background, 
limited color palette, retro game, 
--style pixel --niji 6
```

### 2. Leonardo.ai
- 优点: 有免费额度，支持自定义模型
- 缺点: 生成速度有限制
- 网址: https://leonardo.ai

### 3. Playground AI
- 优点: 完全免费
- 缺点: 自定义能力有限
- 网址: https://playgroundai.com

---

## 方案三：像素艺术专用工具

### 1. Pixel Art AI Generator
- 网址: https://pixelartai.com
- 专为像素艺术优化

### 2. Lospec Pixel Editor
- 网址: https://www.lospec.com/pixel-editor
- 在线像素编辑器，可配合AI生成结果手动调整

---

## 手动调整工具：Aseprite（必需）

### 安装
1. 官网: https://www.aseprite.org (付费$20)
2. 开源版本: https://github.com/aseprite/aseprite (需自行编译)

### 24色板设置
1. 打开Aseprite → Edit → Preferences → Color
2. 导入色板文件(见下方色板定义)
3. 或使用"24色板预设.aseprite-palette"(需创建)

### 24色板定义 (RGB值)
```
暖色系:
  #E8A040 (琥珀主色)
  #F0C060 (亮琥珀/hover)
  #904020 (深琥珀/pressed)
  
文字系:
  #D0C8B8 (正文)
  #908878 (弱化/禁用)
  
功能系:
  #5A8A3A (成功绿)
  #B8402C (危险红)
  #706040 (边框)
  
暗面系:
  #1E1814 (最深底色)
  #2A2218 (低层面板)
  #342A20 (中层面板)
  #403020 (高层面板)
  
材料色:
  #E8A040 (麦芽/金黄)
  #C04050 (葡萄/生肉/暗红)
  #C09050 (面包/面粉/暖棕)
  #60A040 (草药/翠绿)
  #A080F0 (花粉/紫色)
  #F0D060 (谷物/淡黄)
  #E07040 (辣椒/橙红)
  #5090D0 (水/冰/蓝色)
  
中性色:
  #000000 (纯黑/描边)
  #FFFFFF (纯白/高光)
  #605850 (深灰)
  #988878 (浅灰)
```

---

## 工作流建议

### 阶段1: AI生成基础素材
1. 使用Stable Diffusion或在线工具生成基础图像
2. 批量生成多个变体(每个素材生成5-10个版本)
3. 初步筛选，保留3-5个最佳候选

### 阶段2: 手动调整(在Aseprite中)
1. 调整颜色到24色板
2. 添加/统一1px黑色轮廓
3. 纯色填充，移除渐变
4. 调整像素对齐和清晰度
5. 导出为正确尺寸(PNG-24, 透明背景)

### 阶段3: 验证和替换
1. 运行验证脚本(check_assets.py)
2. 备份原占位符
3. 替换素材文件
4. 在Godot中测试

---

## 下一步
1. 选择并安装上述工具之一
2. 运行测试生成，确认风格匹配
3. 开始批量生成P1优先级素材
4. 手动调整并验证

需要我为您生成具体的AI提示词或Aseprite脚本吗？
