# 地下城酒馆 — 项目速查

## 项目定位

**地下城酒馆** — Godot 4.6 .NET **3D** 模拟经营游戏。
玩家是地牢小酒馆老板：白天采集/交易/对话 → 夜晚营业合成食物饮料，服务冒险者。

- **引擎**: Godot 4.6.x .NET/Mono
- **渲染**: Forward+ (3D) — 当前 v0.1 仍是 GL Compatibility 2D
- **语言**: C# (.NET 8.0)
- **分辨率**: 1280×720，可缩放

## 当前状态

**分支**: `dialogue`
**阶段**: v0.1 MVP (2D) — 基础拖拽合成 + 客人服务，已有 3 天莱恩叙事线
**项目当前实际是 2D MVP**，02_AI项目速查.md 描述的是 3D 重制蓝图。

## 关键文件速查

| 文件 | 说明 |
|------|------|
| `project.godot` | 引擎配置，Autoload: GameManager + DialogueManager |
| `scripts/GameManager.cs` | 核心 Autoload (242行)，包含合成/客人/背包/菜单全部逻辑 |
| `scripts/main/MainInit.cs` | Main 场景初始化，调用 `gm.StartGame(this)` |
| `scripts/ui/TitleScreen.cs` | 标题界面，点"开始营业"→ ChangeSceneToFile("Main.tscn") |
| `scenes/main/Main.tscn` | 主场景 (Node2D)，含背景/Sprite、快捷栏、合成区、菜单面板 |
| `scenes/ui/TitleScreen.tscn` | 标题界面 |
| `dialogue/d1~d3.dialogue` | 莱恩 3 天叙事线（Dialogue Manager 插件驱动） |
| `docs/01_AI开发规范.md` | 目录规范（scenes/scripts 分离、路径规则） |
| `docs/02_AI项目速查.md` | 3D 蓝图（12 系统 + 场景结构 + 物品体系 + 路线图） |
| `docs/03_资源清单.md` | v0.1 资源清单（配方/参数/节点路径） |
| `docs/04_游戏总览.md` | 游戏定位、体验目标、玩法循环 |
| `docs/05_核心机制.md` | 昼夜循环、合成、客人、经济等规则 |
| `docs/06_策划文档计划.md` | 策划文档制作总计划 |

## 系统架构 (3D 蓝图，当前未实现)

← 02_AI项目速查.md 描述，共 12 个系统：

| 系统 | 路径 | 状态 |
|------|------|------|
| GameManager | `scripts/systems/GameManager.cs` | 需从 242 行拆出来 |
| InventorySystem | `scripts/systems/` | 待创建 |
| EconomySystem | `scripts/systems/` | 待创建 |
| CraftSystem | `scripts/systems/` | 待创建 |
| TimeSystem | `scripts/systems/` | 待创建 |
| EventSystem | `scripts/systems/` | 待创建 |
| QuestSystem | `scripts/systems/` | 待创建 |
| TradeSystem | `scripts/systems/` | 待创建 |
| GatheringSystem | `scripts/systems/` | 待创建 |
| DialogueSystem | `scripts/systems/` | 待创建 |
| TavernMapSystem | `scripts/systems/` | 待创建 |
| SaveSystem | `scripts/systems/` | 待创建 |
| BuildSystem | `scripts/systems/` | 待创建 |
| PlayerController | `scripts/components/` | 待创建 |
| NPCController | `scripts/components/` | 待创建 |

## 目录规范 (01_AI开发规范.md 核心规则)

### 场景/脚本分离
- `.tscn` → 只放 `scenes/`
- `.cs` → 只放 `scripts/`
- **禁止**混放到同一目录

### 脚本子目录
| 类型 | 位置 |
|------|------|
| Autoload 单例 | `scripts/autoload/` |
| 挂载节点脚本 | `scripts/components/` |
| 系统逻辑 | `scripts/systems/` |
| UI 逻辑 | `scripts/ui/` |

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

## 禁止事项
- 不修改 `addons/` 下任何文件
- 不在项目根目录散落 `.gd`/`.tscn`
- 不将业务代码放 `addons/`
- 不新建 `src/` 目录
- 不将 `scripts/` 和 `scenes/` 合并

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

定义位置: `GameManager.cs` `_recipes` 字典

## 材料颜色映射

| Key | 名称 | 颜色 |
|-----|------|------|
| Ale | 麦芽 | (0.8, 0.6, 0.2) 琥珀 |
| Wine | 葡萄 | (0.6, 0.1, 0.2) 深红 |
| Bread | 面粉 | (0.7, 0.55, 0.3) 棕色 |
| Meat | 生肉 | (0.65, 0.2, 0.1) 暗红 |
| Herb | 草药 | (0.2, 0.7, 0.2) 绿色 |

## 游戏参数

| 参数 | 值 | 位置 |
|------|-----|------|
| 客人耐心 | 60s | `PAT = 60.0` |
| 生成间隔 | 2-5s 随机 | `_nxS = rng.NextDouble()*3+2` |
| 快捷栏 | 10格 | 对应键盘数字 |
| 初始库存 | 999 每种材料 | `_inv` 字典 |
| 客人名池 | 12个 | `Nms` 数组 |

## 输入映射

| 动作 | 按键 | 参数位置 |
|------|------|----------|
| menu_toggle | E | `project.godot` `[input]` |
| 拖拽/放下 | 鼠标左键 | GameManager._Input |
| 逐个退回 | 拖拽中鼠标右键 | GameManager._Input |
| 退回合成区 | 非拖拽时鼠标右键 | GameManager._Input |

## 对话叙事 (d1~d3)

3 个 `.dialogue` 文件描述**莱恩**(见习骑士)的宿命故事线：

- **d1**: 教学日 — 莱恩首次登场，基础服务教学，充满希望
- **d2**: 宿命显现 — 账本显示莱恩明日会死。采集获得`迷睡花粉`。分支：掺入水中让他昏睡 / 不干预
  - 变量: `has_sleep_powder`, `ryan_drugged`
- **d3**: 因果结算 — 基于 d2 变量自动分叉：
  - 未干预 → 莱恩死亡，佣兵带来他裂开的盾牌
  - 干预 → 莱恩存活但精神崩溃（他睡过头没赶上，血斧小队全灭）
- **程序端** `DialogueSystem.cs` 负责封装 Dialogue Manager 调用、管理变量、通过信号通知游戏逻辑

## GameManager 源码结构速查 (GameManager.cs)

```
字段区 (20-39): 库存_inv, 配方_rec, 快捷栏_barMat[10], 客人状态, 拖拽状态, UI节点引用
_Ready() (40-50): 初始化配方字典, 创建拖拽面板
StartGame(m) (52): 入口, 调用 Init()
Init(m) (55-109): 绑定全部UI节点引用, 注册事件, 构建配方表/背包面板
_Process(dt) (122-127): E键菜单, 客人倒计时, 新客人生成
_Input(e) (130-140): 拖拽输入处理
PickUp/DropAll/ReturnOne/ReturnAll (142-191): 拖拽逻辑
OnCraft/OnClear/UpdC (210-218): 合成匹配
Spawn/OT/Clr/OnServe (221-224): 客人逻辑
UpdB/UpdAll/UpdUI/ToggleMenu/Msg (227-235): UI更新
MC(m) (235): 材料键→颜色映射
Ex (239-241): 扩展方法 (GL/WithWhiteText)
```

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
