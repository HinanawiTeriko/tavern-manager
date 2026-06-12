# 废弃矿道调查物件 AI 美术设计

> 日期：2026-06-12  
> 状态：设计确认中，待实现计划  
> 范围：只做 `MineInvestigation` 的可交互物件美术，不重做背景，不迁移其他调查场景。

## 目标

把废弃矿道调查场景里的占位交互物件换成正式像素游戏美术，让玩家不再依赖常驻小标签也能读懂物件：断箭、凹盾、破靴、塌方碎石、撕裂背包、硬币、血斧队牌、染血纸。

这次工作不改调查玩法、文档授予、DayMap 进入/退出流程、物理拖拽手感或节点路径合同。背景只保留现有承托，后续若要做矿道全屏背景，另开单独设计。

## 已确认约束

- 所有物件都必须以 AI 生图作为原始 reference，不能用纯手工像素图替代。
- AI 原图不能直接被 Godot runtime 引用，必须进入 native-pixel 管线。
- 常驻物件小标签从玩家视图隐藏；`Label` 节点和 `setup()` 的 `p_label` 参数保留，作为调试/合同兼容。
- 运行时文字仍由 Godot `Label`/观察栏渲染，AI 图不得包含可读文字、数字、logo 或假 UI。
- 不按 alpha、颜色或连通域猜切图；每个裁切都来自固定 manifest 矩形。
- 每个生成资产必须有 manifest entry：id、source、native、runtime、尺寸、安全区、用途。

## 视觉方向

风格目标是“暗 teal 地牢酒馆 UI 的同一世界观下的法证式矿道证物”：

- 低密度 chunky pixel clusters，硬边、少色、强剪影；
- 冷暗石灰、旧皮革、暗木、氧化铁、少量干血暗红；
- amber 只作为极少量反光或旧金属点，不做高饱和发光；
- 物件要像调查证物，不像现代 UI 图标或手游贴纸。

物件可读性优先级：

1. `bloodied_paper` 必须一眼像关键纸张线索，带暗红血迹但无文字。
2. `rubble` 必须像可扒开的塌方阻挡物，体量明显。
3. `torn_backpack` 必须像会被倾倒的软容器。
4. `broken_arrow`、`dented_shield`、`lost_boot` 作为浅层观察物，剪影要清楚但不能抢过线索纸。
5. `coins`、`warhammer_token` 是洒落演出物，体量小、可读即可。

## 资产方案

### AI reference

生成一张或多张 `mine_investigation` 证物 sheet：

- 存放：`art_sources/generated_raw/mine_investigation/`
- 内容：8 个分格物件，统一视角，干净背景，无文字；
- 允许多轮生成，但只有被选中的 reference 进入 manifest；
- reference 保留在仓库，用于审查和后续重切。

### Native source

清理后的生产源放：

```text
assets/source/investigation/mine_items/
```

建议 native 尺寸：

| id | native size | runtime display intent |
| --- | ---: | --- |
| `broken_arrow` | `24x12` | 浅层观察物，约 `48x16` 碰撞体内居中 |
| `dented_shield` | `32x32` | 浅层观察物，约 `64x64` |
| `lost_boot` | `28x18` | 浅层观察物，约 `56x36` |
| `rubble` | `60x45` | 深层遮蔽物，约 `120x90` |
| `torn_backpack` | `36x28` | 容器，约 `72x56` |
| `coins` | `10x10` | 洒落小物，约 `20x20` |
| `warhammer_token` | `14x14` | 洒落小物，约 `28x28` |
| `bloodied_paper` | `20x26` | 关键线索，约 `40x52` |

### Runtime textures

Godot 运行时纹理放：

```text
assets/ui/generated/investigation/mine_items/
```

所有 runtime PNG 都必须由 native PNG 以 `4x` 最近邻导出。Godot 场景和脚本只引用 runtime 路径，不引用 AI raw 或 reference。

## Manifest

新增固定 manifest：

```text
assets/source/investigation/mine_items/mine_item_art_manifest.json
```

每个 entry 包含：

- `id`：必须对应 `MineItem.item_tag`，如 `bloodied_paper`；
- `source`：AI raw/reference 源图路径；
- `source_rect`：固定裁切矩形；
- `native`：native PNG 输出；
- `runtime`：runtime PNG 输出；
- `native_size` / `runtime_size` / `scale`；
- `safe_area`：物件可见主体安全区；
- `intended_godot_use`：例如 `MineItem visual texture for contract pickup`。

