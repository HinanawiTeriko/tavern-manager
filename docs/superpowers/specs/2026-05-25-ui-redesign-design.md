# UI 重新设计 — 炉火酒馆风格

## 目标

将 5 个场景的 UI 从硬编码绝对定位重建为自适应容器布局，同时应用 Balatro 式俏皮动效 + 酒馆主题装饰，让玩家一看就想玩。

## 风格方向：炉火酒馆

- **灵感**：Balatro 的俏皮动效和统一感，但装饰元素用酒馆主题（非扑克牌）
- **氛围**：温暖古朴，壁炉摇曳，木质框架，铁钉铆接
- **动效密度**：丰富，几乎每个交互都有微反馈
- **分辨率适配**：自适应拉伸，Container + anchors_preset=15

## 三层设计系统

### 基础层 — ThemeColors 升级

保留现有配色，新增炉火扩展色：

```
# 新增色
HEARTH_GLOW     = #FF6B2B  — 壁炉光晕、高亮脉动
EMBER_RED       = #CC4411  — 警告/耐心低
CANDLE_YELLOW   = #FFD480  — 蜡烛光、次要强调
WOOD_DARK       = #2A1E14  — 木板深色、面板底色
WOOD_MID        = #3D2B1A  — 木板中间色
WOOD_LIGHT      = #5C4030  — 木框边框
IRON_GRAY       = #4A4540  — 铁钉、铆钉
NAIL_HIGHLIGHT  = #7A7570  — 铁钉高光
```

新增 `TavernTheme` 类（`scripts/ui/tavern_theme.gd`），统一管理 StyleBox 工厂，替代各脚本中散落的 `add_theme_*_override` 调用。

### 组件层 — 自定义控件

| 组件 | 文件 | 说明 |
|------|------|------|
| `TavernButton` | `scripts/ui/components/tavern_button.gd` | 铁钉风格按钮，内置 squish 弹跳动效 |
| `TavernSlot` | `scripts/ui/components/tavern_slot.gd` | 酒桶/木箱风格格子，支持物品图标+角标，3 种变体：material/result/shortcut |
| `TavernPanel` | `scripts/ui/components/tavern_panel.gd` | 木框圆角面板，内阴影+壁炉光晕可选 |
| `TavernBar` | `scripts/ui/components/tavern_bar.gd` | 进度条，流光填充动效 |
| `TavernLabel` | `scripts/ui/components/tavern_label.gd` | 统一排版，三级：hdr/body/dim |

### 动效层 — TavernTween

`scripts/ui/tavern_tween.gd`，静态工具类：

| 方法 | 效果 | 时长 |
|------|------|------|
| `bounce_in(node, delay)` | scale 0→1.1→1 | 0.35s |
| `bounce_out(node)` | scale 1→1.1→0 | 0.25s |
| `pulse_glow(node, color)` | modulation 循环脉动 | 循环 2s |
| `shake(node, intensity)` | 水平抖动 | 0.3s |
| `float(node, amplitude)` | 缓慢上下漂浮 | 循环 3s |
| `fill_flow(bar_node)` | 进度条流光 | 循环 1.5s |
| `squish(node)` | 按下回弹 | 0.2s |
| `slide_in_bottom(node)` | 从底部滑入 | 0.3s |
| `typewriter(label, text, speed)` | 逐字显示 | 40ms/字 |
| `portrait_bounce(node)` | 角色头像弹入 | 0.3s |
| `choice_stagger(nodes)` | 选项逐个弹入 | 0.1s 间隔 |
| `emotion_shake(node)` | 对话框抖动 | 0.3s |
| `emotion_pulse(node, color)` | 对话框发光 | 0.5s |
| `slide_out_bottom(node)` | 底部滑出 | 0.25s |
| `drag_squish(node)` | 拖起压缩 | 0.15s |
| `drop_bounce(node)` | 放下弹跳 | 0.25s |
| `return_fly(node, target)` | 飞回快捷栏 | 0.3s |
| `spice_sprinkle(node)` | 香料撒入粒子 | 0.4s |

原则：每个动效 ≤0.4s；stagger 交错延迟产生节奏感；持续动效用 set_loops() 不占主通道。

## StyleBox 设计

