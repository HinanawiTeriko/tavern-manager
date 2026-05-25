# C# → GDScript 迁移设计

**日期**: 2026-05-25
**目标**: 将项目从 Godot 4.6 .NET 迁移到纯 GDScript，以支持 Web 导出

## 背景

Godot 4 的 .NET/Mono 运行时无法编译到 WebAssembly。要导出 Web 端，必须使用 GDScript。项目当前有 22 个 C# 文件（约 3,789 行），需要全部迁移。

## 迁移策略

分 4 轮增量迁移，每轮完成后验证可运行。Godot 4 支持 .NET 和 GDScript 混跑，所以中间状态始终可用。

## 迁移顺序

### 第 1 轮 — 纯逻辑系统（无 UI 依赖）
- `SeasoningSystem.cs` → `seasoning_system.gd`
- `ShopSystem.cs` → `shop_system.gd`
- `CraftSystem.cs` → `craft_system.gd`

### 第 2 轮 — 有依赖的系统
- `EconomySystem.cs` → `economy_system.gd`
- `DayCycleSystem.cs` → `day_cycle_system.gd`
- `GuestSystem.cs` → `guest_system.gd`
- `NarrativeManager.cs` → `narrative_manager.gd`

### 第 3 轮 — UI 组件
- `TextureManager.cs` → `texture_manager.gd`
- `ThemeColors.cs` → `theme_colors.gd`
- `CraftStation.cs`, `MixingArea.cs`, `ProductPanel.cs`, `SeasoningPanel.cs`, `SeasoningZone.cs`, `TitleAmbience.cs` → 对应 `.gd` 文件
- `TavernView.cs`, `DayMapView.cs`, `EndingScreen.cs`, `LedgerScreen.cs`, `TitleScreen.cs` → 对应 `.gd` 文件

### 第 4 轮 — 中心节点 + 收尾
- `GameManager.cs` → `game_manager.gd`
- `MainInit.cs` → `main_init.gd`
- 更新 `project.godot`，删除 .NET 配置
- 删除 `.sln`、`.csproj`、所有 `.cs` 文件
- 验证 Web 导出

## 关键转换规则

| C# | GDScript |
|---|---|
| `Dictionary<K,V>` / `List<T>` | `Dictionary` / `Array` |
| `JsonSerializer.Deserialize<T>(json)` | `JSON.parse_string(json)` |
| `[Signal] public delegate void XEventHandler(...)` | `signal x(...)` |
| `public event Action X` | `signal x()` |
| LINQ `.Where().Distinct().ToList()` | `for` 循环或 `Array.filter()` |
| `GetNode<T>(path)` | `$Path` 或 `get_node(path)` |
| `ResourceLoader.Load<T>(path)` | `load(path)` |
| `+=` / `-=` (事件订阅) | `.connect()` / `.disconnect()` |

## 项目配置变更

`project.godot` 需修改：
- `config/features`: 移除 `"C#"`
- `autoload/GameManager`: 路径改为 `*res://scripts/game_manager.gd`
- 删除 `[dotnet]` section

## 风险

1. **信号/事件丢失**: C# 信号连接未在 GDScript 中重建会导致功能静默失效
2. **JSON 解析差异**: `System.Text.Json` 强类型反序列化 vs `JSON.parse_string()` 裸字典
3. **类型静默转换**: GDScript 无编译期类型检查，`int`→`float`→`null` 不会报错

## 验证策略

每轮完成后：编辑器内运行核心路径 + `dotnet build`（前 3 轮）

| 轮次 | 验证内容 |
|------|---------|
| 第 1 轮 | 商店购买/合成配方匹配/香料拖放，确认 JSON 数据正确加载 |
| 第 2 轮 | 昼夜循环/客人生成/经济结算（金+声望），确认数值正常 |
| 第 3 轮 | UI 交互：拖拽合成/加热搅拌/菜单开关/场景跳转，确认视觉正常 |
| 第 4 轮 | 完整流程：标题→地图→酒馆→账单→返回，确认全链路 + Web 导出 |

每轮迁移前打 git tag 作为回退点。
