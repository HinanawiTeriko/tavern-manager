# 地下城酒馆 — 项目速查

## 项目定位

**地下城酒馆** — Godot 4.6 **2D** 模拟经营游戏。
玩家是地牢小酒馆老板：白天去各地图采集/对话 → 夜晚在吧台后合成食物饮料，服务冒险者。

- **引擎**: Godot 4.6.x (标准版，非 .NET/Mono)
- **渲染**: GL Compatibility (2D)
- **语言**: GDScript
- **分辨率**: 1280×720，可缩放
- **设计系统**: "Hearth & Shadow" (`scripts/ui/theme_colors.gd`)

## 当前状态

**分支**: `main`
**阶段**: v0.2 — 5场景流转、7子系统、手势合成、商店、ThemeColors UI 设计系统、莱恩3天叙事线、香料系统
**视角**: VA-11 Hall-A 式 2D 吧台视角

## 关键文件速查

| 文件 | 说明 |
|------|------|
| `project.godot` | 引擎配置，Autoload: GameManager |
| `scripts/game_manager.gd` | Autoload 顶层协调器，库存/快捷栏/配方/拖拽/对话 |
| `scripts/systems/craft_system.gd` | 配方匹配、手势状态 |
| `scripts/systems/day_cycle_system.gd` | 昼夜循环、日期推进 |
| `scripts/systems/economy_system.gd` | 金币/声望/酒馆等级 |
| `scripts/systems/guest_system.gd` | 客人生成、耐心倒计时、结算 |
| `scripts/systems/shop_system.gd` | 商店配置、材料售价、配方解锁 |
| `scripts/systems/seasoning_system.gd` | 香料数据加载、查询 |
| `scripts/systems/narrative_manager.gd` | NPC 剧情配置、DM 驱动、变量管理 |
| `scripts/ui/tavern_view.gd` | 酒馆营业主界面 |
| `scripts/ui/craft_station.gd` | 合成台手势组件（拖拽/加热/摇晃/搅拌）|
| `scripts/ui/day_map_view.gd` | 白天大地图界面（含商店标签页）|
| `scripts/ui/title_screen.gd` | 标题界面 |
| `scripts/ui/ending_screen.gd` | 结局结算界面 |
| `scripts/ui/ledger_screen.gd` | 打烊后账单界面 |
| `scripts/ui/seasoning_zone.gd` | 香料台（三状态拖放：空/有成品/已撒香料）|
| `scripts/ui/theme_colors.gd` | "Hearth & Shadow" 全局配色 + StyleBox 工厂 |
| `scripts/ui/texture_manager.gd` | 纹理加载缓存工具 |
| `scripts/ui/mixing_area.gd` | 合成区拖放台 |
| `scripts/ui/product_panel.gd` | 产品展示面板 |
| `scripts/ledger_data.gd` | 账单数据结构 |
| `scripts/main_init.gd` | Main 场景初始化 |
| `scenes/ui/Tavern.tscn` | 酒馆营业场景 |
| `scenes/ui/DayMap.tscn` | 白天大地图场景（含商店标签页）|
| `scenes/ui/TitleScreen.tscn` | 标题场景 |
| `scenes/ui/EndingScreen.tscn` | 结局场景 |
| `scenes/ui/LedgerScreen.tscn` | 打烊后账单场景 |
| `scenes/main/Main.tscn` | 主入口容器 |
| `data/recipes.json` | 配方表 (9种) |
| `data/locations.json` | 采集点配置 |
| `data/npcs.json` | NPC 剧情配置 (2人: ryan/mira) |
| `data/shop.json` | 商店配置（材料售价、配方解锁价格）|
| `data/seasonings.json` | 香料配置 (4种) |
| `data/inventory_default.json` | 初始库存 |
| `dialogue/ryan_day1~3.pre/post.dialogue` | 莱恩 3 天叙事线（pre=点单, post=上菜反馈）|
| `dialogue/mira_day4/12.pre/post.dialogue` | 米拉 2 天叙事线 |

## 文档速查

| 文档 | 说明 |
|------|------|
| `docs/01_AI开发规范.md` | 目录结构、路径规则、禁止事项 |
| `docs/02_AI项目速查.md` | 系统架构、场景布局、配方表、参数、设计系统 |
| `docs/03_资源清单.md` | v0.2 资源：场景/脚本/数据文件/ThemeColors/美术 |
| `docs/04_游戏总览.md` | 游戏定位、体验目标、技术规格、开发状态 |
| `docs/05_核心机制.md` | 已实现系统规则：合成/客人/经济/昼夜/对话 |
| `docs/06_游戏重制策划案.md` | 2D 重制设计：场景/循环/NPC叙事/合成/经济 |
| `docs/07_美术需求文档.md` | 像素风资源清单、配色表、各场景需求、优先级 |

## 目录规范 (01_AI开发规范.md 核心规则)

### 场景/脚本分离
- `.tscn` → 只放 `scenes/`
- `.gd` → 只放 `scripts/`
- **禁止**混放到同一目录

