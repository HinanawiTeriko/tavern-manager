# 营业界面静态美术整体重做设计

- 日期：2026-06-08
- 范围：`scenes/ui/Tavern.tscn` 夜晚营业界面的静态美术与接入
- 方案：B，统一 Tavern 静态美术包
- 状态：设计待审核

## 目标

把当前 Tavern 营业界面中不可用或风格不一致的静态美术整体重做为一套统一资产。所有新视觉资产必须先生成或收集 reference，再进入 native-pixel 生产源，最后由确定性 exporter 最近邻整数放大成 Godot runtime 纹理。

本轮只做静态美术，不做蒸汽、闪光、飞溅、搅拌漩涡、角色帧动画或按钮抖动动画。玩法逻辑、输入方式、物理规则、订单结算和叙事递交流程保持不变。

## 风格基准

视觉必须延续当前标题画面和开场资产的主风格：

- 暗 teal / 煤黑地牢酒馆作为主底色。
- amber 烛光只做焦点和 UI 强调，不铺满画面。
- 低密度 chunky pixel clusters，少细碎噪点。
- 320x180 缩小视角下仍能读清大轮廓。
- 不使用写实渐变、现代发光 UI、高清生成图直接缩进 runtime。

营业界面相比标题画面可以更暖、更可用，但不能变成高饱和橙棕色界面。背景负责氛围和空间，动态信息由独立 UI/角色/道具层承载。

## 资产管线

新增 Tavern 专属管线：

```text
assets/source/tavern/reference/     # 生图原图、候选图、审核 composite
assets/source/tavern/               # native 生产源
assets/textures/tavern/             # Godot runtime 纹理
scripts/tools/prepare_tavern_sources.py
scripts/tools/export_tavern_assets.py
scripts/test/test_tavern_asset_pipeline.py
```

生成图只允许放在 `assets/source/tavern/reference/`，不能被 Godot 场景直接引用。透明资产使用内置 image generation 生成在纯色 chroma-key 背景上，再本地去背景，之后保存 native alpha PNG。若 chroma-key 无法干净处理，再单独确认是否改用 CLI 真透明路径。

全屏背景 native 为 `320x180`，runtime 为 `1280x720`，只允许 4x nearest-neighbor 导出。局部 UI、图标、角色、道具也必须有 native 源图和 runtime 导出；倍率按资产尺寸统一选定，并在 exporter 和测试中固定。

## 静态资产清单

### 背景层

- `background/tavern_bg_native.png`
- `background/tavern_bg.png`

背景包含地牢酒馆内景、吧台工作面、后墙层次、暖光点、客人舞台留白和桌面操作区域。背景不烘焙客人、订单文字、按钮、耐心条、材料、成品、剧情物品或交互状态。

### UI 层

Tavern 使用一组专属 UI 纹理，不继续依赖当前不可控旧纹理：

- 顶栏背景。
- 快捷栏背景与单槽。
- 订单气泡 9-patch。
- 耐心条背景与填充。
- 菜单、背包、文档/账本面板 9-patch。
- 按钮 normal、hover、pressed、disabled。
- 标签页 normal、selected。
- 列表行背景。
- 滚动条 track 和 grabber。
- 小图标：金币、声望、日期/时间、关闭、翻页。

`ThemeColors` 可保留为样式入口，但 Tavern 场景应优先加载 `assets/textures/tavern/ui/` 里的 stylebox 和 icon。fallback 只用于缺失资源时避免崩溃，不作为目标外观。

### 工作台道具层

- 酒桶。
- 烤架。
- 炖锅。
- 勺子。
- 调味罐。
- 桌面账本。

保留现有 `BarWorkspace`、`Brewery`、`KitchenContainer`、`StirSpoon` 节点和碰撞逻辑。替换 Sprite2D 美术、尺寸校准、z-index 和必要的可视锚点；不改变容器产出规则。

### 物品图标层

材料、成品、剧情物品统一重做静态图标。快捷栏、背包、配方列表和桌面物体显示共用同一批图标语言，避免同一物品在不同界面里风格不同。

最低覆盖：

- 材料：`ale`、`flour`、`meat_raw`、`grape`、`herb`。
- 成品：当前 `data/items.json` 中所有 `product` 类型。
- 剧情物品：`sleep_powder`、`bloodied_contract`、`alternative_contract`、`toby_contract` 等现有可递交/可阅读物品。

### 客人层

主要 NPC 与普通客人 fallback 一起纳入 Tavern 包：

- Ryan 当前剧情所用静态表情。
- Mira 当前剧情所用静态表情。
- 普通客人类型 fallback：commoner、knight、merchant、rogue、wizard、dwarf 或现有 `GuestSystem` 实际使用的职业 key。

若当前代码只按 `npc_id` 加载 `assets/textures/characters/<key>.png`，实施时需要增加一层映射，但不能让缺图时继续出现渐变占位。

## 文字排布硬约束

