# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## 项目定位

**地下城酒馆** — Godot 4.6 2D 模拟经营游戏。玩家是地牢小酒馆老板：白天去各地图采集/对话 → 夜晚在吧台后通过拖拽和手势合成食物饮料，服务冒险者。VA-11 Hall-A 式吧台视角。

- 引擎: Godot 4.6.x 标准版（非 .NET/Mono）
- 语言: GDScript
- 渲染: 2D, GL Compatibility, 1280×720
- 设计系统: "Hearth & Shadow" (`scripts/ui/theme_colors.gd`)

## 当前状态

- **分支**: `main`
- **阶段**: v0.2 — 5 场景流转、7 子系统、手势合成、商店、ThemeColors UI 设计系统、莱恩 3 天叙事线、米拉 2 天叙事线、香料系统
- **视角**: VA-11 Hall-A 式 2D 吧台视角

## 运行游戏

用 Godot 4.6.x 标准版编辑器打开项目目录，点击运行即可。无需编译。主场景: `res://scenes/ui/TitleScreen.tscn`。

导出: HTML5/Web（配置在 `export_presets.cfg`，输出到 `build/web/`）。

无测试、无 linter、无 CI/CD。

## 插件

| 插件 | 用途 |
|------|------|
| `addons/dialogue_manager/` | 对话引擎，解析 `.dialogue` 文件并驱动对话 UI |
| `addons/godot_mcp/` | Godot MCP，AI 通过 MCP 协议操控 Godot 编辑器 |

## 架构

### Autoload 单例

1. **GameManager** (`scripts/game_manager.gd`) — 顶层协调器，路径 `/root/GameManager`。持有 7 个子系统，管理库存、昼夜切换、客人到访、对话流程、上菜逻辑、采集结算、商店购买。各 View 通过 `register_view()` 注册。
2. **DialogueManager** (`addons/dialogue_manager/`) — 第三方对话引擎，解析 `.dialogue` 文件。

### 场景流转

```
TitleScreen ──"开始营业"──> DayMap ──"出发"──> Tavern ──"打烊"──> LedgerScreen
                                ↑                    │                   │
                                └── 下一天 ←────────┘              "继续" → DayMap
                                                                      (第30天 → EndingScreen)
```

- **TitleScreen** (`scenes/ui/TitleScreen.tscn`): 开始营业 → DayMap
- **DayMap** (`scenes/ui/DayMap.tscn`, 白天): 分配体力去采集点或商店购买。"出发" → 结算采集结果 → 进入 Tavern
- **Tavern** (`scenes/ui/Tavern.tscn`, 夜晚): 合成服务客人。"打烊" → LedgerScreen
- **LedgerScreen** (`scenes/ui/LedgerScreen.tscn`): 当晚账单总结。"继续" → 下一天（第30天进 EndingScreen）
- **EndingScreen** (`scenes/ui/EndingScreen.tscn`): 30 天后显示最终金币、声望、NPC 结局

### 7 个子系统（`scripts/systems/`，均为 RefCounted）

| 系统 | 文件 | 职责 |
|------|------|------|
| CraftSystem | `craft_system.gd` | 加载 `items.json`/`operations.json`，物品操作查询，合成规则（4 对硬编码组合），配方解锁 |
| DayCycleSystem | `day_cycle_system.gd` | 昼夜阶段枚举，体力（上限5），`phase_changed` 信号 |
| EconomySystem | `economy_system.gd` | 金币/声望追踪，酒馆等级（3 档基于声望），每日重置 |
| GuestSystem | `guest_system.gd` | 随机客人生成（2-5s 间隔），耐心倒计时（60s/重要客人 90s），12 人名字池，订单结算 |
| NarrativeManager | `narrative_manager.gd` | 加载 `npcs.json`，管理对话变量、好感度、关键道具、结局；按天和触发条件解析场景 |
| ShopSystem | `shop_system.gd` | 加载 `shop.json`，材料定价，配方解锁定价，米拉 8 折 |
| SeasoningSystem | `seasoning_system.gd` | 加载 `seasonings.json`，香料查询和验证 |

### UI 层（`scripts/ui/`）

