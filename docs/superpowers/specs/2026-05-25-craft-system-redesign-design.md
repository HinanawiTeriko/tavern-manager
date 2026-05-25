# 合成系统重制 — 设计规格

> 状态：已确认
> 日期：2026-05-25

---

## 一、目标

将现有"拖 2 材料→点按钮→匹配配方"的机械流程替换为**调和区 + 逐步加工 + 动态操作**的沉浸式合成体验。

核心改进：

- 干净台面——不放材料时无按钮
- 操作按材料动态出现，不适用者不显示
- 逐步加工链，中间产物是独立物品
- 失败产物链（过度加工→搞砸）
- 每个操作有独特手感（按住/转圈/连点）
- 独立香料系统

---

## 二、数据模型

### 2.1 `data/items.json` — 物品定义

```json
{
  "key": {
    "name": "中文名",
    "color": [r, g, b],
    "price": 0
  }
}
```

- `price > 0` = 可卖给客人的成品
- `price = 0` = 中间产物或失败品（也可上菜，客人性格系统后续对接）

完整物品清单见附录 A。

### 2.2 `data/operations.json` — 加工图

```json
{
  "item_key": {
    "operation": "result_key"
  }
}
```

- 每种物品列出可用操作及产物
- 没有定义的物品 = 不可再加工（成品或死胡同）
- 组合规则另表管理（见 2.3）

完整操作表见附录 B。

### 2.3 组合规则（CraftSystem 内部处理）

异类材料在调和区混合时产生新物品：

| 材料A | 材料B | 产物 |
|-------|-------|------|
| dough | meat_raw | dough_meat |
| ale | herb | ale_herb |
| grape | herb | grape_herb |
| meat_raw | ale | meat_stew_raw |

组合不是操作按钮触发，而是调和区检测到异类材料后询问"是否混合"。

### 2.4 旧文件淘汰

`data/recipes.json` 删除，内容迁移到 `items.json` + `operations.json` + 组合规则表。

---

## 三、调和区交互规则

### 3.1 空台面

调和区为空时，无任何操作按钮——只有空的容器。

### 3.2 放入材料

#### 同类材料（同一 item key 视为同类）

不询问，直接显示该材料的可用操作。

```
调和区: [面粉] [面粉]      （两个都是 flour）
按钮:   [搅拌]              （flour 唯一可用操作）
侧栏:   面团 (搅拌)          （点击→自动执行搅拌，产出 dough）
```

#### 异类材料（不同 item key）

调和区下面出现内联询问条 "混合 flour 和 meat_raw？" + [是] [否]
- **是** → 侧栏列出组合产物，调和区内材料自动消耗并执行组合
- **否** → 各管各的，分别显示各自的可能产物和操作

内联询问条是调和区下方临时出现的条形区域，不是弹窗，不打断操作。
选择后询问条消失。

```
调和区: [面粉] [生肉]
询问:   "是否混合面粉和生肉？"
  → 是: 侧栏出现 肉夹生面团(加热)
  → 否: 侧栏出现 面团(搅拌)  操作: [搅拌]  及  烤肉(加热)  操作: [加热]
```

#### 同材料反复添加

可堆叠，不重新询问。操作作用于该材料整体。

### 3.3 产物侧栏（ProductPanel）

调和区右侧实时显示当前可能产物：

- 列出所有当前材料支持的操作结果
- 异类材料混合后列出组合产物
- 玩家点击产物 → 自动消耗调和区内对应材料，执行所需操作序列，产出新物品放入调和区
- 如果只有一个可能产物，也可以直接点它

之后玩家可选择对新产物继续操作，或拖到快捷栏/成品槽。

### 3.4 调和区物品管理

- 调和区内的物品可以拖回快捷栏/背包
- 可以单独拖出某一个材料
- 点击产物时消耗对应材料

---

## 四、操作手感

### 4.1 四种操作

