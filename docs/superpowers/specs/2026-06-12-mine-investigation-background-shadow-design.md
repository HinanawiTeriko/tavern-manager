# 废弃矿道背景与接触阴影设计

> 日期：2026-06-12  
> 状态：设计确认中，待实现计划  
> 范围：只做 `MineInvestigation` 的全屏矿洞背景和统一物件接触阴影；不修改观察栏、离开按钮、调查逻辑、DayMap 接缝或文档授予。

## 目标

给废弃矿道调查场景补正式背景承托，让已经完成的 AI/native-pixel 物件不再像漂在纯色占位背景上。背景负责空间、光源、血迹动线和低对比落点；物件仍保持独立动态节点，继续由 `MineItem` 按 `item_tag` 加载生产贴图。

## 已确认方向

采用“背景带落点暗区 + 统一阴影贴图”的方案：

- 一张 `320x180` native 背景导出为 `1280x720` runtime；
- 背景中预画低对比落点：左侧浅层散落区、右侧塌方区、背包露出区、血纸掉落区；
- 不把断箭、凹盾、破靴、背包、硬币、队牌、染血纸等完整可交互物烙进背景；
- 新增统一 `mine_item_shadow` 贴图，由 `MineItem` 放在 production texture 下方，按物件尺寸缩放；
- `MineInvestigation` 的节点路径和逻辑合同保持不变。

## 视觉构图

背景是冷暗矿洞横截面，服务现有动线：

- 左侧：入口附近浅层调查区域，地面较平，适合断箭、凹盾、破靴落地；
- 中下：暗红血迹从左侧浅层区域延伸到右侧；
- 右侧：塌方石堆所在区域，有更重的冷暗岩壁和碎石暗区；
- 右下/塌方后方：给撕裂背包和血纸洒落预留较暗但可读的地面；
- 顶部和远景：只做矿洞深度和岩壁，不放高对比细节。

画面优先级：

1. 可交互物件读数最高；
2. 血迹动线第二；
3. 塌方区域第三；
4. 岩壁纹理和远景最低。

## 融合规则

背景和物件融合靠四件事：

1. **统一光源**：背景主光来自左侧入口或上方裂缝，弱冷光为主，少量 amber 只落在地面边缘和血迹附近。现有物件的暖色高光不需要重画，但背景不能出现反方向强光。
2. **低对比落点**：背景在物件预期位置下方画暗色/冷灰落点，不画完整物件轮廓。落点只帮助接地，不承担交互信息。
3. **接触阴影**：每个 mapped production item 下方加同一张 `mine_item_shadow`，颜色偏冷黑、透明边缘、无紫边、无现代发光。
4. **细节密度差**：背景细节密度低于物件，边缘更软、更暗；物件剪影保持更硬、更亮。

## 资产管线

新增目录与文件：

```text
art_sources/generated_raw/mine_investigation_background/
assets/source/investigation/mine_background/
assets/ui/generated/investigation/mine_background/
docs/art/mine_investigation_background_contact_sheet.png
scripts/tools/prepare_mine_investigation_background_sources.py
scripts/tools/export_mine_investigation_background_assets.py
scripts/test/test_mine_investigation_background_pipeline.py
```

AI 生成只作为 reference：

- 原始 AI 背景放 `art_sources/generated_raw/mine_investigation_background/`；
- stable reference 和 native PNG 放 `assets/source/investigation/mine_background/`；
- Godot runtime 只引用 `assets/ui/generated/investigation/mine_background/`；
- 背景 native 为 `320x180`，runtime 为 `1280x720`，只能 `4x` 最近邻；
- 阴影 native 建议 `32x12` 或 `40x14`，runtime 同样 `4x` 最近邻；
- contact sheet 展示 reference、native 4x preview、runtime preview、物件叠加预览。

## Godot 接入

### 背景接入

`scenes/ui/MineInvestigation.tscn` 当前有 `Background` 和 `BloodTrail` 两个 `ColorRect`。实现时不改根节点、不改 `World`、`DragCtrl`、`UI`、`ObservationLabel`、`HintLabel`、`LeaveButton`。

推荐最小接入：

