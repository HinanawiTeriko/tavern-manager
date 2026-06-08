# 商店界面完整重做设计

- 日期：2026-06-08
- 状态：待用户复核
- 范围：DayMap 商店入口打开后的完整商店体验、视觉资产和 UI 结构

## 背景

当前商店已经从 DayMap 标签页改为地图上的探索地点，并已有一版地下杂货店方向的 UI 刷新：全屏 `shop_backdrop`、`panel_shop`、滚动列表、图标化数量按钮。这个方向解决了灰底和占位按钮问题，但商店内容仍然像调试列表：材料、配方、技法以横向文字行堆在同一个滚动区里，缺少商品陈列、选中详情、数量核算和开店前整备感。

本次重做不是继续修补列表，而是把商店做成一个有场景叙事和清晰决策的界面：玩家在白天进入地下商铺或米拉的旅行摊位，站在柜台前翻账册、选货、核对今晚需要什么，然后完成当前商品的购买操作。

## 设计目标

1. 商店第一眼要像游戏世界里的地下商铺，不像通用 RPG 商城或管理后台。
2. 玩家能快速判断“我买这个有什么用”，尤其是它能支持哪些今晚产品、配方或技法。
3. 材料、配方、技法三类商品有不同呈现，但共用同一套购买语言。
4. 米拉折扣和普通商店保持现有逻辑，但视觉上能体现“米拉在场”。
5. 所有新视觉资产遵守 native-pixel 管线：reference、native source、runtime texture、Pillow exporter、pipeline test。
6. 不改经济系统核心，不改价格表含义，不引入复杂库存或出售系统。

## 核心方向

采用“米拉摊位 + 开店前整备账册”的混合界面。

画面是完整 1280x720 商店场景：暗 teal 地下石墙、木柜台、货架、蜡烛、货箱、药草束、酒瓶和一本打开的账册。米拉在有折扣的日子出现在柜台侧或背景货架前；普通商店日则保留柜台和账册，但不显示米拉角色强调。

UI 不再浮在一块抽象面板里，而是嵌入账册和柜台：

- 左页：分类标签和商品网格。
- 右页：选中商品详情、用途、拥有数量、价格和折扣。
- 底部柜台条：金币、当前选中商品总价、购买按钮、离开按钮。

这让商店既有角色感，又保留“开店前补货”的实用性。

## 布局

### 全屏层级

1. 背景层：地下商铺或米拉旅行摊位，保留大面积暗背景，暖光只做视觉锚点。
2. 账册层：打开的账册占画面中下部，是主要 UI 承载面。
3. 商品层：商品格、分类标签、详情文本、数量控件和结算条。
4. 状态层：hover、selected、disabled、折扣标记、购买成功短反馈。

### 左页：分类和商品

左页顶部是分类标签：

- `材料`
- `配方`
- `技法`
- 预留 `特殊`，本次不启用

分类标签使用横向书签或账页侧边签，不使用现代页签样式。选中态是 amber 纸角/墨迹标记，hover 是低亮度刷痕。

商品区使用 2 列或 3 列小卡格，而不是文字行：

- 图标：材料图标、配方卷轴图标、技法符文图标。
- 名称：短中文名。
- 价格：金币图标 + 数字。
- 状态：已拥有、未解锁、折扣、买入数量。

材料商品支持数量步进；配方和技法是一次性解锁商品。

### 右页：详情和用途

右页始终显示当前选中商品，没有选中时默认选中第一个可买商品。

详情内容：

- 商品名称和类型。
- 描述：一句短说明，避免长文本。
- 当前拥有：材料显示库存数量，配方/技法显示已拥有或未掌握。
- 价格：普通价；米拉日显示原价到折扣价。
- 用途：列出该商品直接支持的产品、配方或能力效果。

用途是本次体验提升的重点。示例：

- 麦芽：可用于麦芽酒、肉汤。
- 草药麦酒配方：解锁后可制作草药麦酒。
- 冲击魔法·炖锅：允许用撞击方式制作炖锅类配方。

如果现阶段缺少完整反查数据，先实现保守版本：材料用途从现有 recipe 数据反查；配方/技法用途从 `shop.json` 或小型 UI 文案表读取。

### 底部结算条

底部是柜台上的结算条，不做悬浮现代 footer。

内容：

- 当前金币。
- 当前选中商品按数量计算出的总价。
- 购买按钮：材料按当前数量加入购买；配方/技法直接购买。
- 购买后反馈：短暂 amber 墨迹闪烁或小字“已补货 / 已解锁 / 已掌握”。
- 离开按钮放在右下或账册外侧，不抢主操作视觉权重。

本次不做购物车的多商品批量结算。材料数量选择后点击购买即结算；底部总价显示当前选中商品数量对应价格。这样能改善决策，但不引入购物车复杂度。

## 视觉语言

### 氛围

商店应该像地下酒馆世界的一角：

- 暗 teal 石墙和阴影。
- 深棕木柜台。
- 低饱和羊皮账页。
- Amber 蜡烛和灯笼点光。
- 少量瓶罐、货袋、药草、卷轴、木箱。

禁止方向：

- 亮金色高级商城。
- 现代弹窗、霓虹边框、玻璃拟态。
- 大面积单色棕黄，避免画面变成一整张旧纸。
- 把文字、商品名、价格直接画死在背景里。

### 米拉状态

