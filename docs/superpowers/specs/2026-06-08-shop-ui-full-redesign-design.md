# 商店界面完整重做设计

- 日期：2026-06-08
- 状态：待用户复核
- 范围：DayMap 商店入口打开后的完整商店体验、视觉资产和 UI 结构

## 背景

当前商店已经从 DayMap 顶部标签页改成地图探索地点，也已有一版商店 overlay 和 `shop_redesign` 资产。但现状仍有明显割裂：背景和账本细节密度较高，商品卡、按钮和运行时布局却像普通控件叠在图上。玩家看到的是“漂亮背景 + 简陋 UI”，不是标题页那种界面与画面浑然一体的感觉。

本次重做不继续修补按钮或卡片，而是把商店当成一张可交互的像素场景来设计。目标是地下流浪商人摊位：没有完整商人入镜，但能通过手、袖口、背包剪影、柜台物件和灯光感觉到有人在经营。

## 已确认方向

- 采用“流浪商人摊位”气质，但不出现完整商人。
- 主要构图采用“中央账本 + 周围摊位物件”。
- 采用保守的变体：账本负责文字密集信息，摊位物件负责少量明确操作。
- 商店视觉要接近标题页的整体感：暗青地下背景、琥珀点光、粗颗粒像素、低密度 chunky 细节。
- 所有新视觉资产必须走项目 native-pixel 管线，不能把生成的高分辨率图直接放进 runtime 纹理目录。

## 设计目标

1. 商店第一眼读作“地下流浪商人摊位”，不是菜单弹窗或管理后台。
2. UI 信息像写在账本、木牌、签条、金币盘旁边，而不是浮在背景上的控件。
3. 背景、账本、书签、购买区和状态标记来自同一套参考图和像素材质。
4. 保留当前商店业务能力：材料购买、配方解锁、技法解锁、Mira 折扣、关闭返回 DayMap。
5. 让后续新增商品依然可维护，动态文字仍由 Godot 渲染，不把商品名和价格画死进背景。
6. 用测试防止再次退化成“高质量背景 + 低细节矩形控件”。

## 非目标

- 不做完整商人立绘或完整角色动画。
- 不做出售系统。
- 不做多商品购物车。
- 不改变材料、配方、技法价格。
- 不改变 Mira 折扣计算。
- 不改变商店作为 DayMap 地点的入口逻辑。
- 不把所有商品文案静态烘焙进图片。

## 视觉构图

商店是完整 `1280x720` 全屏场景，native 源为 `320x180`。画面中心偏下是一本文字可读的大账本，左页承载商品列表，右页承载当前选中商品详情。账本下方和四周是柜台物件：钱袋、硬币盘、小算盘、印章、蜡烛、货箱、卷轴、瓶罐和零散纸条。

商人不完整入镜。可以在柜台后方或画面右上保留一只手、袖口、半截旅行背包、投在墙上的影子或货架后的轮廓。它只提供“有人经营”的存在感，不占用主要 UI 空间，也不成为完整角色立绘。

背景需要在生图阶段就为 UI 留出原生空间。账本页、书签、金币盘、印章和离开木牌都要作为画面中的真实物件出现，而不是在完成背景后再硬塞控件。

## 信息布局

左页是商品列表。商品项不再是独立卡片网格，而像账本上的条目、货单行或贴在账页上的小签。每条商品显示：

- 商品名。
- 单价。
- 已拥有或已掌握状态。
- 选中标记。

右页是详情。固定显示当前选中商品，没有选中时默认选第一个可用商品。详情内容包括：

- 商品名称。
- 一句短描述。
- 当前库存或拥有状态。
- 价格；Mira 日显示原价到折扣价。
- 用途说明；材料从配方数据反查，配方和技法从 UI 文案表读取。

底部柜台是结算区。金币显示放在钱袋或硬币盘旁；材料数量放在算盘或小木片旁；购买确认使用印章、签条或递金币的小盘；离开入口是柜台边缘木牌或账本角落签条。

## 分类与状态

分类入口是账本边缘的三枚书签：

- `材料`
- `配方`
- `技法`

选中分类时，书签被拉出、局部被琥珀灯照亮，或被蜡印/金线压住。不要使用现代 tab 的高亮逻辑。

商品选中态使用账本内的场景语言：蜡印、夹条、墨线框、小烛光或纸边阴影。不可购买或已拥有状态使用暗化条目和“已拥有 / 已掌握”印章感标记。Hover 可以有轻微墨痕或灯光变化，但不要变成通用按钮 hover。

Mira 折扣不需要完整米拉人物。折扣状态通过柜台上的小折扣签、特别钱袋、袖口/手影或一盏额外暖灯表现。价格文本显示 `2→1金` 这类短文本。

## 运行时结构

`ShopOverlay` 保留业务逻辑，但视觉层要重写为“场景底图 + 固定点击区域 + 自定义状态纹理/标记”。Godot `Button` 节点可以继续承担输入和焦点，但不能再显示普通控件外观，也不能用低细节矩形 StyleBox 主导画面。

建议保留或新增这些视觉节点：

- `SceneBackdrop`：全屏摊位场景。
- `BookLayer`：账本承载层，可能已融入背景，也可以作为透明叠层。
- `CategoryBookmarks`：三枚分类书签和选中态。
- `ItemRows`：账本左页固定点击区域。
- `DetailPage`：右页文本区域。
- `CoinTray`：金币显示区域。
- `QuantityAbacus`：材料数量区域。
- `PurchaseSeal`：购买确认区域。
- `CloseTag`：离开区域。
- `StateMarks`：选中、禁用、已拥有、折扣等标记。