- 保留旧 `Background` 节点和节点名，作为底色/fallback；
- 新增 `BackgroundArt` 视觉节点承载 runtime 背景，放在旧 `Background` 之上、`World` 之下；
- 隐藏旧 `BloodTrail` 色块，不删除；血迹改为背景图一部分；
- 不改变 `World/Ground` 和左右墙碰撞。

如果实现时发现现有节点排序不适合直接插入，仍以“保留旧节点、新增视觉节点”为准，不通过删除旧节点来解决层级问题。

### 接触阴影接入

在 `MineItem` 的 production texture 分支中新增 `ShadowVisual`：

- 只对 `ITEM_TEXTURES` 映射到的 production items 显示；
- 位于 `TextureVisual` 下方，`z_index` 低于物件、高于背景；
- 按 `p_size` 水平方向缩放，竖向固定较低；
- 未映射物件继续保持旧 `Polygon2D + Label` fallback，不强行加阴影；
- 不改变碰撞尺寸，不改变拖拽和拾取逻辑。

## 验证

新增测试覆盖：

1. 背景 native/runtime 存在，尺寸正确；
2. runtime 是 native 的 exact nearest-neighbor `4x` 导出；
3. 背景不是纯色占位，且有足够冷暗像素、少量血迹暗红、低数量 amber；
4. 背景不能含大面积可交互物件形状或文字；
5. 阴影贴图有透明边界、非空、无 magenta/chroma fringe；
6. `MineInvestigation.tscn` 引用 runtime 背景路径，不引用 raw/reference；
7. `MineInvestigation.tscn` 保留 `Background` 和 `BloodTrail` 节点名，`BloodTrail` 隐藏；
8. `MineItem` production 分支显示 `ShadowVisual`，fallback 分支不强制显示阴影；
9. 现有 `test_mine_investigation`、`test_toby_lodging_investigation` 仍通过。

视觉检查：

- contact sheet 中物件叠加预览应显示物件落地，不漂浮；
- 背景不抢 `bloodied_paper`；
- 血迹动线能把视线导向右侧塌方；
- 没有紫边、软糊边或高清贴图感。

## 预计改动文件

实现阶段预计触碰：

| 文件/目录 | 原因 |
| --- | --- |
| `art_sources/generated_raw/mine_investigation_background/` | 保存 AI 背景 reference |
| `assets/source/investigation/mine_background/` | 保存 stable reference、native 背景、native 阴影、manifest |
| `assets/ui/generated/investigation/mine_background/` | 保存 runtime 背景和阴影 |
| `docs/art/mine_investigation_background_contact_sheet.png` | 视觉审查 |
| `scripts/tools/prepare_mine_investigation_background_sources.py` | 规范 AI raw 到 stable reference |
| `scripts/tools/export_mine_investigation_background_assets.py` | 导出 native/runtime 与叠加预览 |
| `scripts/test/test_mine_investigation_background_pipeline.py` | 背景与阴影资产合同测试 |
| `scripts/test/test_mine_item_visual_contract.gd` | 增加 `ShadowVisual` 合同断言 |
| `scripts/ui/components/mine_item.gd` | production texture 分支增加接触阴影 |
| `scenes/ui/MineInvestigation.tscn` | 新增背景视觉节点、隐藏旧血迹色块，保留关键节点名 |

不触碰：

- `scripts/ui/mine_investigation.gd`；
- `scripts/ui/day_map_view.gd`；
- `scripts/game_manager.gd`；
- `data/locations.json`；
- `DocumentOverlay`、观察栏、离开按钮样式。

## 风险与处理

- **背景抢物件读数**：降低背景亮度和边缘对比，contact sheet 必须包含物件叠加预览。
- **AI 背景画入完整物件**：reference 审查不通过就重生；导出阶段不得靠裁掉局部物件补救。
- **阴影随物理旋转不自然**：阴影不跟随旋转，只按物件尺寸缩放并保持水平；它是接地暗区，不是精确投影。
- **背景节点改动破坏合同**：保留 `Background` 和 `BloodTrail` 节点名；新增视觉节点而非删除旧节点。
- **影响 Toby 共用 `MineItem`**：阴影只在 mapped production items 显示，未映射 `contract_fragment` 等继续旧 fallback。