### 脚本子目录
| 类型 | 位置 |
|------|------|
| Autoload 单例 | `scripts/` (根目录) |
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
- 所有 `load/preload` 用完整 `res://` 路径
- 资源只放 `assets/` 子目录 (models/textures/audio/fonts/ui)

## 配方表 (9种)

| Key | 名称 | 材料 | 价格 |
|-----|------|------|------|
| Ale | 麦芽酒 | 麦芽 | 5金 |
| Wine | 葡萄酒 | 葡萄 | 5金 |
| Bread | 面包 | 面粉 | 3金 |
| Meat | 烤肉 | 生肉 | 4金 |
| Herb Tea | 草药茶 | 草药 | 3金 |
| Herbal Ale | 草药麦酒 | 麦芽+草药 | 10金 |
| Meat Stew | 肉汤 | 生肉+麦芽 | 12金 |
| MeatSand | 肉夹面包 | 面粉+生肉 | 9金 |
| SpicedWine | 香料红酒 | 葡萄+草药 | 11金 |

定义位置: `data/recipes.json` → `game_manager.gd._recipes`

## 场景流转

```
TitleScreen ──"开始营业"──> DayMap ──"出发"──> Tavern ──"打烊"──> LedgerScreen
                                ↑                    │                   │
                                └── 下一天 ←─────────┘              "继续" → DayMap
                                                                      (第30天 → EndingScreen)
```

## 游戏参数

| 参数 | 值 | 位置 |
|------|-----|------|
| 客人耐心 | 60s | `guest_system.gd` |
| 生成间隔 | 2-5s 随机 | `guest_system.gd._next_spawn` |
| 快捷栏 | 10格 (键盘 0-9) | `craft_station.gd.bar_materials` |
| 手势时长 | 1.5s | `craft_station.gd.HEAT_TIME` |
| 游戏天数 | 30天 | `day_cycle_system.gd` |
| 客人名池 | 12个 | `guest_system.gd` |

## 输入映射

| 动作 | 按键 | 功能 |
|------|------|------|
| menu_toggle | E | 打开/关闭配方+背包菜单 |
| 拖拽/放下 | 鼠标左键 | 材料拖到合成区 |
| 逐个退回 | 拖拽中鼠标右键 | 退回单个材料 |
| 全部退回 | 非拖拽时鼠标右键 | 退回合成区所有材料 |

## 香料系统

| 香料 Key | 名称 | 效果 |
|----------|------|------|
| spice | 辣 | 口味标签 |
| herb_spice | 香草 | 口味标签 |
| salt | 咸 | 口味标签 |
| sleep_powder | 迷睡花粉 | 口味标签 + 消耗库存 |

交互流程：成品 → 拖入 SeasoningZone → 从快捷栏拖香料撒入 → 拖出给客人
定义位置: `data/seasonings.json` → `seasoning_system.gd`

## 禁止事项
- ❌ 不修改 `addons/` 下任何文件
- ❌ 不在项目根目录散落 `.gd`/`.tscn`
- ❌ 不将业务代码放 `addons/`
- ❌ 不新建 `src/` 目录
- ❌ 不将 `scripts/` 和 `scenes/` 合并

## 开发流程（强制）

**上一阶段未完成，不进下一阶段。**

1. **Spec** — 需求写 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`，确认后才往下
2. **Plan** — 拆任务写 `docs/superpowers/plans/`，每个任务 ≤1 文件，确认后才往下
3. **Worktree** — 创建 `feature/<topic>` 隔离工作区
4. **编码** — 严格按 plan 顺序，每任务完成立即运行验证，禁止顺手重构，禁止加 plan 外功能
5. **验证** — Godot 跑起来走核心路径 + 回归检查 + 0 errors 0 warnings
6. **Code Review** — 过 diff：多余改动/null 引用/死代码/资源泄漏，问题清零
7. **Commit** — 格式 `type: 简述`（feat:/fix:/refactor:/docs:），commit 到 main

**对话规则**：一次对话只做一个功能。上下文膨胀就重开，用 spec/plan 文档恢复。AI 必须是 spec/plan 确认通过后，才可以写代码。

## NPC 对话文件规范

重要 NPC 的对话拆成两个文件：
- `{npc_id}_day{N}.pre.dialogue` — 客人进店时的点单对话（上菜前）
- `{npc_id}_day{N}.post.dialogue` — 上菜后的反馈对话（读 `serve_result` 变量走 `if/else`）

`serve_result` 由 GameManager 上菜逻辑设置 (`"success"` / `"fail"`)，通过 `NarrativeManager` 的 dialogue_vars 传给 Dialogue Manager。

`npcs.json` 中的 `dialogue` 字段为历史遗留，当前代码用上述命名约定自动拼接路径。

## 插件

| 插件 | 用途 |
|------|------|
| `addons/dialogue_manager/` | 对话引擎，.dialogue 文件解析 |
| `addons/godot_mcp/` | Godot MCP，AI 通过 MCP 操控编辑器 |

## 构建/运行

用 Godot 4.6.x 标准版（非 .NET）编辑器打开项目目录即可运行。无需 `dotnet build`。