- **View**: `tavern_view.gd`（酒馆主界面）、`day_map_view.gd`（白天大地图，含商店 Tab）、`title_screen.gd`（标题界面）、`ending_screen.gd`（结局结算）、`ledger_screen.gd`（打烊账单）
- **合成交互**: `craft_station.gd`（拖拽 + 手势）、`mixing_area.gd`（合成区拖放）、`seasoning_zone.gd`（三状态：空/有成品/已撒香料）、`product_panel.gd`（产品展示）
- **设计系统**: `theme_colors.gd`（"Hearth & Shadow" 全局配色 + StyleBox 工厂）、`tavern_theme.gd`（面板/按钮/格子/进度条构造器）、`tavern_tween.gd`（动画工具：弹跳、抖动、脉冲、浮入、滑动、打字机效果、拖拽挤压等）
- **可复用组件**（`scripts/ui/components/`）: `tavern_button.gd`、`tavern_label.gd`（HDR/BODY/DIM 三级文本）、`tavern_panel.gd`（可选辉光）、`tavern_slot.gd`（MATERIAL/RESULT/SHORTCUT 三种样式）、`tavern_bar.gd`（带流动动画的进度条） — 均标记 `@tool` 支持编辑器预览
- **工具**: `texture_manager.gd`（安全纹理加载，带缓存和降级）、`title_ambience.gd`（标题画面粒子效果：星星 + 粉尘）

### 关键文件速查

| 文件 | 说明 |
|------|------|
| `project.godot` | 引擎配置，Autoload: GameManager + DialogueManager，主场景入口，输入映射 |
| `scripts/game_manager.gd` | Autoload 顶层协调器，库存/快捷栏/配方/拖拽/对话 |
| `scripts/systems/craft_system.gd` | 配方匹配、操作图查询、合成规则 |
| `scripts/systems/day_cycle_system.gd` | 昼夜循环、日期推进、体力管理 |
| `scripts/systems/economy_system.gd` | 金币/声望/酒馆等级 |
| `scripts/systems/guest_system.gd` | 客人生成、耐心倒计时、结算 |
| `scripts/systems/shop_system.gd` | 商店配置、材料售价、配方解锁 |
| `scripts/systems/seasoning_system.gd` | 香料数据加载、查询 |
| `scripts/systems/narrative_manager.gd` | NPC 剧情配置、对话变量、好感度 |
| `scripts/ui/craft_station.gd` | 合成台手势组件（拖拽/加热/摇晃/搅拌） |
| `scripts/ui/mixing_area.gd` | 合成区拖放台 |
| `scripts/ui/seasoning_zone.gd` | 香料台（三状态拖放：空/有成品/已撒香料） |
| `scripts/ui/product_panel.gd` | 产品展示面板 |
| `scripts/ui/tavern_view.gd` | 酒馆营业主界面 |
| `scripts/ui/day_map_view.gd` | 白天大地图界面（含商店标签页） |
| `scripts/ui/theme_colors.gd` | 全局配色 + StyleBox 工厂 |
| `assets/themes/hearth_and_shadow.tres` | 统一 Theme 资源，替代逐个节点覆盖 |
| `scripts/ui/texture_manager.gd` | 纹理加载缓存工具 |
| `scripts/ledger_data.gd` | 账单数据结构 |
| `scripts/main/main_init.gd` | Main 场景初始化 |
| `scenes/ui/Tavern.tscn` | 酒馆营业场景 |
| `scenes/ui/DayMap.tscn` | 白天大地图场景 |
| `scenes/ui/TitleScreen.tscn` | 标题场景 |
| `scenes/ui/EndingScreen.tscn` | 结局场景 |
| `scenes/ui/LedgerScreen.tscn` | 打烊账单场景 |
| `scenes/main/Main.tscn` | 主入口容器 |

### 文档速查

| 文档 | 说明 |
|------|------|
| `docs/01_AI开发规范.md` | 目录结构、路径规则、禁止事项 |
| `docs/02_AI项目速查.md` | 系统架构、场景布局、配方表、参数、设计系统 |
| `docs/03_资源清单.md` | v0.2 资源：场景/脚本/数据文件/ThemeColors/美术 |
| `docs/04_游戏总览.md` | 游戏定位、体验目标、技术规格、开发状态 |
| `docs/05_核心机制.md` | 已实现系统规则：合成/客人/经济/昼夜/对话 |
| `docs/06_游戏重制策划案.md` | 2D 重制设计：场景/循环/NPC叙事/合成/经济 |
| `docs/07_美术需求文档.md` | 像素风资源清单、配色表、各场景需求、优先级 |
| `docs/superpowers/specs/` | 8 份功能规格文档（账本、商店、对话、合成重设计、迁移、香料站、UI 重设计、开发流程） |
| `docs/superpowers/plans/` | 9 份实现计划文档 |

### 合成流程