| 组件 | 样式 |
|------|------|
| `TavernPanel` 木框面板 | WOOD_DARK 底 + WOOD_LIGHT 边框2px + 内阴影，角圆8px |
| `TavernButton` 铁钉按钮 | AMBER 底 + 深色1px边框 + 底部3px加粗，角圆6px，hover 变亮，press 下沉1px |
| `TavernSlot.material` 酒桶格 | WOOD_MID 底 + 虚线内框，角圆10px，放入物品时实线+发光 |
| `TavernSlot.shortcut` 木箱格 | WOOD_DARK 底 + 铁钉角标，选中时边框变 AMBER |
| `TavernBar` 进度条 | 暗底 + 流光填充，渐变 AMBER→HEARTH_GLOW |

## 场景布局

### Tavern — 酒馆营业（最复杂，优先级最高）

```
Tavern (Node2D)
├── Background (Sprite2D) — 壁炉背景 + 光晕动效层
├── UILayer (CanvasLayer)
│   ├── Root (VBoxContainer, anchors_preset=15, full rect)
│   │   ├── TopBar (TavernPanel, HBoxContainer)
│   │   │   ├── 🪙 金币 (TavernLabel.hdr)
│   │   │   ├── ⭐ 声望 (TavernLabel.body)
│   │   │   ├── 天数 (TavernLabel.dim)
│   │   │   ├── Spacer (Control, h_expand)
│   │   │   ├── 菜单 (TavernButton.small)
│   │   │   └── 打烊 (TavernButton.small)
│   │   │
│   │   ├── MainArea (HBoxContainer, v_expand)
│   │   │   ├── CustomerZone (TavernPanel, VBoxCenter, h_expand)
│   │   │   │   ├── 角色立绘 (TextureRect, expand)
│   │   │   │   ├── 名字+点单 (VBox)
│   │   │   │   └── 耐心条 (TavernBar)
│   │   │   │
│   │   │   └── CraftZone (VBoxContainer, h_expand)
│   │   │       ├── MixingArea (TavernPanel, HBoxWrap)
│   │   │       │   └── 材料 Slot ×3 (TavernSlot.material)
│   │   │       ├── RightSide (HBoxContainer)
│   │   │       │   ├── ResultSlot (TavernSlot.result)
│   │   │       │   └── SeasoningZone (TavernSlot.seasoning)
│   │   │       └── ActionBar (HBox)
│   │   │           ├── 混合/是/否 (TavernButton)
│   │   │           └── 清空 (TavernButton.small)
│   │   │
│   │   ├── ShortcutBar (TavernPanel, HBoxContainer)
│   │   │   └── Slot 0-9 (TavernSlot.shortcut)
│   │   │
│   │   └── BottomBar (TavernPanel)
│   │       └── 消息 (TavernLabel.dim)
│   │
│   ├── DialogueOverlay (ColorRect, full rect, 半透明 + slide 动效)
│   └── OverlayMenu (TavernPanel, center anchor)
│       ├── TabBtns (HBox: 配方 | 背包, TavernButton)
│       ├── Content (ScrollContainer)
│       └── CloseBtn (TavernButton)
```

动效分配：

| 触发 | 动效 |
|------|------|
| 客人到来 | portrait_bounce |
| 耐心条 | fill_flow（持续） |
| 合成成功 | bounce_in（成品） |
| 合成失败 | shake（合成台） |
| 上菜点击 | squish（客人区域） |
| 壁炉 | pulse_glow（持续） |
| 蒸汽 | float（持续） |
| 对话开始 | slide_in_bottom |
| 对话文字 | typewriter |
| 对话选项 | choice_stagger |
| 拖起材料 | drag_squish |
| 放下材料 | drop_bounce |
| 退回材料 | return_fly |
| 撒香料 | spice_sprinkle |

### TitleScreen — 标题界面

```
TitleScreen (Node2D)
├── Background (Sprite2D) — 壁炉暖光背景
├── Deco (Node2D) — 蜡烛/酒杯/徽章
├── UILayer (CanvasLayer)
│   └── Root (VBoxContainer, anchors_preset=15, center)
│       ├── Spacer (v_expand)
│       ├── TitlePanel (TavernPanel)
│       │   ├── TitleSign (TextureRect)
│       │   └── TitleLabel (TavernLabel.hdr) "地下城酒馆"
│       ├── SubtitleLabel (TavernLabel.dim)
│       ├── StartButton (TavernButton) "开始营业"
│       ├── HintLabel (TavernLabel.dim)
│       └── VersionLabel (TavernLabel.dim, 右对齐)
```

