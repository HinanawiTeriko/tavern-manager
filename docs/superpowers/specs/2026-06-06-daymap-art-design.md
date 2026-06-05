# DayMap 美术完成设计

## 背景

DayMap 已有一套未完成的原生像素管线：`scripts/tools/export_daymap_assets.py`、`scripts/test/test_daymap_asset_pipeline.py`、`assets/source/daymap/` 和 `assets/textures/daymap/`。当前问题是管线骨架存在，但运行时仍用 `_setup_background()` 的代码渐变覆盖背景；地点 marker 也仍由 `MapPointMarker` 程序绘制圆点，没有使用已经导出的像素图标。

主界面标题屏做得稳定，是因为流程闭环完整：先用生成图或参考图确定气氛与构图，再压回 `320x180` 原生像素源，分层导出 `4x` nearest-neighbor 运行时纹理，并用测试锁住尺寸、alpha、色数、可见面积和像素密度。DayMap 应补齐同一套闭环。

## 目标

完成 DayMap 美术，使它与标题屏同属一个视觉体系：暗青地下城、少量琥珀暖光、低密度 chunky 像素块、无高频生成图噪声、无运行时直接使用高分辨率生成图。

交付范围包括：

- DayMap 背景美术强化并接入运行时。
- 地点 marker 从程序圆点改为像素图标。
- hover、selected、home 等交互状态完成。
- 生图参考进入项目源目录，但最终运行时纹理只能来自 deterministic exporter。
- Python 管线测试和 Godot 场景测试保护该结果。

## 视觉方向

DayMap 背景不是明亮羊皮纸 UI，而是一张摊在地下酒馆桌面或洞穴入口桌面上的行动图。整体基底延续标题屏的暗青地牢和桌面阴影，中部地图纸保持旧纸质感但降低亮度，边缘被暗色环境吞没。home/酒馆位置附近有小范围琥珀光，呼应标题屏左侧酒馆门口暖光。

地图内容使用低密度符号化像素表达：洞穴轮廓、暗河、矿道、藤架、磨坊、告示板、公会柜台和连接路径。背景图不内嵌地点文字，地点名仍由 Godot label 渲染，避免生成图文字和游戏字体混杂。

## 参考生成流程

这次会调用生图工具，但生成图只作为参考源，不作为最终 runtime texture。

参考图提示方向：

- 地下酒馆桌面上的洞穴行动地图。
- 暗青地牢环境，左下或 home 位置有琥珀灯光。
- 低密度像素艺术感，chunky block shapes。
- 地图中有路线和地点符号，但不要任何文字、logo 或 watermark。
- 构图适配 16:9，最终会压回 `320x180`。

生成图保存到 `assets/source/daymap/reference/`，作为构图、光源和色彩参考。之后 exporter 会用确定性绘制和归一化逻辑生成 `assets/source/daymap/daymap_bg_native.png`，再以 nearest-neighbor 导出 `assets/textures/daymap/daymap_bg.png`。

## 资产管线

背景：

- Native source: `assets/source/daymap/daymap_bg_native.png`
- Runtime texture: `assets/textures/daymap/daymap_bg.png`
- Native size: `320x180`
- Runtime size: `1280x720`
- Scale: `4x`
- 导出方式：`Image.Resampling.NEAREST`

地点 marker：

- Native source: `assets/source/daymap/markers/<location_id>_native.png`
- Runtime texture: `assets/textures/daymap/markers/<location_id>.png`
- Native size: `24x24`
- Runtime size: `96x96`
- Scale: `4x`
- 必须有 alpha，色数受控，透明边缘保留。

需要覆盖的 marker：

- `home`
- `mushroom_forest`
- `dark_river`
- `grape_trellis`
- `mill_farm`
- `mercenary_board`
- `abandoned_mine`
- `guild_counter`

## 运行时接入

`DayMap.tscn` 中 `MapWorld/Background` 继续作为地图背景 Sprite，但纹理应来自 `res://assets/textures/daymap/daymap_bg.png`。`day_map_view.gd` 中 `_setup_background()` 不再创建代码渐变覆盖主视觉；它只负责加载 runtime texture、设置 nearest texture filter 和适配当前地图世界坐标。

`MapPointMarker` 改为加载 `res://assets/textures/daymap/markers/<location_id>.png`。home marker 使用 `home.png`。如果某个图标缺失，保留旧程序圆点作为降级路径，避免坏资源阻断 DayMap 主流程。

地点 label 使用项目 pixel font，浅色文字、暗色 outline，字号和当前可读性接近。label 不参与 texture pipeline，因为它需要支持中文地点名和运行时数据。

## 交互状态

普通状态：

- 显示地点图标本体。
- 轻微暗色投影或底座，保证在背景上可读。

Hover：

- 图标调亮到琥珀方向。
- 缩放到约 `1.08`，时间短且不改变布局。
- 显示较弱像素光环。

Selected：

- 图标保持高亮。
- 外圈像素光环更明显。
- 缩放到约 `1.12`。
- label 颜色使用 `ThemeColors.AMBER_PRIMARY` 或接近色。

Home：

- 图标可稍大或使用更强暖光，强调这是回酒馆/进入夜晚的入口。
- 仍遵守同一 marker 图标尺寸和交互状态系统。

## 测试

扩展 `scripts/test/test_daymap_asset_pipeline.py`：

- 背景 native 必须是 `320x180`，runtime 必须是 `1280x720`。
- 背景 runtime 必须是 native 的 exact nearest-neighbor export。
- 背景必须基本不透明。
- 背景色数受控，避免 painterly noise。
- 背景必须包含足够暗青像素和少量琥珀像素。
- marker native 必须是 `24x24`，runtime 必须是 `96x96`。
- marker runtime 必须是 native 的 exact nearest-neighbor export。
- marker 必须有透明 alpha 和足够可见像素。

扩展 Godot 侧 DayMap 测试：

- `MapWorld/Background` 使用 `res://assets/textures/daymap/daymap_bg.png`。
- `MapPointMarker` 对普通地点和 home 都能创建图标 sprite。
- 已知地点 marker 的 texture path 指向 `assets/textures/daymap/markers/<id>.png`。
- marker 仍保留点击信号，不破坏 DayMap 选择地点流程。

## 非目标

- 不重做 DayMap 系统逻辑、地点解锁逻辑、商店逻辑或剧情数据。
- 不把地点名烘焙进背景图。
- 不把生成图直接作为 runtime texture。
- 不修改用户已有的无关工作树变更。

## 完成标准

DayMap 首屏打开时，背景和 marker 应能直接看出与标题屏同源：暗青地下空间、琥珀光源、低密度像素、清晰但不抢 UI 的地点符号。运行时不再出现代码渐变背景或程序圆点 marker。重新运行 exporter 后，所有 runtime PNG 都能由 native source 精确复现，并通过 Python 和 Godot 测试。
