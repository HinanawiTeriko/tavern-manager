# 商店系统 (Shop System) 设计文档

> 日期: 2026-05-24 | 状态: 已确认

---

## 目标

在 DayMap 白天阶段增加商店入口，玩家可用金币直接购买材料和解锁配方。解决当前"金币无处花、材料无限供应"的问题，给经济系统注入意义。

---

## 玩法概述

- **入口**: DayMap 白天阶段，在采集列表旁增加"商店"标签/面板
- **货币**: 金币（EconomySystem.Gold）
- **不消耗体力**: 商店与采集并列，互不占用体力
- **两种模式**: 常规商店（每天开放）和米拉商店（米拉晚间到访日时，商店替换为米拉的旅行商店）

---

## 商品设计

### 材料（永久可购，无限制）

| 材料 Key | 材料名 | 单价 | 对应成品 | 成品售价 | 毛利 |
|----------|--------|------|----------|----------|------|
| Ale | 麦芽 | 2金 | 麦芽酒 | 5金 | +3 |
| Wine | 葡萄 | 2金 | 葡萄酒 | 5金 | +3 |
| Bread | 面粉 | 2金 | 面包 | 3金 | +1 |
| Meat | 生肉 | 3金 | 烤肉 | 4金 | +1 |
| Herb | 草药 | 2金 | 草药茶 | 3金 | +1 |

合成配方利润率更高（如肉汤材料成本 5 金、售价 12 金），激励解锁。

### 配方（一次性购买解锁，永久可用）

| 配方 Key | 配方名 | 解锁价格 | 材料 | 成品售价 |
|----------|--------|----------|------|----------|
| Herbal Ale | 草药麦酒 | 20金 | 麦芽+草药 | 10金 |
| SpicedWine | 香料红酒 | 20金 | 葡萄+草药 | 11金 |
| MeatSand | 肉夹面包 | 30金 | 面粉+生肉 | 9金 |
| Meat Stew | 肉汤 | 40金 | 生肉+麦芽 | 12金 |

初始状态: 5 种单品配方（麦芽酒/葡萄酒/面包/烤肉/草药茶）开局可用，4 种合成配方锁定。

### 米拉商店特殊规则

当天晚间有 NPC "米拉"到访时（当前为 Day 4）:
- 商店标题变为"米拉的旅行商店"
- 所有材料打 8 折（向下取整，如 3×0.8=2.4→2）
- 配方价格不变
- 后续可扩展专属商品（当前版本不做）

判断方式: 检查 `NarrativeManager.GetTodayScenes(currentDay)` 中是否有 NPC Id == "mira"。

---

## 架构

### 新文件

| 文件 | 职责 |
|------|------|
| `scripts/systems/ShopSystem.cs` | 商店逻辑：商品配置、购买材料、解锁配方、米拉状态判断、已解锁配方追踪 |
| `data/shop.json` | 商店配置：材料价格表、配方解锁价格表、米拉折扣率 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `scripts/systems/CraftSystem.cs` | 新增 `UnlockedRecipes` HashSet、`IsRecipeUnlocked()`、`UnlockRecipe()` |
| `scripts/systems/EconomySystem.cs` | 新增 `SpendGold(int amount)` 方法，返回 bool，金币不足返回 false |
| `scripts/ui/DayMapView.cs` | 新增商店 UI 面板（标签切换采集/商店、材料购买行、配方解锁行） |
| `scripts/GameManager.cs` | 初始化 ShopSystem、连接商店购买信号、重构 ServeRequested 中的已解锁配方检查 |

---

## 数据模型

### shop.json

```json
{
  "materials": [
    { "key": "Ale", "price": 2 },
    { "key": "Wine", "price": 2 },
    { "key": "Bread", "price": 2 },
    { "key": "Meat", "price": 3 },
    { "key": "Herb", "price": 2 }
  ],
  "recipeUnlocks": [
    { "key": "Herbal Ale", "price": 20 },
    { "key": "SpicedWine", "price": 20 },
    { "key": "MeatSand", "price": 30 },
    { "key": "Meat Stew", "price": 40 }
  ],
  "miraDiscount": 0.8
}
```

### ShopSystem 核心接口

```csharp
public class ShopSystem
{
    // 材料价格查询
    public int GetMaterialPrice(string materialKey);        // 原价
    public int GetMaterialPrice(string materialKey, bool isMira); // 米拉折后价

    // 配方解锁
    public int GetRecipeUnlockPrice(string recipeKey);
    public bool IsRecipeUnlocked(string recipeKey);
    public bool UnlockRecipe(string recipeKey);    // 返回是否成功（已解锁返回 false）

    // 米拉状态
    public bool IsMiraShopToday(int currentDay);   // 检查今日是否有米拉到访

    // 购买操作（由 GameManager 协调）
    public bool BuyMaterial(string key, int quantity, EconomySystem economy, Dictionary<string,int> inventory);
    public bool BuyRecipeUnlock(string key, EconomySystem economy);

    // 配置加载
    public void LoadConfig();
}
```