文本仍由 Godot 动态渲染，字体使用现有 Fusion Pixel。文本颜色以墨色、旧金、暗暖白为主，避免纯白大面积覆盖背景。所有文本都必须落在账页、标签、木牌、签条或钱盘旁这种“本来可以写字”的区域。

## 数据与文案

`data/shop.json` 继续作为价格和解锁配置来源。UI 描述、用途和排序继续使用或扩展 `data/shop_ui.json`，避免把展示文案塞进经济配置。

材料用途从当前配方数据反查；如果反查为空，只显示短描述，不显示虚假用途。配方和技法用途由 `shop_ui.json` 提供，因为它们更像 UI 解释文案。

## 资产流水线

这次必须按完整闭环执行：

1. 生成或整理完整商店参考图，保留在 `assets/source/daymap/reference/` 或 `assets/source/daymap/shop_redesign/reference/`。
2. 从参考图归一化 native 源。主场景为 `320x180`，runtime 为 `1280x720`。拆分出的交互部件按 4x runtime 反推 native 尺寸。
3. 所有 runtime 纹理只通过整数倍最近邻导出。
4. `scripts/tools/export_daymap_shop_redesign_assets.py` 必须读取参考图并裁切/归一化核心资产，不能用 `ImageDraw` 手画核心控件。
5. native 源保存在 `assets/source/daymap/shop_redesign/`，runtime 纹理保存在 `assets/textures/daymap/shop_redesign/`。

核心资产至少包括：

- `shop_scene_native.png`
- `shop_book_native.png` 或等价账本承载层
- 分类书签 normal/selected
- 商品条目 normal/selected/disabled
- 购买印章 normal/pressed/disabled
- 离开木牌 normal/selected
- 数量控件或算盘相关状态
- 折扣、已拥有、已掌握状态标记

## 测试

### Python 资产测试

资产测试需要覆盖：

- reference 图存在且 exporter 明确引用。
- native 和 runtime 文件存在且尺寸正确。
- runtime 是 native 的 exact nearest-neighbor export。
- exporter 核心控件不使用 `ImageDraw` 或纯矩形手绘生成。
- 背景有足够暗青阴影、琥珀光、木柜台、账本纸面像素。
- 书签、商品条目、购买印章、离开木牌和状态标记有足够色阶和材质细节。
- 商品条目和按钮不能退化成低细节矩形块。

### Godot UI 测试

功能测试保留现有商店行为：

- 打开商店 overlay 后默认显示材料并选中第一项。
- 可切换材料、配方、技法。
- 材料可调数量并购买。
- 配方和技法是一次性解锁，已拥有后禁用购买。
- Mira 日显示折扣状态，普通日不显示。
- 关闭商店会隐藏 overlay 并恢复 DayMap。

视觉结构测试需要验证：

- 主场景、账本、书签、结算区、数量区、关闭牌节点存在。
- 点击区域可以是透明按钮或自定义 Control，但不能显示普通 Button 皮肤。
- 纹理过滤使用 nearest。
- 文本节点位于固定账本/标签/木牌区域。

### 手动验收

实现后至少检查：

- 第一眼能看出地下流浪商人摊位。
- 背景、账本和操作区是一体构图，不像 UI 浮在背景上。
- 没有完整商人，但能感到有人在经营。
- 商品信息可读，中文不挤、不盖住物件。
- 视觉密度接近标题页，避免大块扁平纸片和普通按钮。

## 风险与处理

- 参考图太好看但文字区不够读：生图提示词必须明确留出账本左右页和底部结算区的低噪声区域。
- 摊位物件过多导致 UI 混乱：文字密集信息只放账本，摊位物件只承载金币、数量、购买、关闭这些短信息。
- 状态资产数量膨胀：优先做少量通用状态标记，复用在商品条目和详情区。
- Godot 默认控件重新露出：测试检查核心按钮 style 是否透明或自定义，不允许普通控件皮肤回归。

## 验收标准

1. 商店打开后呈现为完整地下流浪商人摊位，而不是菜单弹窗。
2. 商品列表、详情、金币、数量、购买、离开都像场景物件的一部分。
3. 没有完整商人入镜，但有手、袖口、背包、影子或其他经营者存在感。
4. 所有核心视觉资产来自 native-pixel 管线，并有测试证明 exact nearest-neighbor 导出。
5. `ShopOverlay` 的业务行为与现有商店一致，材料、配方、技法、Mira 折扣和关闭返回都不回退。

## 2026-06-08 Master Composition Revision

The asset route is tightened to avoid a visible collage effect. The shop redesign now starts from one final-screen master composition retained as `assets/source/daymap/shop_redesign/reference/shop_master_composition_generated.png`.

- The master composition is the only production visual source consumed by `scripts/tools/export_daymap_shop_redesign_assets.py`.
- The old full-scene reference can remain as style history, but it is not the exporter input.
- A separate UI pieces sheet is not used for production assets, because independently generated pieces risk mismatched lighting, silhouette, and material language.
- `shop_scene_native.png` is the baked full-screen composition normalized to `320x180`.
- `shop_book_native.png`, bookmarks, item rows, seal, close tag, abacus, and status marks are fixed-region crops or state variants derived from the same master composition.
- Runtime interaction still uses transparent Godot `Control`/`Button` zones, but visual sprites stay aligned to the master composition instead of being freely re-arranged.