米拉出现时，标题从 `商店` 变为 `米拉的旅行商店`，并显示折扣提示。视觉差异以背景角色和小装饰表现，不改变购买规则：

- 背景右侧出现米拉像素角色或旅行包剪影。
- 柜台上多一盏暖灯或一枚折扣小签。
- 价格显示 `原价 → 折扣价`。

普通商店日不显示米拉角色，但保留同一账册和商品结构。

## 资产管线

新增或替换资产仍归入 DayMap UI 管线。

目录：

```text
assets/source/daymap/shop_redesign/reference/
assets/source/daymap/shop_redesign/
assets/textures/daymap/shop_redesign/
scripts/tools/export_daymap_shop_redesign_assets.py
scripts/test/test_daymap_shop_redesign_asset_pipeline.py
```

资产建议：

- `shop_scene_native.png`：320x180 背景 native，runtime 1280x720。
- `shop_book_native.png`：账册承载层，可透明，native 尺寸按 4x runtime 反推。
- `shop_tab_*_native.png`：分类标签 normal/hover/selected。
- `shop_item_card_*_native.png`：商品格 normal/hover/selected/disabled。
- `shop_quantity_button_*_native.png`：数量按钮 normal/hover/pressed。
- `shop_purchase_button_*_native.png`：购买按钮 normal/hover/pressed/disabled。
- `shop_badge_discount_native.png`、`shop_badge_owned_native.png`：状态徽记。

如复用已有 `assets/textures/daymap/ui/` 的按钮或滚动条，必须保持 exact nearest-neighbor export 测试。新背景和账册不能直接使用 AI 生成 runtime 图，必须保留 reference 并通过 exporter 从 native 导出。

## 代码结构

当前 `_build_shop_ui()`、`_build_material_rows()`、`_build_recipe_rows()`、`_build_ability_rows()` 都在 `scripts/ui/day_map_view.gd` 内，重做后继续把商店挂在 DayMap 上，但应拆出更清晰的商店视图脚本，避免 DayMapView 继续膨胀。

建议新增：

- `scenes/ui/ShopOverlay.tscn`
- `scripts/ui/shop_overlay.gd`

`DayMapView` 只负责：

- 打开/关闭商店 overlay。
- 传入 `GameManager`。
- 保持地图隐藏、相机暂停、教程触发和离开恢复。

`ShopOverlay` 负责：

- 构建分类、商品格、详情页和结算条。
- 根据 `GameManager.shop`、`GameManager.craft`、`GameManager.inventory_sys` 刷新商品状态。
- 调用 `buy_material`、`buy_recipe_unlock`、`buy_ability`。
- 发出 `closed` 信号给 DayMapView。

## 数据和文案

现有 `data/shop.json` 保持价格来源。为 UI 描述和用途补充一个轻量文案层，优先不要污染经济配置。

可选新增：

```text
data/shop_ui.json
```

用途：

- 商品显示名覆盖。
- 商品短描述。
- 技法用途说明。
- 配方用途说明。
- 商品排序和分类显式配置。

材料用途可以从配方系统反查；如果反查结果为空，详情页显示短描述，不显示虚假用途。

## 测试

### Godot UI 测试

新增或扩展 DayMap 商店测试：

- 打开 `market_shop` 后实例化 `ShopOverlay`。
- 商店 overlay 使用 Fusion Pixel 字体。
- 分类至少包含材料、配方、技法。
- 默认选中第一个商品并显示详情。
- 材料商品有减量、数量、加量、购买按钮。
- 配方/技法已拥有时显示 disabled/owned 状态，不重复扣钱。
- 米拉日在价格区域显示折扣价，普通日不显示折扣态。
- 离开按钮能关闭 overlay 并恢复 DayMap。

### Python 管线测试

新增 asset pipeline 测试：

- native 和 runtime 文件存在且尺寸正确。
- runtime 是 native 的 exact nearest-neighbor export。
- 背景可见色数量、暖光像素、柜台/货架/账册像素达到最低阈值，避免退化成纯色占位。
- UI 透明层非空且 alpha 正确。
- 分类标签和商品卡状态有足够对比，hover/selected/disabled 可区分。

### 手动视觉验收

实现后至少检查：

- 1280x720 下文字不挤、不盖住商品格。
- 商店第一眼能看出柜台、账册和地下商铺。
- 米拉日在视觉上明显但不喧宾夺主。
- 商品用途说明能帮助玩家做购买决策。
- 不出现现代 UI 感、过亮黄纸感或纯表格感。

## 非目标

- 不做出售系统。
- 不做多商品购物车。
- 不改变材料、配方、技法价格。
- 不改变米拉折扣计算。
- 不改 Tavern 营业逻辑。
- 不把商店拆成新的地图地点逻辑；入口仍沿用现有 `market_shop`。
- 不把所有商品用途都写死进背景图。

## 验收标准

1. 商店打开后不再呈现为三段文字滚动列表，而是分类商品格 + 选中详情 + 当前购买操作。
2. 商店背景、账册和 UI 控件都来自 native-pixel 管线，并有测试证明 exact nearest-neighbor 导出。
3. `DayMapView` 不再承担主要商店 UI 构建逻辑，商店行为集中到独立 overlay 脚本。
4. 材料、配方、技法购买行为与当前系统一致，现有存档和折扣逻辑不受破坏。
5. 玩家能从详情页理解商品用途，至少材料能反查可制作产品，技法能说明解锁效果。