### CraftSystem 新增

```csharp
public HashSet<string> UnlockedRecipes { get; private set; } = new();

public bool IsRecipeUnlocked(string recipeKey) => UnlockedRecipes.Contains(recipeKey);

public void UnlockRecipe(string recipeKey) => UnlockedRecipes.Add(recipeKey);

// LoadRecipes() 中初始化：5 种单品配方默认加入 UnlockedRecipes
```

### EconomySystem 新增

```csharp
public bool SpendGold(int amount)
{
    if (Gold < amount) return false;
    Gold -= amount;
    EmitChanged();
    return true;
}
```

---

## UI 布局 (DayMap 改造)

DayMap 当前是单一采集面板，改造为标签切换：

```
┌─────────────────────── DayMap 1280×720 ───────────────────────┐
│  TopBar: [体力: 5/5] [第 N/30 天 — 白天·采集]                  │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │  [采集]  [商店]          ← 标签切换按钮                   │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │                                                        │  │
│  │  采集面板 (现有)          商店面板 (新增)                  │  │
│  │                                                        │  │
│  │  ┌─ 采集地点1 ─┐         ┌─ 购买材料 ──────────────┐   │  │
│  │  │ …           │         │ 麦芽  2金  [+][-][购买]  │   │  │
│  │  ├─ 采集地点2 ─┤         │ 葡萄  2金  [+][-][购买]  │   │  │
│  │  │ …           │         │ 面粉  2金  [+][-][购买]  │   │  │
│  │  ├─ … ────────┤         │ 生肉  3金  [+][-][购买]  │   │  │
│  │  │ …           │         │ 草药  2金  [+][-][购买]  │   │  │
│  │  └────────────┘         └──────────────────────────┘   │  │
│  │                                                        │  │
│  │                          ┌─ 解锁配方 ──────────────┐   │  │
│  │                          │ 草药麦酒  20金  [购买]    │   │  │
│  │                          │ 香料红酒  20金  [购买]    │   │  │
│  │                          │ 肉夹面包  30金  [购买]    │   │  │
│  │                          │ 肉汤      40金  [购买]    │   │  │
│  │                          └──────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│  [出发]  [跳过准备]                    金币: XXX              │
└──────────────────────────────────────────────────────────────┘
```

- 标签切换: "采集"和"商店"两个按钮，互斥高亮，切换面板可见性
- 材料购买: 每行 [+][-] 调整数量，[购买] 一次性买断当前数量
- 配方解锁: 已解锁显示"已拥有"灰色，未解锁显示价格按钮
- 米拉模式: 标题变为"米拉的旅行商店"，材料价格显示原价划掉+折后价

符号说明: 具体价格显示格式、布局位置由实现阶段细化。

---

## 数据流

```
DayMap 场景加载
  → DayMapView._Ready()
    → 加载 ShopSystem 配置
    → 构建商店 UI（材料行 + 配方行）
    → 检查 IsMiraShopToday(CurrentDay) 决定商店模式

玩家在商店面板操作:
  购买材料:
    → DayMapView 调用 GameManager.BuyMaterial(key, qty)
      → EconomySystem.SpendGold(totalPrice) → 失败则提示"金币不足"
      → GameManager.Inventory[key] += qty
      → InventoryChanged?.Invoke()

  解锁配方:
    → DayMapView 调用 GameManager.BuyRecipeUnlock(key)
      → EconomySystem.SpendGold(price) → 失败则提示"金币不足"
      → CraftSystem.UnlockRecipe(key)
      → 刷新配方 UI（按钮变"已拥有"）

  GuestSystem 订单生成:
    → 当前代码 Guests 初始化用 Craft.RecipeKeys（全部9种）
    → 需改为只从已解锁配方中随机选单
    → GuestSystem 构造函数改为接收已解锁列表
```

---

## 配方锁定对游戏的影响

- **客人生成**: GuestSystem 只从已解锁配方中选单。开局只有 5 种单品，配方越解锁越多
- **合成台**: 配方匹配不变，但锁定配方即使材料正确也返回"配方未解锁"提示
- **配方 UI**: OverlayMenu 配方标签中，锁定配方显示"???"和灰色，解锁后正常显示
- **存档兼容**: 当前无存档系统，无向后兼容问题

---

## 常量

- 商店配置路径: `res://data/shop.json`
- 米拉 NPC ID: `mira`
- 米拉折扣: 0.8（材料 8 折，向下取整）
- 初始解锁配方数: 5 种（Ale, Wine, Bread, Meat, Herb Tea）
- 材料默认购买数量: 1，可增减

---

## 不在范围内的内容

- 夜晚 Tavern 中嵌入商店（仅 DayMap）
- 米拉专属商品（当前版本预留扩展点，不做）
- 配方升级/永久 buff（单体配方解锁模式）
- 体力与商店的关联
- 商店价格随酒馆等级变化
- 数量折扣/批量优惠
- 出售材料给商店（只买不卖）
