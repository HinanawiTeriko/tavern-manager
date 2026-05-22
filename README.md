# 地下城酒馆 (Tavern Manager)

> 一个地下城风格的酒馆模拟经营游戏 | Godot 4.6 .NET | v0.1 MVP

---

## 游戏简介

你是一名地下城酒馆的老板。冒险者们从危险的地牢归来，渴望一杯麦芽酒或一顿热饭。通过**拖拽材料合成食物和饮料**，满足客人的订单，赚取金币和声望！

### 核心玩法

- **拖拽合成**：从快捷栏拿起材料，拖入合成区组合成食物/饮料
- **服务客人**：在客人耐心耗尽前提供正确订单
- **经营成长**：赚取金币和声望，解锁更多配方

### 当前内容 (v0.1 MVP)

| 内容 | 数量 |
|------|------|
| 材料种类 | 5 种（麦芽、葡萄、面粉、生肉、草药） |
| 可合成配方 | 9 种（5 单品 + 4 合成品） |
| 客人名池 | 12 个随机冒险者名字 |
| 客人耐心 | 60 秒倒计时 |
| 生成间隔 | 2~5 秒随机 |

---

## 快速开始

### 环境要求

- **Godot**: 4.6.2-stable (.NET/Mono 版)
- **.NET SDK**: 8.0+
- **操作系统**: Windows / macOS / Linux

### 运行

```powershell
# 1. 编译
cd tavern-manager
dotnet build

# 2. 用 Godot .NET 编辑器打开项目目录即可运行
```

### 操作

| 操作 | 按键/方式 |
|------|-----------|
| 拖拽材料 | **鼠标左键** 拿起/放下 |
| 逐个退回 | 拖拽中 **鼠标右键** |
| 退回合成区 | 非拖拽时 **鼠标右键** |
| 打开菜单 | **E 键**（查看配方表和背包） |

---

## 项目结构

```
tavern-manager/
├── project.godot                  # 引擎配置
├── tavern-manager.csproj          # .NET 8 项目
├── assets/                        # 美术/音频/字体资源
│   ├── textures/                  # 图片纹理
│   ├── audio/                     # 音效音乐
│   ├── fonts/                     # 字体文件
│   └── ui/                        # UI 素材
├── scenes/                        # 场景文件 (.tscn)
│   ├── main/Main.tscn             # 主游戏场景
│   └── ui/TitleScreen.tscn        # 标题界面
├── scripts/                       # C# 脚本
│   ├── GameManager.cs             # [核心] Autoload 游戏管理器
│   ├── main/MainInit.cs           # Main 场景初始化
│   └── ui/TitleScreen.cs          # 标题界面脚本
├── data/                          # 配置数据（预留）
├── docs/                          # 文档
│   ├── AI_GUIDE.md                # AI 开发规范
│   ├── AI_CONTEXT.md              # AI 项目速查
│   └── RESOURCES.md               # 资源标记文档
└── addons/godot_mcp/              # Godot MCP 编辑器插件
```

---

## 技术栈

| 项目 | 说明 |
|------|------|
| 引擎 | Godot 4.6 (.NET / GL Compatibility) |
| 语言 | C# (.NET 8.0) |
| 渲染 | 2D (GL Compatibility) |
| 分辨率 | 1280×720，可缩放视口 |
| 插件 | godot_mcp（AI 辅助开发） |

---

## 文档导航

| 文档 | 用途 |
|------|------|
| [AI_CONTEXT.md](docs/AI_CONTEXT.md) | AI 快速理解项目的速查文档 |
| [AI_GUIDE.md](docs/AI_GUIDE.md) | AI 开发规范和目录约定 |
| [RESOURCES.md](docs/RESOURCES.md) | 资源清单、参数速查 |

---

## 路线图

- [x] v0.1 MVP — 基础拖拽合成 + 客人服务循环
- [ ] v0.2 — 材料消耗/进货系统、失败条件
- [ ] v0.3 — 美术资源替换、音效
- [ ] v1.0 — 完整游戏循环、更多配方和客人类型
