# 📚 地下城酒馆 — 文档索引

> 最后更新: 2026-05-31  
> 项目: tavern-manager | Godot 4.6 | v0.2

---

## 目录结构

```
docs/
├── README.md                 ← 你在这里
├── guides/                   ← 规范和指南
├── design/                   ← 游戏设计
├── art/                      ← 美术资源
├── specs/                    ← 系统需求规格
├── reference/                ← 参考资料
├── archive/                  ← 废弃归档
└── superpowers/              ← 开发流程 (specs + plans)
```

---

## 📋 guides/ — 规范指南

| 文档 | 说明 |
|------|------|
| [01_AI开发规范.md](guides/01_AI开发规范.md) | 目录结构、路径规则、禁止事项 |
| [02_AI项目速查.md](guides/02_AI项目速查.md) | 系统架构、场景布局、配方表、参数速查 |
| [12_Git协作规范.md](guides/12_Git协作规范.md) | Git 协作规范，适用人类开发者 + AI |

## 🎮 design/ — 游戏设计

| 文档 | 说明 |
|------|------|
| [04_游戏总览.md](design/04_游戏总览.md) | 游戏定位、体验目标、技术规格 |
| [05_核心机制.md](design/05_核心机制.md) | 已实现系统规则：合成/客人/经济/昼夜/对话 |
| [06_游戏重制策划案.md](design/06_游戏重制策划案.md) | 2D 重制设计：场景/循环/NPC叙事/合成/经济 |
| [15_宿命与自由核心设计方案.md](design/15_宿命与自由核心设计方案.md) | 主题方向设计：统一账本/夜晚服务/NPC分支与30天节奏 |

## 🎨 art/ — 美术资源

| 文档 | 说明 |
|------|------|
| [07_美术需求文档.md](art/07_美术需求文档.md) | v4.0 美术总纲：色板/角色/图标/UI/特效，P0-P2 优先级 |
| [09_NanoBanana提示词.md](art/09_NanoBanana提示词.md) | Nano Banana AI 生图提示词合集（中英双语） |

> **缺失编号说明**：`08_AI生图提示词.md` 原为通用 AI 生图提示词，已被 `09_NanoBanana提示词.md` 替代，不再保留。

## ⚙️ specs/ — 系统需求规格

| 文档 | 说明 |
|------|------|
| [11_合成物理效果需求文档.md](specs/11_合成物理效果需求文档.md) | P2 润色项：合成区拖拽物理反馈（摇晃/回弹/粉末） |
| [13_合成系统物理重设计需求文档.md](specs/13_合成系统物理重设计需求文档.md) | 核心：物理工作面 + 三层叙事重建合成系统 |
| [16_物品物理手感Profile接口设计.md](specs/16_物品物理手感Profile接口设计.md) | 数据驱动：物品物理手感 profile 接口 |
| [17_Day1三容器配方与解锁设计.md](specs/17_Day1三容器配方与解锁设计.md) | Day 1 酒桶/烤架/炖锅三容器配方与解锁节奏 |

## 📖 reference/ — 参考资料

| 文档 | 说明 |
|------|------|
| [03_资源清单.md](reference/03_资源清单.md) | v0.2 资源清单：场景/脚本/数据/美术 |

## 🗄️ archive/ — 废弃归档

| 文档 | 说明 |
|------|------|
| [10_酿造系统需求文档.md](archive/10_酿造系统需求文档.md) | ⚠ 已废弃，被 `docs/specs/13_` 取代 |
| [14_吧台交互系统重设计_legacy.md](archive/14_吧台交互系统重设计_legacy.md) | ⚠ Legacy，被 `docs/specs/13_` 部分取代，保留作为历史记录 |

## 🔧 superpowers/ — 开发流程

| 目录 | 用途 |
|------|------|
| `superpowers/specs/` | 新功能 Spec 文档（格式: `YYYY-MM-DD-<topic>-design.md`） |
| `superpowers/plans/` | 任务拆分 Plan 文档 |

> 开发流程：Spec → Plan → Worktree → 编码 → 验证 → Review → Commit（详见 `CODEBUDDY.md`）

---

## 阅读路径

- **新成员快速了解** → `guides/02_AI项目速查.md` → `design/04_游戏总览.md` → `design/05_核心机制.md`
- **美术同学** → `art/07_美术需求文档.md` → `art/09_NanoBanana提示词.md`
- **开发新功能** → `specs/13_合成系统物理重设计需求文档.md`（核心设计） → 相关 specs
- **查配置数据** → `reference/03_资源清单.md`