## Godot 接入设计

接入点保持小而兼容：

- `MineItem.setup()` 签名不变；
- `MineItem` 增加可选 `Sprite2D`/`TextureRect` 视觉子节点或脚本内创建的 `Sprite2D`；
- 按 `item_tag` 查表加载 runtime 纹理；
- 有纹理时隐藏 `Polygon2D` 占位块，隐藏常驻 `Label`；
- 没有纹理时继续显示旧 `Polygon2D` 和 `Label`，方便回退和调试；
- 碰撞尺寸仍由 `p_size` 驱动，不从纹理尺寸反推物理。

这样保留以下合同：

- `scenes/ui/components/MineItem.tscn` 根节点仍是 `MineItem`；
- 子节点 `Shape`、`Visual`、`Label` 仍存在；
- `setup(p_tag, p_kind, p_size, p_color, p_label, p_observation)` 不变；
- `MineInvestigation` 的 item tags、kinds、授予逻辑不变。

## 合同与验证

实现前先补资产合同和验证，而不是直接改场景：

1. 新增 pipeline 测试 `scripts/test/test_mine_investigation_item_art_pipeline.py`。
2. 测试 manifest 完整性：8 个 id 都存在，路径存在，尺寸正确。
3. 测试 runtime 是 native 的 exact nearest-neighbor `4x` 导出。
4. 测试 AI raw/reference 没被 runtime scene/script 直接引用。
5. 测试每个物件有可见 alpha，透明边界存在，剪影不为空。
6. 测试 `MineItem` 保留 `Shape`、`Visual`、`Label`，`setup()` 仍可被现有调查场景调用。
7. 生成 contact sheet：`docs/art/mine_investigation_item_art_contact_sheet.png`，包含 reference、native 4x preview、runtime preview。

后续实现完成后，至少运行：

```text
python scripts/test/test_mine_investigation_item_art_pipeline.py
godot --headless --path . scenes/test/test_mine_investigation.tscn
```

如果接入 `MineItem` 影响 Toby 场景，也运行：

```text
godot --headless --path . scenes/test/test_toby_lodging_investigation.tscn
```

## 预计改动文件

实现阶段预计触碰以下文件；动手前需再次列出并说明原因：

| 文件/目录 | 原因 |
| --- | --- |
| `art_sources/generated_raw/mine_investigation/` | 保存 AI 生成物件 reference |
| `assets/source/investigation/mine_items/` | 保存 native PNG 与 manifest |
| `assets/ui/generated/investigation/mine_items/` | 保存 runtime PNG |
| `scripts/tools/export_mine_investigation_item_assets.py` | 固定 manifest 裁切、清理、native 导出、runtime 4x 导出、contact sheet |
| `scripts/test/test_mine_investigation_item_art_pipeline.py` | 资产合同和最近邻导出验证 |
| `scripts/ui/components/mine_item.gd` | 兼容地给 `MineItem` 按 `item_tag` 加载纹理并隐藏常驻标签 |
| `scenes/ui/components/MineItem.tscn` | 如需要，新增视觉节点；保留旧节点 |

不触碰：

- `scripts/ui/mine_investigation.gd`，除非后续验证发现必须显式设置 debug label visibility；
- `scenes/ui/MineInvestigation.tscn`；
- `scripts/ui/day_map_view.gd`；
- `scripts/game_manager.gd`；
- `data/locations.json`。

## 非目标

- 不做废弃矿道背景正式美术；
- 不做托比落脚处物件；
- 不把调查场景抽象成通用模板；
- 不修改 DocumentOverlay 或 DayMap UI；
- 不调整物理参数、碰撞形状或调查完成条件。

## 风险与处理

- **去掉常驻标签后物件读不清**：以 contact sheet 和 Godot 实机截图检查；必要时增强剪影、减少内部细节，不恢复常驻标签作为第一选择。
- **AI sheet 风格太细/太糊**：只把它当 reference，native 阶段量化、降噪、重建透明边界；runtime 仍严格最近邻。
- **物件纹理和碰撞尺寸不贴合**：纹理按 `p_size` 显示意图缩放，碰撞尺寸不从图推导；manifest 记录 safe area 便于调整。
- **影响 Toby 共用 `MineItem`**：新增逻辑必须可回退；没有 texture mapping 的 item 继续走旧占位外观。

