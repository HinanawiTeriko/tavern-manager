# 香料台重设计

> **Goal:** 重做香料系统交互——从"看不见的 SeasoningZone + 未接入的 SeasoningPanel"改为"显眼的香料台，拖成品进去撒香料，拖出来上菜"。

## 当前状态

- SeasoningZone 存在但太小（110×59px），用户感知不到
- SeasoningPanel 从未接入，死代码
- 成品进 ResultSlot → 上菜，香料流程不直观

## 新交互流程

```
成品产出 → 留在合成区（MixingArea/ResultSlot）
              │
              ├── 直接上菜（现有逻辑）
              │
              └── 拖入香料台 → 撒香料 → 拖成品给顾客
```

## SeasoningZone 重写

### 三种状态

| 状态 | 触发 | 显示 | 接收拖入 | 可拖出 |
|------|------|------|----------|--------|
| 空 | 初始 / 成品被取走 | 虚线框 + "放入成品" | 成品 | — |
| 有成品 | 成品拖入 | 成品名称 + 颜色色块 | 香料 | 成品 |
| 已撒香料 | 香料拖入 | 成品名称 + 香料名（如"烤肉 · 辣"） | — | 成品 |

### 拖入逻辑

- **拖入成品**：`_drag_material` 为空但有 `_drag_result_key`（从 ResultSlot 拖来的成品 key）
- **拖入香料**：`_drag_material` 不为空 → 调用 `SeasoningSystem.is_seasoning()` 检查 → 设置 `_applied_seasoning`

### 拖出逻辑

- 鼠标按下香料台上的成品 → 开始拖拽 → 拖到顾客区 → 发射 `serve_requested(item_key, seasoning_tag)`

## 改动清单

| 文件 | 改动 |
|------|------|
| `scripts/ui/seasoning_zone.gd` | 重写：三状态、接收成品拖入、接收香料拖入、拖出成品 |
| `scripts/ui/craft_station.gd` | 成品产出留在 ResultSlot（不变）；新增拖 ResultSlot 到 SeasoningZone；拖 SeasoningZone 到顾客区上菜 |
| `scripts/ui/seasoning_panel.gd` | 删除 |
| `scenes/ui/Tavern.tscn` | 删除 SeasoningPanel 节点；SeasoningZone 尺寸调整 |

## 不变

- `SeasoningSystem` 数据层
- `GameManager.serve_requested(item_key, seasoning_tag)` 信号
- `GameManager._on_serve` 上菜逻辑
- 快捷栏香料来源（sleep_powder 采集、其他从商店买）
