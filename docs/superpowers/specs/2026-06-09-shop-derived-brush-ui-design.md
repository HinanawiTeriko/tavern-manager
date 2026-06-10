# 商店派生笔刷 UI 重做设计

- 日期：2026-06-09
- 状态：待复核
- 范围：DayMap 商店 overlay 的视觉结构、资产管线和 Godot UI 接入

## 背景

当前商店大账本方案虽然走了 native-pixel 管线，但方向不对。它把商店做成了“场景插画 + 叠加 UI”，导致背景、书页、按钮和运行时文字彼此割裂。主菜单和设置菜单表现更好，是因为它们使用了统一的暗青笔刷 UI 语言：低噪声可读区、破碎笔刷边缘、少量琥珀强调、像素字体和清晰控件节奏。

本次重做不复用主菜单资产原图，而是从 `assets/source/ui/menu_brush_components_approved.png` 的视觉语法派生一套商店专用 UI kit。目标是让商店第一眼属于同一套主界面美术体系，同时保持商店自己的功能结构和商业气质。

## 设计原则

1. 派生，不复用。商店资产可以参考主菜单笔刷的颜色、边缘、噪声密度和强调方式，但不能把 `menu_brush_panel.png`、`menu_brush_band.png`、`menu_brush_tab.png` 原样作为主体控件。
2. 先 UI，后氛围。先在 `1280x720` 运行时布局中确认商品列表、详情、金币、数量、购买、关闭都清楚可读，再制作美术资产。
3. 背景退后。商店可以有暗色柜台、货架、商人剪影或灯光，但背景只提供场景情绪，不承担主要信息，不抢文字面板。
4. 暗青为主体，琥珀为强调。大面积 UI 保持深 teal；琥珀只用于选中态、价格、购买确认、hover 标记和少量装饰。
5. 动态文字仍由 Godot 渲染。商品名、价格、描述、库存、折扣和状态不烘焙进图片。
6. 所有新 runtime PNG 必须来自 native 源的整数最近邻导出，并保留确定性 Pillow exporter 和测试。

## 视觉方向

商店界面采用“派生笔刷管理面板”而不是“大账本场景”。画面由一个暗色商店背景和一组商店专用笔刷面板组成。

左侧是商品列表区域：五条商店专用 item row，每条有足够低噪声文本区、价格区和状态区。行轮廓继承主菜单笔刷的毛边，但比例更紧凑，更像货单条。

右侧是详情区域：一个更大的商店详情 panel，内部可容纳名称、描述、用途和状态。它继承主菜单大面板的暗青块面和破碎边缘，但比例与商店详情内容匹配。

顶部是分类区：材料、配方、技法三枚商店专用 category tab。选中态使用琥珀刷痕或下沿亮边，而不是现代 tab 高亮。

底部是结算区：金币状态、数量控制、购买按钮、离开按钮。它们使用同一套商店 brush 语言，购买按钮可以有更强的琥珀/蜡印强调，但仍保持暗色主体。

背景为低对比度地下商店氛围：柜台、货架、少量瓶罐、商人剪影或手部存在感。背景不能出现亮羊皮纸大块，也不能出现会和 UI 文字争抢注意力的高密度细节。

## 资产结构

新增商店笔刷资产目录：

```text
assets/source/daymap/shop_brush/reference/
assets/source/daymap/shop_brush/
assets/textures/daymap/shop_brush/
scripts/tools/export_daymap_shop_brush_assets.py
scripts/test/test_daymap_shop_brush_asset_pipeline.py
```

保留 `menu_brush_components_approved.png` 作为风格母版，并新增一张或多张商店专用 reference sheet。reference sheet 可以由人工整理、生成图修整或程序辅助构成，但最终 exporter 必须从商店专用 native 源导出 runtime 资产。

核心导出资产：

- `shop_brush_backdrop.png`：暗色商店背景，低对比度。
- `shop_brush_panel_detail.png`：详情大面板。
- `shop_brush_panel_list.png`：列表容器或列表底板。
- `shop_brush_row_normal.png`
- `shop_brush_row_hover.png`
- `shop_brush_row_selected.png`
- `shop_brush_row_disabled.png`
- `shop_brush_category_normal.png`
- `shop_brush_category_selected.png`
- `shop_brush_button_normal.png`
- `shop_brush_button_hover.png`
- `shop_brush_button_pressed.png`
- `shop_brush_button_disabled.png`
- `shop_brush_quantity.png`
- `shop_brush_status_owned.png`
- `shop_brush_status_discount.png`
- `shop_brush_divider.png`
- `shop_brush_hover_marker.png`

旧 `assets/textures/daymap/shop_redesign/` 大账本资产不作为新主结构使用。可以保留在仓库中作为历史资产，除非后续明确清理。

## Godot 结构

`ShopOverlay` 保留现有业务逻辑：分类切换、默认选中、材料购买、配方解锁、技法解锁、Mira 折扣、关闭返回 DayMap。

视觉节点改为 brush UI 结构：

- `ShopBackdrop`：全屏暗色背景。
- `MainBrushPanel`：主商店面板容器。
- `CategoryTabs`：三枚分类标签。
- `ItemList`：五条商品行。
- `DetailPanel`：选中商品详情。
- `CheckoutBar`：金币、数量、购买、离开。
- `StateMarks`：已拥有、折扣、禁用、选中等状态标。

Godot `Button` 仍可作为输入区，但可见外观必须来自商店 brush 纹理或透明区域，不能显示普通 Godot 控件皮肤。所有 TextureRect 使用 nearest filtering。

## 布局约束

- 分辨率基准为 `1280x720`。
- 左侧列表固定显示最多五行，行高保持稳定，动态文本不改变布局。
- 商品名称、价格、库存和状态必须各有固定文本区域。
- 详情区中文描述必须有可换行空间，不能压到边缘毛刷。
- 购买按钮和离开按钮不能仅靠文字区分，必须有明确位置和状态纹理。
- 数量控制只在材料分类显示；配方和技法分类隐藏数量控制但结算区不能显得空洞。

## 测试要求

Python 资产测试：

- 商店 brush reference/source/runtime 文件存在。
- runtime 是 native 的 exact nearest-neighbor export。
- 商店 brush 资产不是直接复制主菜单 runtime PNG；尺寸、字节内容或 alpha 轮廓必须有差异。
- 主色保持暗 teal，琥珀像素占比受控，不能变成大面积亮黄。
- 商品行和详情面板中部有足够低噪声可读区域。
- hover/selected/disabled 状态互不相同。

Godot UI 测试：

- `ShopOverlay` 使用新 `shop_brush` 纹理路径。
- 旧 `BookLayer` / 大账本主结构不再作为核心节点。
- 分类、列表、详情、结算和关闭节点存在。
- 透明按钮不显示普通皮肤。
- 纹理过滤为 nearest。
- 原有购买、解锁、折扣和关闭行为不回退。

## 验收标准

1. 商店第一眼与主菜单/设置菜单属于同一套 UI 美术语言，但不是原资产拼贴。
2. 商品列表和详情信息清楚、稳定、可读。
3. 背景提供商店氛围，但不抢 UI。
4. 不再出现大面积亮羊皮纸、翻开大账本或高细节插画压住界面的效果。
5. 所有新商店 UI 资产都有 native 源、runtime 导出和测试证明。