1. 从快捷栏拖材料 → MixingArea
2. 两个不同材料 → 合并提示 → 生成中间产物
3. 根据 `operations.json` 出现操作按钮（加热/搅拌/摇晃/倒出）
4. 加热 = 按住 1.5s；搅拌 = 3 次鼠标画圈
5. 单个物品无可操作步骤 → 自动移到 Result Slot
6. Result Slot → 拖入 SeasoningZone → 从快捷栏拖香料调味
7. 调味成品 → 拖到 Customer Zone 上菜

### 数据流

- 所有游戏数据在 `GameManager._ready()` 中从 `data/*.json` 加载
- 游戏状态保存在 GameManager + 子系统实例中
- GameManager↔View: 直接方法调用 + Godot 信号（`guest_arrived`、`phase_changed`、`inventory_changed`、`serve_requested`）

## 新系统设计原则（强制）

### 低耦合、高内聚

- **子系统不直接互相引用**。所有跨系统调用通过 `GameManager` 中转，子系统之间不 `import`/`load` 彼此。
- **通信走信号**。子系统暴露信号，由 `GameManager` 或 View 层监听连接，不直接调用其他子系统的方法。
- **数据驱动**。系统只依赖自己加载的 `data/*.json` 和 `GameManager` 注入的共享状态副本，不持有其他系统的引用。

### 独立性检查清单

在设计/评审一个新系统时，逐条确认：

1. **RefCounted 优先**。新系统优先用 `RefCounted`，只在不涉及场景树的纯逻辑时才考虑 Node。当前 7 个子系统全部为 RefCounted。
2. **能单独测试**。新系统能不能不依赖其他系统单独构造并调用核心方法？
3. **能描述边界**。这个系统的输入是什么（JSON 配置/GameManager 注入）？输出是什么（信号/方法返回值）？
4. **能回答"不该做什么"**。例：CraftSystem 管配方但不问库存够不够 — 那是 GameManager 的事。

### 接入方式

```
新系统（scripts/systems/xxx_system.gd，RefCounted）
    ↓ 构造 + 注入依赖
GameManager（scripts/game_manager.gd，Autoload）
    ↓ 注册/方法调用
View 层（scripts/ui/*.gd，信号监听 + 方法调用）
```

- 新系统在 `GameManager._ready()` 中构造并持有引用
- 构造时注入它需要的只读数据（JSON 字典）或回调，不传递其他系统的引用
- View 层通过 `GameManager` 访问系统，不直接持有子系统引用
- 系统对 View 层不可见：View 只知道 GameManager 暴露的接口

### 反例

| 错误做法 | 正确做法 |
|----------|----------|
| `guest_system.gd` 里 `var craft = load("res://...")` | 通过 GameManager 协调两个系统 |
| View 持有 `CraftSystem` 引用调用其方法 | View 调 `GameManager.craft_item()`，GameManager 再做分发 |
| 新系统是 `Node` 需要手动 `add_child` | 用 `RefCounted`，由 GameManager 全权管理生命周期 |

## 配方表（9 种）

| Key | 名称 | 材料 | 价格 |
|-----|------|------|------|
| Ale | 麦芽酒 | 麦芽 | 5 金 |
| Wine | 葡萄酒 | 葡萄 | 5 金 |
| Bread | 面包 | 面粉 | 3 金 |
| Meat | 烤肉 | 生肉 | 4 金 |
| Herb Tea | 草药茶 | 草药 | 3 金 |
| Herbal Ale | 草药麦酒 | 麦芽 + 草药 | 10 金 |
| Meat Stew | 肉汤 | 生肉 + 麦芽 | 12 金 |
| MeatSand | 肉夹面包 | 面粉 + 生肉 | 9 金 |
| SpicedWine | 香料红酒 | 葡萄 + 草药 | 11 金 |

定义: 由 `CraftSystem` 加载 `data/items.json` 和 `data/operations.json` 管理合成规则。

## 香料系统

| Key | 名称 | 效果 |
|-----|------|------|
| spice | 辣 | 口味标签 |
| herb_spice | 香草 | 口味标签 |
| salt | 咸 | 口味标签 |
| sleep_powder | 迷睡花粉 | 口味标签 + 消耗库存 |

交互流程：成品 → 拖入 SeasoningZone → 从快捷栏拖香料撒入 → 拖出给客人

定义: `data/seasonings.json` → `SeasoningSystem`

## 目录规范（强制）

### 场景/脚本分离
- `.tscn` → 只放 `scenes/`
- `.gd` → 只放 `scripts/`
- **禁止混放到同一目录**

### 脚本子目录

