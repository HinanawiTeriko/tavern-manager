# 地下城酒馆 (Tavern Manager)

> Godot 4.6 标准版 / GDScript / 2D GL Compatibility 的吧台物理经营原型。

## 项目现状

当前主线已经从旧的“固定合成槽 + 按钮手势 + SeasoningZone”改为“物理吧台工作面 + 三容器加工 + 拖拽上菜”。

- 主场景：`res://scenes/ui/TitleScreen.tscn`
- 夜晚营业：`res://scenes/ui/Tavern.tscn`
- 核心工作面：`scripts/ui/bar_workspace.gd`
- 三个 Day 1 容器：酒桶 `barrel`、烤架 `grill`、炖锅 `pot`
- 物理物品：`scenes/test/desk_item.tscn` + `scripts/test/desk_item.gd`
- 配方查询：`CraftSystem.query_recipe(container, ingredients)`

## 游戏简介

玩家经营一间地下城酒馆。白天在 DayMap 选择目的地、采集材料、触发 NPC 对话；夜晚在吧台后从快捷栏取材，把材料作为物理物体拖到桌面，通过酒桶、烤架和炖锅制作订单，再把成品拖到客人投放区完成上菜。上菜时的力度会进入 L3 动作风格系统，影响重要 NPC 的信任与反馈。

### 当前可玩循环

1. `TitleScreen` 点击开始进入 `DayMap`。
2. 选择或跳过白天准备，进入 `Tavern`。
3. 从底部 `ShortcutBar` 点取材料，生成可拖拽的 `DeskItem`。
4. 把材料投入酒桶、烤架或炖锅，容器产出物理成品。
5. 将成品拖到 `CustomerDropArea` 松手，上菜并结算金币、声望和叙事变量。
6. 打烊后进入 `LedgerScreen`，继续下一天；第 30 天后进入 `EndingScreen`。

## 当前内容

| 内容 | 当前状态 |
|------|----------|
| 基础材料 | 5 种：麦芽、葡萄、面粉、生肉、草药 |
| 可上菜成品 | 11 种：酒桶 5、烤架 3、炖锅 3 |
| 容器 | 酒桶、烤架、炖锅已接入 Tavern |
| 物理手感 | RigidBody2D + PinJoint 拖拽，物品 profile 可配置 |
| 酒桶 | 投料、摇晃计数、品质 normal/good、物理产出 |
| 烤架 | 按压煎制，肉类双面熟度，熟/焦定稿 |
| 炖锅 | 投料后用物理勺搅拌，进度满足后产出 |
| L3 风格 | 上菜速度分为温柔、平静、粗鲁，接入 Mira/Day4/wine 竖切片 |
| NPC 叙事 | Ryan Day 1-3、Mira Day 4/12 |

## 快速开始

### 环境要求

- Godot 4.6.x standard，非 .NET/Mono 版
- Windows / macOS / Linux

### 运行

用 Godot 4.6.x 标准版编辑器打开项目目录，运行主场景即可。项目没有额外编译、打包脚本、linter 或 CI。

Godot MCP 环境可能启动 Mono 并输出 `.NET: Assemblies not found`，只要标准编辑器不复现，按环境噪声处理。

### 基本操作

| 操作 | 方式 |
|------|------|
| 取材料 | 鼠标左键点击底部快捷栏槽位 |
| 拖动物品/容器/勺子 | 鼠标左键按住并移动 |
| 投入酒桶 | 把材料丢入桶口，速度足够才会接收 |
| 摇酒桶 | 抓住酒桶左右晃动，摇够后产出 |
| 烤制 | 抓着可烤材料按在烤架热区，离开热区时定稿 |
| 炖煮 | 把材料放进锅，再用勺尖在锅内搅动 |
| 上菜 | 把成品拖进客人投放区松手 |
| 菜单 | `E` 打开/关闭配方与背包面板 |

## 项目结构

```text
tavern-manager/
├── project.godot                  # Godot 配置，主场景为 TitleScreen
├── assets/                        # 纹理、图标、导入资源
├── data/                          # JSON 玩法数据
│   ├── items.json                 # 物品、价格、颜色、profile 引用
│   ├── recipes.json               # container + ingredients 配方表
│   ├── item_physics_profiles.json # 物理/碰撞/反馈 profile
│   ├── barrel.json                # 酒桶摇晃阈值
│   └── craft_style_thresholds.json# L3 风格阈值
├── dialogue/                      # Dialogue Manager 对话
├── scenes/
│   ├── ui/                        # TitleScreen / DayMap / Tavern / Ledger / Ending
│   └── test/                      # 物理沙盘和无 runner 的测试场景
├── scripts/
│   ├── game_manager.gd            # Autoload 顶层协调器
│   ├── systems/                   # RefCounted 子系统
│   ├── ui/                        # 正式 UI 与吧台工作面
│   └── test/                      # 沙盘脚本与手动测试脚本
├── docs/                          # 项目文档
└── addons/                        # vendored 插件，不随意修改
```

## 重要文档

| 文档 | 用途 |
|------|------|
| [docs/01_AI开发规范.md](docs/01_AI开发规范.md) | 目录与代码约定 |
| [docs/02_AI项目速查.md](docs/02_AI项目速查.md) | 当前系统速查 |
| [docs/03_资源清单.md](docs/03_资源清单.md) | 文件、场景、数据、测试资源清单 |
| [docs/04_游戏总览.md](docs/04_游戏总览.md) | 当前游戏定位与体验目标 |
| [docs/05_核心机制.md](docs/05_核心机制.md) | 当前已实现规则 |
| [docs/13_合成系统物理重设计需求文档.md](docs/13_合成系统物理重设计需求文档.md) | 物理工作面设计与落地状态 |
| [docs/16_物品物理手感Profile接口设计.md](docs/16_物品物理手感Profile接口设计.md) | 物品 profile 接口 |
| [docs/17_Day1三容器配方与解锁设计.md](docs/17_Day1三容器配方与解锁设计.md) | Day 1 三容器配方设计 |

`docs/10_酿造系统需求文档.md` 和 `docs/14_吧台交互系统重设计_legacy.md` 是历史/废弃文档，不作为新开发依据。

## 开发约定

- GDScript 使用 tabs，文件/变量/函数用 `snake_case`。
- 场景和脚本分树存放：`.tscn` 在 `scenes/`，`.gd` 在 `scripts/`。
- 子系统放 `scripts/systems/`，尽量保持 `RefCounted`，跨系统行为通过 `GameManager` 路由。
- 使用绝对 `res://` 路径。
- 不修改 `addons/`，除非明确更新依赖。
- 提交前至少检查 `git status` 和冲突标记。

## 验证建议

项目没有自动测试 runner。改 gameplay/UI 后优先走标准编辑器手测：

```text
TitleScreen -> DayMap -> Tavern -> LedgerScreen -> DayMap
```

三容器相关改动还应在 Tavern 中逐个验证酒桶、烤架、炖锅的主要配方，并确认上菜结算无错误/警告。需要跑测试场景时可用 `scenes/test/test_l3.tscn`、`test_barrel_shake.tscn`、`test_kitchen_containers.tscn` 等 headless 场景辅助验证。
