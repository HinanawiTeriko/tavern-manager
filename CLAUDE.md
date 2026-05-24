# 地下城酒馆 — 项目速查

## 项目定位

**地下城酒馆** — Godot 4.6 .NET **2D** 模拟经营游戏。
玩家是地牢小酒馆老板：白天去各地图采集/对话 → 夜晚在吧台后合成食物饮料，服务冒险者。

- **引擎**: Godot 4.6.x .NET/Mono
- **渲染**: GL Compatibility (2D)
- **语言**: C# (.NET 8.0)
- **分辨率**: 1280×720，可缩放
- **设计系统**: "Hearth & Shadow" (`scripts/ui/ThemeColors.cs`)

## 当前状态

**分支**: `zzc`
**阶段**: v0.2 — 4场景流转、6子系统、手势合成、ThemeColors UI 设计系统、莱恩3天叙事线
**视角**: VA-11 Hall-A 式 2D 吧台视角

## 关键文件速查

| 文件 | 说明 |
|------|------|
| `project.godot` | 引擎配置，Autoload: GameManager |
| `scripts/GameManager.cs` | Autoload 顶层协调器，库存/快捷栏/配方/拖拽 |
| `scripts/systems/CraftSystem.cs` | 配方匹配、手势状态 |
| `scripts/systems/DayCycleSystem.cs` | 昼夜循环、日期推进 |
| `scripts/systems/EconomySystem.cs` | 金币/声望/酒馆等级 |
| `scripts/systems/GuestSystem.cs` | 客人生成、耐心倒计时、结算 |
| `scripts/systems/NarrativeManager.cs` | NPC 剧情配置、Dialogue Manager 驱动、变量管理 |
| `scripts/ui/TavernView.cs` | 酒馆营业主界面 |
| `scripts/ui/CraftStation.cs` | 合成台手势组件（拖拽/加热/摇晃/搅拌） |
| `scripts/ui/DayMapView.cs` | 白天大地图界面 |
| `scripts/ui/TitleScreen.cs` | 标题界面 |
| `scripts/ui/EndingScreen.cs` | 结局结算界面 |
| `scripts/ui/ThemeColors.cs` | "Hearth & Shadow" 全局配色 + StyleBox 工厂 |
| `scripts/main/MainInit.cs` | Main 场景初始化 |
| `scenes/ui/Tavern.tscn` | 酒馆营业场景 |
| `scenes/ui/DayMap.tscn` | 白天大地图场景 |
| `scenes/ui/TitleScreen.tscn` | 标题场景 |
| `scenes/ui/EndingScreen.tscn` | 结局场景 |
| `scenes/main/Main.tscn` | 主入口容器 |
| `data/recipes.json` | 配方表 (9种) |
| `data/locations.json` | 采集点配置 |
| `data/npcs.json` | NPC 剧情配置 |
| `data/inventory_default.json` | 初始库存 |
| `dialogue/d1~d3.dialogue` | 莱恩 3 天叙事线 |

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
- `.cs` → 只放 `scripts/`
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

定义位置: `data/recipes.json` → `GameManager._recipes`

## 场景流转

```
TitleScreen ──"开始营业"──> DayMap ──"出发"──> Tavern ──"打烊"──> EndingScreen
                                ↑                    │
                                └── 下一天 ←─────────┘
```

## 游戏参数

| 参数 | 值 | 位置 |
|------|-----|------|
| 客人耐心 | 60s | `GuestSystem` |
| 生成间隔 | 2-5s 随机 | `GuestSystem._nextSpawn` |
| 快捷栏 | 10格 (键盘 0-9) | `GameManager._barMat[10]` |
| 手势时长 | 1.5s | `CraftStation.HeatTime` |
| 游戏天数 | 30天 | `DayCycleSystem` |
| 客人名池 | 12个 | `GuestSystem` |

## 输入映射

| 动作 | 按键 | 功能 |
|------|------|------|
| menu_toggle | E | 打开/关闭配方+背包菜单 |
| 拖拽/放下 | 鼠标左键 | 材料拖到合成区 |
| 逐个退回 | 拖拽中鼠标右键 | 退回单个材料 |
| 全部退回 | 非拖拽时鼠标右键 | 退回合成区所有材料 |

## 禁止事项
- ❌ 不修改 `addons/` 下任何文件
- ❌ 不在项目根目录散落 `.cs`/`.tscn`
- ❌ 不将业务代码放 `addons/`
- ❌ 不新建 `src/` 目录
- ❌ 不将 `scripts/` 和 `scenes/` 合并

## 插件

| 插件 | 用途 |
|------|------|
| `addons/dialogue_manager/` | 对话引擎，.dialogue 文件解析 |
| `addons/godot_mcp/` | Godot MCP，AI 通过 MCP 操控编辑器 |

## 构建/运行

```powershell
cd tavern-manager
dotnet build
# 用 Godot .NET 4.6.x 编辑器打开项目目录即可运行
```