动效：标题 bounce_in、蜡烛 pulse_glow（持续）、按钮 float（待机）、点击 squish。

### DayMap — 白天地图

```
DayMap (Node2D)
├── Background (Sprite2D)
├── UILayer (CanvasLayer)
│   └── Root (VBoxContainer, anchors_preset=15)
│       ├── TopBar (TavernPanel, HBox)
│       │   ├── 天数 (TavernLabel.hdr)
│       │   ├── Spacer (h_expand)
│       │   ├── 金币 (TavernLabel.body)
│       │   └── 体力 (TavernBar)
│       ├── MapArea (TavernPanel, v_expand)
│       │   ├── TitleLabel (TavernLabel.hdr)
│       │   └── LocationList (VBox, ScrollContainer)
│       │       └── LocationRow ×N (TavernButton.toggle)
│       ├── GoButton (TavernButton) "出发！"
│       └── ResultPanel (TavernPanel, center anchor, hidden)
│           ├── ResultLabel (TavernLabel.body)
│           └── ContinueBtn (TavernButton)
```

动效：地点行 bounce_in（stagger）、体力 fill_flow（持续）、结果 bounce_in。

### LedgerScreen — 打烊账单

```
LedgerScreen (Node2D)
├── Background (ColorRect, 羊皮纸色)
├── UILayer (CanvasLayer)
│   └── Root (VBoxContainer, anchors_preset=15, center)
│       ├── TitleLabel (TavernLabel.hdr) "今日账单"
│       ├── StatsList (VBox, v_expand)
│       │   └── StatRow ×N (HBox: 图标+标签+数值)
│       ├── FateTitle (TavernLabel.hdr)
│       ├── FateList (VBox, ScrollContainer)
│       └── ContinueBtn (TavernButton) "继续"
```

动效：账单行 bounce_in（stagger）。

### EndingScreen — 结局

```
EndingScreen (Node2D)
├── Background (Sprite2D)
├── UILayer (CanvasLayer)
│   └── Root (VBoxContainer, anchors_preset=15, center)
│       ├── TitleLabel (TavernLabel.hdr) "旅程终结"
│       ├── Stats (HBox, 居中)
│       ├── NPCEndingsList (VBox, ScrollContainer, v_expand)
│       ├── RestartBtn (TavernButton) "重新开始"
│       └── QuitBtn (TavernButton) "退出"
```

动效：结局卡片 bounce_in（stagger）。

## 装饰元素实现

- **壁炉光晕**：Sprite2D 上叠加半透明 ColorRect + pulse_glow tween
- **铁钉角标**：StyleBoxFlat 的 border + corner_detail 绘制，4px IRON_GRAY 圆点
- **木纹分隔**：快捷栏格子间 1px WOOD_LIGHT 线
- **合成台装饰条**：底部 HBox 内绘制铁链纹理 StyleBox
- **标题蜡烛**：Sprite2D + pulse_glow + float

所有装饰主要通过 StyleBox 组合实现，尽量不依赖额外美术资源。

## 实现顺序

1. 设计系统（TavernTheme + TavernTween + 5 个自定义控件）
2. Tavern 场景重建
3. DayMap 场景重建
4. TitleScreen 场景重建
5. LedgerScreen 场景重建
6. EndingScreen 场景重建

每个场景完成后立即运行验证：核心路径走通 + 回归检查 + 0 errors 0 warnings。

## 脚本适配

场景节点路径变化后，需要同步修改引用这些路径的脚本：

- `game_manager.gd` — 可能引用 Tavern 子节点
- `tavern_view.gd` — 主要适配对象
- `craft_station.gd` — 合成台子节点路径
- `mixing_area.gd` — 混合区子节点路径
- `product_panel.gd` — 产品面板子节点路径
- `seasoning_zone.gd` — 香料区子节点路径
- `day_map_view.gd` — DayMap 子节点路径
- `title_screen.gd` — TitleScreen 子节点路径
- `ledger_screen.gd` — LedgerScreen 子节点路径（如存在）

适配原则：节点名称保持一致，只改结构层级和布局方式，最小化脚本改动。

## 约束

- 不修改 `addons/` 下任何文件
- 不将业务代码放 `addons/`
- 自定义控件放 `scripts/ui/components/`
- 遵循 CODEBUDDY.md 目录规范：.gd → scripts/，.tscn → scenes/
- 对话动效不修改 Dialogue Manager 插件本身，在调用层包装