| 操作 | 交互方式 | 视觉反馈 | 耗时 |
|------|----------|----------|------|
| **加热** | 按住按钮不放 | 调和区颜色渐变暖色（橙→红），冒泡粒子动画 | 1.5s 持续按住 |
| **搅拌** | 按住按钮绕圈拖拽（跟踪鼠标旋转） | 调和区内漩涡动画，材料颜色均匀渐变 | 跟随鼠标旋转圈数（约3圈） |
| **摇晃** | 快速连点按钮（或左右甩鼠标） | 调和区抖动，材料跳动，液体晃荡效果 | 约1s 连点 |
| **倒出** | 点击，即刻完成 | 材料从调和区滑出到成品槽 | 瞬间 |

每种操作只在当前调和区内容支持时才显示按钮。

### 4.2 操作按钮样式

- 不使用文字，改用图标（火焰/螺旋/双向箭头/倒出箭头）
- 不适用时隐藏（不是灰掉）
- 加热按住时按钮本身有按压动画

---

## 五、失败产物链

过度加工导致失败：

```
生肉 ──加热──> 烤肉 ──加热──> 焦肉
面团 ──加热──> 面包 ──加热──> 焦面包
麦芽 ──加热──> 烤麦芽 ──加热──> 焦麦芽
```

- 失败品也定义在 `items.json` 中，price = 0
- 仍然可以上菜给客人
- 客人性格系统（未来）决定客人对失败品的反应
- 失败品不可继续加工（operations 表中无条目）
- 关键剧情物品（如 SleepPowder）不由加工产出，保持独立

---

## 六、香料系统（独立模块）

### 6.1 定位

香料**不属于合成**。它是成品产出后的可选后处理。独立系统，独立文件。

### 6.2 触发时机

调和区产出成品（price > 0 的物品）后，成品槽旁出现香料选择面板。

### 6.3 香料类型（初版）

| Key | 中文名 | 标签 | 来源 |
|-----|--------|------|------|
| spice | 辣 | 辛辣 | 采集/购买 |
| herb_spice | 香草 | 清香 | 采集/购买 |
| salt | 盐 | 咸味 | 采集/购买 |

### 6.4 交互

```
成品槽: [烤肉]
           ↓
香料面板: [🌶辣] [🌿香草] [🧂盐] [不加]
           ↓
成品 + "辣"标签 → 辣烤肉 → 上菜
```

- 不强制加香料，可以直接上菜
- 香料是消耗品，使用消耗库存
- 香料标签存在物品实例上，后续客人性格系统读此标签

### 6.5 文件

`data/seasonings.json` — 香料定义（名称、图标、颜色、消耗量）
`scripts/systems/SeasoningSystem.cs` — 香料逻辑（独立于 CraftSystem）

---

## 七、客人性格系统（占位）

本次**不实现**，但预留接口：

- `GuestData` 增加 `Personality` 字段（`Dictionary<string, int>`，key=标签，value=好感度）
- `EconomySystem` 增加 `RateServedItem(item, guest)` 方法
- 合成产出物品时在物品实例上附加标签（香料标签、失败标签、品质标签）
- `NarrativeManager.DialogueVars` 可读取上菜结果做分支

本次只保证：失败品和加香料的成品能正常上菜，价格暂用 item.price。性格系统后续 spec 独立设计。

---

## 八、文件变更清单

| 操作 | 文件 |
|------|------|
| **新建** | `data/items.json` |
| **新建** | `data/operations.json` |
| **新建** | `data/seasonings.json` |
| **新建** | `scripts/ui/MixingArea.cs` |
| **新建** | `scripts/ui/ProductPanel.cs` |
| **新建** | `scripts/ui/SeasoningPanel.cs` |
| **新建** | `scripts/systems/SeasoningSystem.cs` |
| **重写** | `scripts/systems/CraftSystem.cs` |
| **重写** | `scripts/ui/CraftStation.cs` |
| **修改** | `scripts/GameManager.cs` |
| **修改** | `scenes/ui/Tavern.tscn` |
| **删除** | `data/recipes.json` |

---

## 九、不涉及的内容

- 采集系统（DayMap/Gathering）
- 商店系统（ShopSystem）
- 对话/NPC 系统（NarrativeManager）
- 经济系统规则（EconomySystem）
- 客人性格系统（后续独立 spec）

---

## 附录 A：完整物品表