所有承载文字的面板必须先设计文字安全区，再制作边框和装饰。文字由 Godot 渲染，不烘焙进 PNG。

覆盖范围：

- 顶栏：金币、声望、天数、菜单按钮、打烊按钮。
- 客人区：姓名、订单气泡、耐心条。
- 快捷栏：物品名、数量、图标。
- 菜单弹窗：标签页、配方列表、背包入口、整理桌面、关闭。
- 背包弹窗：材料列、剧情物品列、行项目名称和数量。
- 文档/账本弹窗：标题、左右页正文、页码、翻页、关闭。
- Tavern 内打开的设置面板。

规则：

- 每个 texture stylebox 都设置 content margin，Label 不贴边。
- 长中文名、配方行、订单句子必须测试换行、省略或缩小策略，不允许溢出面板。
- 按钮四态使用同一文字安全区，hover/pressed 不改变文字布局。
- 图标和文字分区固定，图标不能挤压文字。
- 文档正文使用固定两栏版心，翻页按钮不能覆盖正文。
- 装饰只允许落在文字安全区外；若装饰影响阅读，删除装饰。

## 生成与审核顺序

1. 生成并审核 Tavern 整体背景 reference。
2. 从批准的背景 reference 规整出 `320x180` native，再导出 runtime。
3. 生成 UI 面板和控件 reference，按文字安全区切 native。
4. 生成工作台道具、账本、物品图标、客人立绘 reference。
5. 对透明资产做 chroma-key 去背景，验证 alpha 后进入 native。
6. 运行 exporter，生成 `assets/textures/tavern/` runtime。
7. 接入 Godot 场景和主题路径。
8. 运行 pipeline 测试和 Tavern 场景回归。
9. 截图人工核查：背景、UI、文字、客人、道具、图标是否同一套风格。

每个 reference 进入 native 前必须通过肉眼审核。未通过的 reference 不进入 runtime，不用后期硬修掩盖结构错误。

## Godot 接入

接入点保持局部化：

- `scenes/ui/Tavern.tscn`：替换背景、UI 节点样式、工作台 Sprite2D、客人区布局。
- `scripts/ui/tavern_view.gd`：加载 Tavern 专属纹理、客人贴图映射、文字安全区样式。
- `scripts/ui/theme_colors.gd`：增加或复用 Tavern stylebox 加载入口。
- `scripts/ui/bar_workspace.gd`：只在必要时调整图标/槽位显示和道具视觉锚点。
- `scripts/ui/inventory_overlay.gd`、`scripts/ui/document_overlay.gd`：接入 Tavern 面板纹理和文字安全区。
- `scripts/game_manager.gd` 仅在缺少统一图标映射入口时做最小修改。

不重写 `GuestSystem`、`CraftSystem`、`EconomySystem`、`NarrativeManager` 的业务逻辑。

## 测试策略

新增 Python pipeline 测试：

- native 文件存在且尺寸正确。
- runtime 文件存在且尺寸正确。
- runtime 是 native 的 exact nearest-neighbor export。
- 透明资产有 alpha，非空，边缘没有整片 chroma-key 残留。
- full-screen 背景只从 `320x180` native 4x 导出。
- Tavern 场景引用的是 `assets/textures/tavern/` runtime，而不是 reference 或旧路径。

新增或扩展 Godot 测试：

- Tavern 实例化后背景、订单气泡、耐心条、快捷栏、菜单、背包、文档面板都有新纹理。
- 工作台道具的旧 Polygon2D 占位仍隐藏，新 Sprite2D 可见。
- 缺少某个普通客人贴图时使用 Tavern fallback 贴图，不生成渐变占位。
- 关键 Label 在安全区内，长订单/长物品名不溢出。
- 现有 `test_workspace_scene_recovery.gd`、`test_ryan_slice_assets.gd`、`test_kitchen_containers.gd` 继续通过。

## 风险与边界

- 生图 reference 可能风格漂移。处理方式是先审核 reference，再进入 native，不在 Godot 侧补救。
- 透明小图标可能 chroma-key 边缘不干净。处理方式是生成时要求纯色背景和足够 padding，必要时重生成。
- 文字安全区可能压缩美术装饰。处理方式是阅读优先，装饰服从版心。
- 当前工作区已有大量 DayMap 未提交改动。本任务不修改 DayMap 相关文件，提交时只纳入 Tavern 相关变更。

## 完成标准

- Tavern 营业界面第一眼不再出现旧占位背景、旧渐变占位角色或程序化色块 UI。
- 背景、UI、道具、图标、客人立绘来自同一套 reference 和 native-pixel 管线。
- 所有 Godot runtime 纹理都有可追溯 native 源图。
- 文字面板在中文长文本情况下仍可读、无遮挡、不溢出。
- 静态美术接入不改变营业玩法和叙事结算。
- pipeline 测试、Tavern 相关 Godot 回归和人工截图核查通过。
