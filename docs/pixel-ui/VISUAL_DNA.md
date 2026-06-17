# Pixel UI Visual DNA

当前 UI 方向是“地下城酒馆管理界面”：暗色石墙、木牌、纸张、烛光、低饱和金色点亮信息，整体应像可反复使用的经营工具，而不是插画式落地页。

## 视觉关键词

- dark teal dungeon shadows
- warm amber candle accents
- rough ink edges
- wooden tavern signs
- worn paper panels
- chunky native pixels
- restrained readable interface

## 当前参考

- Title screen runtime textures under `assets/textures/title/`
- DayMap UI textures under `assets/textures/daymap/ui/`
- Tavern UI textures under `assets/textures/ui/`
- Fusion Pixel font under `assets/fonts/fusion-pixel/`

## Rules

- UI text is rendered by Godot controls, not baked into generated images.
- Avoid soft antialiasing and blurred borders for pixel UI.
- Avoid one-hue palettes; amber accents should sit on dark teal/brown/stone neutrals.
- No decorative gradient orb backgrounds.
- Cards/panels should be functional containers, not nested decoration.
- New UI must preserve existing node paths and public methods unless explicitly approved.