```json
{
  "flour":        { "name": "面粉",       "color": [0.7, 0.55, 0.3],  "price": 0 },
  "dough":        { "name": "面团",       "color": [0.8, 0.7, 0.5],   "price": 0 },
  "bread":        { "name": "面包",       "color": [0.75, 0.5, 0.2],  "price": 3 },
  "bread_burnt":  { "name": "焦面包",     "color": [0.1, 0.08, 0.05], "price": 0 },
  "meat_raw":     { "name": "生肉",       "color": [0.65, 0.2, 0.1],  "price": 0 },
  "meat_cooked":  { "name": "烤肉",       "color": [0.5, 0.15, 0.05], "price": 4 },
  "meat_burnt":   { "name": "焦肉",       "color": [0.1, 0.08, 0.05], "price": 0 },
  "ale":          { "name": "麦芽",       "color": [0.8, 0.6, 0.2],   "price": 0 },
  "ale_roasted":  { "name": "烤麦芽",     "color": [0.5, 0.35, 0.1],  "price": 0 },
  "ale_beer":     { "name": "麦芽酒",     "color": [0.7, 0.5, 0.15],  "price": 5 },
  "ale_burnt":    { "name": "焦麦芽",     "color": [0.08, 0.06, 0.04],"price": 0 },
  "grape":        { "name": "葡萄",       "color": [0.6, 0.1, 0.2],   "price": 0 },
  "grape_juice":  { "name": "葡萄汁",     "color": [0.5, 0.08, 0.2],  "price": 0 },
  "wine":         { "name": "葡萄酒",     "color": [0.4, 0.05, 0.2],  "price": 5 },
  "herb":         { "name": "草药",       "color": [0.2, 0.7, 0.2],   "price": 0 },
  "herb_tea":     { "name": "草药茶",     "color": [0.3, 0.5, 0.2],   "price": 3 },
  "dough_meat":   { "name": "肉夹生面团",  "color": [0.7, 0.5, 0.3],   "price": 0 },
  "meat_sand":    { "name": "肉夹面包",    "color": [0.65, 0.4, 0.2],  "price": 9 },
  "ale_herb":     { "name": "草药麦芽",    "color": [0.5, 0.5, 0.2],   "price": 0 },
  "herbal_ale":   { "name": "草药麦酒",    "color": [0.6, 0.45, 0.2],  "price": 10 },
  "grape_herb":   { "name": "香料葡萄",    "color": [0.5, 0.2, 0.2],   "price": 0 },
  "spiced_wine":  { "name": "香料红酒",    "color": [0.45, 0.1, 0.2],  "price": 11 },
  "meat_stew_raw":{ "name": "生肉汤",      "color": [0.5, 0.3, 0.15],  "price": 0 },
  "meat_stew":    { "name": "肉汤",        "color": [0.55, 0.3, 0.15], "price": 12 },
  "sleep_powder": { "name": "沉睡花粉",    "color": [0.55, 0.4, 0.75], "price": 0 }
}
```

24 种物品：5 种原材料 + 10 种中间产物 + 4 种失败品 + 5 种特殊/剧情物品

## 附录 B：完整操作表

```json
{
  "flour":       { "stir": "dough" },
  "dough":       { "heat": "bread" },
  "bread":       { "heat": "bread_burnt" },
  "meat_raw":    { "heat": "meat_cooked" },
  "meat_cooked": { "heat": "meat_burnt" },
  "ale":         { "heat": "ale_roasted" },
  "ale_roasted": { "stir": "ale_beer" },
  "ale_beer":    { "heat": "ale_burnt" },
  "grape":       { "stir": "grape_juice" },
  "grape_juice": { "heat": "wine" },
  "herb":        { "heat": "herb_tea" },
  "dough_meat":  { "heat": "meat_sand" },
  "meat_sand":   { "heat": "bread_burnt" },
  "ale_herb":    { "heat": "herbal_ale" },
  "grape_herb":  { "heat": "spiced_wine" },
  "meat_stew_raw":{ "heat": "meat_stew" }
}
```

## 附录 C：组合规则表

```json
[
  { "a": "dough",       "b": "meat_raw", "result": "dough_meat" },
  { "a": "ale",         "b": "herb",     "result": "ale_herb" },
  { "a": "grape",       "b": "herb",     "result": "grape_herb" },
  { "a": "meat_raw",    "b": "ale",      "result": "meat_stew_raw" }
]
```
