# 地下城酒馆 - 资源标记文档

> 版本: v0.1 MVP | 最后更新: 2026-05-20

---

## 📁 项目结构

```
tavern-manager/
├── tavern-manager.csproj       ← .NET 8 项目文件
├── project.godot               ← Godot 引擎配置
│
├── assets/                     ← 所有外部资源
│   ├── textures/               ← 图片纹理
│   │   └── dark_dungeon_tavern_interior_*.png  ← [待替换] AI生成背景
│   ├── audio/                  ← 音效/音乐（空）
│   ├── fonts/                  ← 字体文件（空，使用系统默认）
│   ├── models/                 ← 3D模型（空）
│   └── ui/                     ← UI专用素材（空）
│
├── scenes/                     ← 场景文件
│   ├── main/Main.tscn          ← 主游戏场景（吧台/客人/UI）
│   └── ui/TitleScreen.tscn     ← 开始界面
│
├── scripts/                    ← C# 脚本
│   ├── GameManager.cs          ← [核心] Autoload 游戏管理器
│   └── ui/TitleScreen.cs       ← 开始界面脚本
│
└── docs/
    ├── AI_GUIDE.md             ← AI开发指南
    └── RESOURCES.md            ← [本文件] 资源标记文档
```

---

## 🖼️ 美术资源清单

| 资源路径 | 用途 | 当前状态 | 建议替换为 |
|----------|------|----------|-----------|
| `assets/textures/dark_dungeon_tavern_interior_*.png` | 酒馆背景 (1280×720) | AI生成临时占位 | 手绘/像素风黑暗地牢酒馆场景 |
| `assets/textures/` (待添加) | 客人立绘 | 用 ColorRect 代替 | 冒险者角色图片，每种职业一张 |
| `assets/textures/` (待添加) | 材料图标 (5种) | 按钮文字代替 | 麦芽/葡萄/面粉/生肉/草药像素图标 |
| `assets/textures/` (待添加) | 成品图标 (9种) | 无图标 | 食物/饮料像素图标 |
| `assets/ui/` (待添加) | UI面板皮肤 | Godot默认样式 | 羊皮纸/木板纹理背景 |

**引用位置**: `Main.tscn` 的 `Background` 节点 (id=1), `TitleScreen.tscn` 的 `Background` 节点 (id=1)

---

## 🎵 音频资源清单

| 资源路径 | 用途 | 当前状态 | 建议 |
|----------|------|----------|------|
| `assets/audio/` | BGM背景音乐 | 无 | 中世纪酒馆氛围音乐 |
| `assets/audio/` | 客人到来音效 | 无 | 门铃/脚步声 |
| `assets/audio/` | 合成完成音效 | 无 | 叮当/倒酒声 |
| `assets/audio/` | 金币音效 | 无 | 钱币声 |
| `assets/audio/` | 错误音效 | 无 | 低沉提示音 |

---

## ⌨️ 输入映射

| 动作名 | 按键 | 触发位置 | 功能 |
|--------|------|----------|------|
| `menu_toggle` | **E** | `GameManager._Process()` | 打开/关闭配方+背包菜单 |

---

## 🧾 游戏数据

### 配方表 (9种)

| 内部Key | 中文名 | 材料1 | 材料2 | 价格 | 类型 |
|---------|--------|-------|-------|------|------|
| Ale | 麦芽酒 | 麦芽 | — | 5金 | 单品 |
| Wine | 葡萄酒 | 葡萄 | — | 5金 | 单品 |
| Bread | 面包 | 面粉 | — | 3金 | 单品 |
| Meat | 烤肉 | 生肉 | — | 4金 | 单品 |
| Herb Tea | 草药茶 | 草药 | — | 3金 | 单品 |
| Herbal Ale | 草药麦酒 | 麦芽 | 草药 | 10金 | 合成 |
| Meat Stew | 肉汤 | 生肉 | 麦芽 | 12金 | 合成 |
| MeatSand | 肉夹面包 | 面粉 | 生肉 | 9金 | 合成 |
| SpicedWine | 香料红酒 | 葡萄 | 草药 | 11金 | 合成 |

**定义位置**: `scripts/GameManager.cs` → `_recipes` 字典 (第70行附近)

### 材料颜色映射

| 内部Key | 中文名 | 显示颜色(RGB) | 定义位置 |
|---------|--------|--------------|----------|
| Ale | 麦芽 | #CD9933 琥珀 | `MC()` 方法 |
| Wine | 葡萄 | #991A33 深红 | `MC()` 方法 |
| Bread | 面粉 | #B38C4D 棕色 | `MC()` 方法 |
| Meat | 生肉 | #A6331A 暗红 | `MC()` 方法 |
| Herb | 草药 | #33B333 绿色 | `MC()` 方法 |

### 客人名池 (12人)

**定义位置**: `scripts/GameManager.cs` → `Names` 数组

---

## 🎮 游戏参数

| 参数 | 值 | 定义位置 |
|------|-----|----------|
| 客人耐心时间 | 60秒 | `Patience` 常量 |
| 生成间隔 | 2~5秒随机 | `_nextSpawn` |
| 窗口大小 | 1280×720 | `project.godot` → `[display]` |
| 视口可缩放 | 是 | `project.godot` |

---

## 🔧 脚本速查

| 脚本 | 类型 | 附着目标 | 核心方法 |
|------|------|----------|----------|
| `GameManager.cs` | Autoload | `/root/GameManager` | `_Ready()`, `_Process()`, `Spawn()`, `OnCraft()`, `OnServe()` |
| `TitleScreen.cs` | Node2D脚本 | `TitleScreen` 场景根节点 | `_Ready()` → 连接开始按钮 |

### GameManager 节点依赖

所有 UI 节点通过 `GetNodeOrNull("/root/Main/...")` 查找：

| 路径 | 节点类型 | 用途 |
|------|----------|------|
| `UI/TopPanel/GoldLabel` | Label | 金币显示 |
| `UI/TopPanel/ReputationLabel` | Label | 声望显示 |
| `UI/CustomerInfo/CustomerName` | Label | 客人名 |
| `UI/CustomerInfo/OrderText` | Label | 订单需求 |
| `UI/CustomerInfo/TimerBar` | ProgressBar | 耐心倒计时 |
| `UI/MaterialsPanel/*` | Button[] | 材料按钮 (BtnAle/BtnWine/BtnBread/BtnMeat/BtnHerb) |
| `UI/CraftPanel/Slot1` | ColorRect | 合成槽1 |
| `UI/CraftPanel/Slot2` | ColorRect | 合成槽2 |
| `UI/CraftPanel/CraftButton` | Button | 合成按钮 |
| `UI/CraftPanel/ClearButton` | Button | 清空按钮 |
| `UI/ServePanel/ServeButton` | Button | 服务按钮 |
| `UI/OverlayMenu` | Panel | 菜单面板 (E键) |
| `CustomerArea/CustomerSprite` | ColorRect | 客人形象 |
| `CustomerArea/OrderBubble` | Label | 对话气泡 |

---

## 🚀 构建与运行

```powershell
# 编译
cd tavern-manager
dotnet build

# 运行 (需要 Godot .NET 4.6.2)
# 双击 godot-editor/Godot_v4.6.2-stable_mono_win64.exe
# Import → tavern-manager 目录
```

**.NET 版本要求**: .NET SDK 8.0+
**Godot 版本**: 4.6.2-stable .NET (mono) 版