| 类型 | 位置 |
|------|------|
| Autoload 单例 | `scripts/` 根目录 |
| 系统逻辑 | `scripts/systems/` |
| UI 逻辑 | `scripts/ui/` |
| 场景入口 | `scripts/main/` |
| 挂载节点脚本 | `scripts/components/` |

### 场景子目录

| 类型 | 位置 |
|------|------|
| 游戏实体 | `scenes/entities/` |
| 关卡/地图 | `scenes/levels/` |
| 主入口 | `scenes/main/` |
| UI | `scenes/ui/` |

### 路径规范
- 所有 `load`/`preload` 使用完整 `res://` 路径
- 资源只放 `assets/` 子目录

## 禁止事项

- 不修改 `addons/` 下任何文件
- 不在项目根目录散落 `.gd`/`.tscn`
- 不将业务代码放 `addons/`
- 不新建 `src/` 目录
- 不将 `scripts/` 和 `scenes/` 合并

## 开发流程（强制）

**上一阶段未完成，不进下一阶段。**

1. **Spec** — 需求写 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`，确认后才往下
2. **Plan** — 拆任务写 `docs/superpowers/plans/`，每个任务 ≤1 文件，确认后才往下
3. **Worktree** — 创建 `feature/<topic>` 分支隔离开发
4. **编码** — 严格按 plan 顺序，每任务完成立即验证，禁止顺手重构，禁止加 plan 外功能
5. **验证** — Godot 跑起来走核心路径 + 回归检查，0 errors 0 warnings
6. **Review** — 过 diff：多余改动/null 引用/死代码/资源泄漏，问题清零
7. **Commit** — 格式 `type: 简述`（feat:/fix:/refactor:/docs:）

**一次对话只做一个功能。** 上下文膨胀就重开，用 spec/plan 文档恢复。Spec 和 Plan 未确认前不写代码。

## NPC 对话文件规范

重要 NPC 对话拆成两个文件：
- `{npc_id}_day{N}.pre.dialogue` — 点单对话（上菜前）
- `{npc_id}_day{N}.post.dialogue` — 反馈对话（读取 `serve_result` 变量 `"success"` / `"fail"`，由 GameManager 设置，通过 NarrativeManager 的 dialogue_vars 传递）

`npcs.json` 中的 `dialogue` 字段为历史遗留，当前代码按上述命名约定自动拼接路径。

当前对话文件：
| 文件 | 说明 |
|------|------|
| `dialogue/ryan_day1.pre/post.dialogue` | 莱恩第 1 天 |
| `dialogue/ryan_day2.pre/post.dialogue` | 莱恩第 2 天 |
| `dialogue/ryan_day3.pre/post.dialogue` | 莱恩第 3 天 |
| `dialogue/mira_day4.pre/post.dialogue` | 米拉第 4 天 |
| `dialogue/mira_day12.pre/post.dialogue` | 米拉第 12 天（好感度门槛） |

## 游戏参数

| 参数 | 值 | 位置 |
|------|-----|------|
| 客人耐心 | 60s（重要客人 90s） | `guest_system.gd` |
| 生成间隔 | 2-5s 随机 | `guest_system.gd._next_spawn` |
| 快捷栏 | 10 格（键盘 0-9） | `craft_station.gd.bar_materials` |
| 手势加热时长 | 1.5s 按住 | `craft_station.gd.HEAT_TIME` |
| 游戏天数 | 30 天 | `day_cycle_system.gd` |
| 客人名池 | 12 个 | `guest_system.gd` |
| 体力上限 | 5 点 | `day_cycle_system.gd` |

## 输入映射

| 动作 | 按键 | 功能 |
|------|------|------|
| menu_toggle | E | 打开/关闭配方+背包菜单 |
| 拖拽/放下 | 鼠标左键 | 拿起 / 放下材料 |
| 逐个退回 | 拖拽中鼠标右键 | 退回单个材料 |
| 全部退回 | 非拖拽时鼠标右键 | 退回合成区所有材料 |

## 关键数据文件

| 文件 | 内容 |
|------|------|
| `data/items.json` | 25 个物品定义（材料+中间产物+成品），含名称、颜色、价格 |
| `data/operations.json` | 合成操作图（加热/搅拌/摇晃/倒出的转换规则） |
| `data/locations.json` | 5 个采集点，含消耗和材料池 |
| `data/npcs.json` | 2 个 NPC（ryan, mira），含场景、订单、结局 |
| `data/shop.json` | 材料售价、配方解锁价格、米拉折扣 0.8 |
| `data/seasonings.json` | 4 种香料（spice, herb_spice, salt, sleep_powder） |
| `data/inventory_default.json` | 初始库存：5 种基础材料各 20 个 |
