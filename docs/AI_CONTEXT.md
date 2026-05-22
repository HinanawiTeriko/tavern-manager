# AI 项目速查文档

> 本文档供 AI 快速理解地下城酒馆项目的全貌，在修改代码前请务必阅读。

---

## 一、项目是什么

**地下城酒馆** — Godot 4.6 .NET 2D 模拟经营游戏，v0.1 MVP 阶段。

玩家扮演酒馆老板，通过**拖拽材料合成食物饮料**，服务随机到访的冒险者客人，赚取金币和声望。

- **引擎**: Godot 4.6.2-stable (.NET/Mono), GL Compatibility 渲染
- **语言**: C# (.NET 8.0)
- **分辨率**: 1280×720, 可缩放
- **工作目录**: `scripts/` (C#), `scenes/` (.tscn), `assets/` (资源), `addons/godot_mcp/` (编辑器插件)

---

## 二、场景流转

```
TitleScreen.tscn  ──点击"开始营业"──>  Main.tscn
                                           │
                                      MainInit.cs
                                      _Ready() 中获取
                                      Autoload GameManager
                                      调用 gm.StartGame(this)
                                           │
                                      GameManager 接管所有逻辑
                                      (拖拽/合成/客人/UI)
```

---

## 三、核心架构 — GameManager

`GameManager.cs` 是 Autoload 全局单例 (`/root/GameManager`)，承担**全部游戏逻辑**，没有拆分其他系统脚本。

### 3.1 关键数据字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `_inv` | `Dictionary<string,int>` | 背包库存，5种材料初始各999 |
| `_rec` | `Dictionary<string,Recipe>` | 9种配方表 |
| `_barMat[10]` | `string[]` | 底部快捷栏10个槽位的材料key |
| `_barCnt[10]` | `int[]` | 快捷栏各槽位数量 |
| `_c1`, `_c2` | `string` | 合成区槽位1、2的材料key |
| `_crafted` | `string` | 已合成的产物key（供服务使用） |
| `_curN` | `string` | 当前客人名字 |
| `_curO` | `string` | 当前客人订单（配方key） |
| `_custA` | `bool` | 是否有客人在场 |
| `_custT` | `float` | 客人剩余耐心(秒) |
| `_g`, `_r` | `int` | 金币、声望 |
| `_drag` | `bool` | 是否正在拖拽 |
| `_dm`, `_src`, `_si`, `_dragCnt` | — | 拖拽状态机（材料名/来源/槽位索引/数量） |

### 3.2 关键方法

| 方法 | 触发时机 | 功能 |
|------|----------|------|
| `_Ready()` | 游戏启动 | 构建配方表、初始化库存 |
| `Init(Node main)` | MainInit 调用 | 绑定所有 UI 节点引用 |
| `_Process(delta)` | 每帧 | 耐心倒计时、新客人生成、E键菜单 |
| `_Input(event)` | 输入事件 | 鼠标拖拽、右键退回 |
| `Spawn()` | 自动触发 | 随机生成客人+订单 |
| `OnCraft()` | 点击合成按钮 | 检查合成区材料→生成产物 |
| `OnServe()` | 点击服务按钮 | 交付产物→结算金币/声望 |

### 3.3 配方表 (9种)

```csharp
// 定义在 GameManager._Ready() 中
_rec["Ale"]        = {name:"麦芽酒",    mats:["Ale"],          price:5}
_rec["Wine"]       = {name:"葡萄酒",    mats:["Wine"],         price:5}
_rec["Bread"]      = {name:"面包",      mats:["Bread"],        price:3}
_rec["Meat"]       = {name:"烤肉",      mats:["Meat"],         price:4}
_rec["Herb Tea"]   = {name:"草药茶",    mats:["Herb"],         price:3}
_rec["Herbal Ale"] = {name:"草药麦酒",  mats:["Ale","Herb"],   price:10, isCraft:true}
_rec["Meat Stew"]  = {name:"肉汤",      mats:["Meat","Ale"],   price:12, isCraft:true}
_rec["MeatSand"]   = {name:"肉夹面包",  mats:["Bread","Meat"], price:9,  isCraft:true}
_rec["SpicedWine"] = {name:"香料红酒",  mats:["Wine","Herb"],  price:11, isCraft:true}
```

### 3.4 材料颜色

| Key | 中文 | 颜色 | 色值 |
|-----|------|------|------|
| Ale | 麦芽 | 琥珀 | `#CD9933` |
| Wine | 葡萄 | 深红 | `#991A33` |
| Bread | 面粉 | 棕色 | `#B38C4D` |
| Meat | 生肉 | 暗红 | `#A6331A` |
| Herb | 草药 | 绿色 | `#33B333` |

### 3.5 客人名池 (12个)

铁锤格鲁姆、冰霜莱拉、暗影德恩、圣光凯尔、疾风维克斯、暗夜尼克斯、山丘伯林、银弦艾莉亚、怒血索恩、黎明扎拉、磐石芬恩、毒刃鲁克

---

## 四、UI 节点树 (Main.tscn)

```
Main (Node2D) ─ MainInit.cs
├── Background (Sprite2D)              ← 酒馆背景图
├── UI (CanvasLayer)                   ← 所有 UI 元素
│   ├── TopPanel
│   │   ├── GoldLabel                  ← 金币显示
│   │   └── ReputationLabel            ← 声望显示
│   ├── CustomerInfo
│   │   ├── CustomerName               ← 客人名字
│   │   ├── OrderText                  ← 订单需求文字
│   │   └── TimerBar (ProgressBar)     ← 耐心倒计时条
│   ├── MaterialsPanel                 ← 5个材料按钮
│   │   ├── BtnAle / BtnWine / BtnBread / BtnMeat / BtnHerb
│   ├── CraftPanel
│   │   ├── Slot1 (ColorRect)          ← 合成槽1
│   │   ├── Slot2 (ColorRect)          ← 合成槽2
│   │   ├── CraftButton                ← 合成按钮
│   │   └── ClearButton                ← 清空按钮
│   ├── ServePanel
│   │   └── ServeButton                ← 服务按钮
│   ├── BarSlots                       ← 底部10格快捷栏
│   └── OverlayMenu (Panel)            ← E键菜单(配方表+背包)
├── CustomerArea
│   ├── CustomerSprite (ColorRect)     ← 客人形象占位
│   └── OrderBubble (Label)            ← 对话气泡
└── GameManager (Autoload, 不显示)
```

**GameManager 通过 `GetNodeOrNull("/root/Main/...")` 查找所有 UI 节点。MainInit.cs 在 `_Ready()` 中调用 `gm.Init(this)` 建立绑定。**

---

## 五、交互流程

```
玩家操作流程:
1. 左键点击材料按钮/快捷栏 → 拿起材料 (进入拖拽状态)
2. 左键点击合成槽 → 放入材料
3. 右键(拖拽中) → 逐个退回材料
4. 右键(非拖拽) → 退回合成区材料到快捷栏
5. 点击"合成" → OnCraft() 检查两个槽位材料匹配配方
6. 点击"服务" → OnServe() 检查合成产物是否匹配客人订单
7. E键 → 切换配方表+背包覆盖菜单
```

---

## 六、当前状态与限制

### 已完成
- [x] 5种材料 + 9种配方的合成系统
- [x] 自定义拖拽交互（纯代码 UI）
- [x] 随机客人生成 + 耐心倒计时
- [x] 金币/声望累计
- [x] E键覆盖菜单（配方表 + 背包）
- [x] 标题界面 → 主场景的完整流程
- [x] AI 辅助开发 MCP 插件集成

### 已知限制 / 待实现
- [ ] 材料999份永不消耗，没有进货系统
- [ ] 没有失败条件（客人离开无惩罚）
- [ ] 所有 UI 使用纯代码 ColorRect/Label，无美术资源
- [ ] 仅 1 张 AI 生成背景图，无音效/字体
- [ ] 没有存档系统
- [ ] 没有难度递进、事件系统
- [ ] `scripts/main/MainInit.cs` 路径与 `AI_GUIDE.md` 规范不符（应在 `scripts/components/` 或 `scripts/systems/`）

---

## 七、关键文件速查

| 文件 | 行数估计 | 核心内容 |
|------|----------|----------|
| `scripts/GameManager.cs` | ~500+ | 所有游戏逻辑 |
| `scripts/main/MainInit.cs` | ~20 | Main场景初始化桥接 |
| `scripts/ui/TitleScreen.cs` | ~30 | 标题界面"开始"按钮 |
| `scenes/main/Main.tscn` | — | 主场景UI布局 |
| `scenes/ui/TitleScreen.tscn` | — | 标题界面布局 |
| `assets/textures/dark_dungeon_tavern_interior_*.png` | — | 酒馆背景图(1280×720) |

---

## 八、构建命令

```powershell
# 编译（在工作区目录下）
dotnet build

# Godot 编辑器运行需要 Godot_v4.6.2-stable_mono_win64.exe
# 打开编辑器后导入 tavern-manager 项目目录即可
```

---

## 九、AI 操作注意事项

1. **不要新建顶层目录**，遵循 `AI_GUIDE.md` 的目录规范
2. **不要修改 `addons/godot_mcp/`**，这是编辑器插件
3. **GameManager 是唯一逻辑入口**，新增功能优先考虑在此扩展或拆分为新系统脚本放入 `scripts/systems/`
4. **所有 res:// 路径必须完整**，如 `res://scenes/main/Main.tscn`
5. **当前项目使用 C#**，不是 GDScript（除了 addons 中的插件）
6. **备份 project.godot 再修改 autoload 配置**
