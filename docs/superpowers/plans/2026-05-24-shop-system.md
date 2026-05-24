# 商店系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a shop to DayMap where players spend gold to buy materials and unlock recipes.

**Architecture:** New `ShopSystem` class holds config/prices loaded from `data/shop.json`. `CraftSystem` gains `UnlockedRecipes` tracking — 5 basic recipes free, 4 require purchase. `EconomySystem` gets `SpendGold()`. `GameManager` coordinates purchases between systems. `DayMapView` gets tab switching (采集/商店) with programmatic shop UI. `GuestSystem` filters orders to unlocked recipes only.

**Tech Stack:** Godot 4.6 .NET/C#, JSON config, HBoxContainer/VBoxContainer UI

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新增 | `data/shop.json` | 商店配置（材料价格、配方解锁价格、米拉折扣率） |
| 新增 | `scripts/systems/ShopSystem.cs` | 价格查询、米拉判定、配置加载 |
| 修改 | `scripts/systems/EconomySystem.cs` | 新增 `SpendGold(int)` 方法 |
| 修改 | `scripts/systems/CraftSystem.cs` | 新增 `UnlockedRecipes` HashSet、`IsRecipeUnlocked()`、`UnlockRecipe()` |
| 修改 | `scripts/systems/GuestSystem.cs` | 构造函数改为接收 `Func<string[]>` 动态获取已解锁配方 |
| 修改 | `scripts/ui/DayMapView.cs` | 标签切换 UI + 商店面板（材料购买行/配方解锁行） |
| 修改 | `scripts/GameManager.cs` | 初始化 ShopSystem、`BuyMaterial()`、`BuyRecipeUnlock()` |
| 修改 | `scripts/ui/TavernView.cs` | BuildRecipeList 对锁定配方显示"???"/灰色 |
| 修改 | `scenes/ui/DayMap.tscn` | TopBar 添加 GoldLabel |

---

### Task 1: 创建商店配置数据文件

**Files:**
- Create: `data/shop.json`

- [ ] **Step 1: 创建 shop.json**

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

- [ ] **Step 2: 验证文件格式**

Run: `powershell -Command "Get-Content data/shop.json | ConvertFrom-Json"` (or just visual check)
Expected: Valid JSON.

- [ ] **Step 3: Commit**

```bash
git add data/shop.json
git commit -m "feat: add shop.json config for material prices and recipe unlocks"
```

---

### Task 2: EconomySystem.SpendGold

**Files:**
- Modify: `scripts/systems/EconomySystem.cs`

- [ ] **Step 1: 在 AddGold 方法之后、AddReputation 方法之前插入 SpendGold 方法**

当前 AddGold 方法在第 17-22 行。在 AddGold 的闭合 `}` 之后、`public void AddReputation` 之前，插入：

```csharp
    public bool SpendGold(int amount)
    {
        if (Gold < amount) return false;
        Gold -= amount;
        EmitChanged();
        return true;
    }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/EconomySystem.cs
git commit -m "feat: add SpendGold method to EconomySystem"
```

---

### Task 3: CraftSystem 配方解锁追踪

**Files:**
- Modify: `scripts/systems/CraftSystem.cs`

- [ ] **Step 1: 在 `RecipeKeys` 属性之后添加 UnlockedRecipes 及相关方法**

当前 `RecipeKeys` 在第 32 行。在其后插入：

```csharp
    public HashSet<string> UnlockedRecipes { get; private set; } = new();

    public bool IsRecipeUnlocked(string recipeKey) => UnlockedRecipes.Contains(recipeKey);

    public void UnlockRecipe(string recipeKey)
    {
        UnlockedRecipes.Add(recipeKey);
        GD.Print($"[Craft] 配方已解锁: {recipeKey}");
    }
```

- [ ] **Step 2: 在 LoadRecipes() 方法末尾初始化默认解锁配方**

在 `LoadRecipes()` 方法的 `GD.Print(...)` 行之后、闭合 `}` 之前，添加：

```csharp
        // 5 种单品配方默认解锁
        var defaultUnlocked = new[] { "Ale", "Wine", "Bread", "Meat", "Herb Tea" };
        foreach (var key in defaultUnlocked)
            UnlockedRecipes.Add(key);
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/CraftSystem.cs
git commit -m "feat: add UnlockedRecipes tracking to CraftSystem"
```

---

### Task 4: ShopSystem 核心类

**Files:**
- Create: `scripts/systems/ShopSystem.cs`

- [ ] **Step 1: 创建 ShopSystem.cs**

```csharp
using Godot;
using System.Collections.Generic;
using System.Text.Json;

public class ShopMaterialEntry
{
    public string Key { get; set; }
    public int Price { get; set; }
}

public class ShopRecipeEntry
{
    public string Key { get; set; }
    public int Price { get; set; }
}

public class ShopConfig
{
    public ShopMaterialEntry[] Materials { get; set; }
    public ShopRecipeEntry[] RecipeUnlocks { get; set; }
    public double MiraDiscount { get; set; } = 0.8;
}

public class ShopSystem
{
    private Dictionary<string, int> _materialPrices = new();
    private Dictionary<string, int> _recipeUnlockPrices = new();
    private double _miraDiscount = 0.8;

    public void LoadConfig()
    {
        try
        {
            using var file = FileAccess.Open("res://data/shop.json", FileAccess.ModeFlags.Read);
            if (file == null)
            {
                GD.PrintErr("[Shop] shop.json 未找到");
                return;
            }
            var json = file.GetAsText();
            var data = JsonSerializer.Deserialize<ShopConfig>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            _materialPrices.Clear();
            if (data.Materials != null)
                foreach (var m in data.Materials)
                    _materialPrices[m.Key] = m.Price;

            _recipeUnlockPrices.Clear();
            if (data.RecipeUnlocks != null)
                foreach (var r in data.RecipeUnlocks)
                    _recipeUnlockPrices[r.Key] = r.Price;

            _miraDiscount = data.MiraDiscount;
            GD.Print($"[Shop] 加载 {_materialPrices.Count} 种材料, {_recipeUnlockPrices.Count} 种可解锁配方");
        }
        catch (System.Exception e)
        {
            GD.PrintErr($"[Shop] 加载配置失败: {e.Message}");
        }
    }

    public int GetMaterialPrice(string key, bool miraActive = false)
    {
        if (!_materialPrices.TryGetValue(key, out var price)) return 999;
        if (miraActive) return Mathf.FloorToInt(price * _miraDiscount);
        return price;
    }

    public int GetRecipeUnlockPrice(string key)
    {
        _recipeUnlockPrices.TryGetValue(key, out var price);
        return price; // 0 if not found (already unlocked or invalid key)
    }

    public bool IsMiraShopToday(int currentDay, NarrativeManager narrative)
    {
        var scenes = narrative.GetTodayScenes(currentDay);
        foreach (var npc in scenes)
        {
            if (npc.Id == "mira") return true;
        }
        return false;
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/ShopSystem.cs
git commit -m "feat: add ShopSystem with config loading and price queries"
```

---

### Task 5: GameManager 集成 ShopSystem

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 添加 ShopSystem 字段和属性**

在 `NarrativeManager` 字段之后（第 26 行后）添加：

```csharp
    public ShopSystem Shop { get; private set; } = new();
```

- [ ] **Step 2: 在 _Ready() 中初始化 ShopSystem 并修改 GuestSystem 构造**

在 `_Ready()` 方法的 `Narrative.LoadNpcData();` 之后插入：

```csharp
        // 初始化 ShopSystem
        Shop.LoadConfig();
```

将 GuestSystem 构造从：

```csharp
        Guests = new GuestSystem(Craft.RecipeKeys);
```

改为：

```csharp
        Guests = new GuestSystem(() => Craft.UnlockedRecipes.ToArray());
```

- [ ] **Step 3: 添加 BuyMaterial 和 BuyRecipeUnlock 方法**

在 `EndNight()` 方法之后、`RefreshTavernUI()` 之前（第 316 行之后）添加：

```csharp
    // ── 商店购买 ──
    public bool BuyMaterial(string key, int quantity, bool miraActive = false)
    {
        if (quantity < 1) return false;
        var unitPrice = Shop.GetMaterialPrice(key, miraActive);
        var total = unitPrice * quantity;
        if (!Economy.SpendGold(total))
        {
            _tavernView?.ShowMessage("金币不足！", Colors.Orange);
            return false;
        }
        _inv.TryGetValue(key, out var existing);
        _inv[key] = existing + quantity;
        NotifyInventoryChanged();
        return true;
    }

    public bool BuyRecipeUnlock(string key)
    {
        if (Craft.IsRecipeUnlocked(key)) return false;
        var price = Shop.GetRecipeUnlockPrice(key);
        if (price <= 0) return false;
        if (!Economy.SpendGold(price))
        {
            _tavernView?.ShowMessage("金币不足！", Colors.Orange);
            return false;
        }
        Craft.UnlockRecipe(key);
        return true;
    }
```

注: `_tavernView` 在 DayMap 阶段为 null，`ShowMessage` 调用会静默忽略。金币不足时购买失败，DayMapView 应自行检查返回值并显示提示。

- [ ] **Step 4: 在 CraftRequested 回调中增加配方解锁检查**

在 `RegisterView` 方法的 `craftStation.CraftRequested += () => {` 回调中，`Craft.TryMatch(...)` 成功后添加解锁检查。找到：

```csharp
                    if (Craft.TryMatch(mat1, mat2, out var key))
                    {
                        Craft.CraftedKey = key;
```

改为：

```csharp
                    if (Craft.TryMatch(mat1, mat2, out var key))
                    {
                        if (!Craft.IsRecipeUnlocked(key))
                        {
                            tv.ShowMessage("配方未解锁！请前往商店购买。", Colors.Orange);
                            return;
                        }
                        Craft.CraftedKey = key;
```

- [ ] **Step 5: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: integrate ShopSystem into GameManager with buy methods"
```

---

### Task 6: GuestSystem 动态配方过滤

**Files:**
- Modify: `scripts/systems/GuestSystem.cs`

- [ ] **Step 1: 将 _normalOrders 从 string[] 改为 Func<string[]>**

将构造函数中的字段类型和赋值改为动态获取。

当前（第 30、33、39-42 行）：

```csharp
    private readonly string[] _normalOrders;
    // ...
    public GuestSystem(string[] recipeKeys)
    {
        _normalOrders = recipeKeys;
    }
```

改为：

```csharp
    private readonly Func<string[]> _getAvailableOrders;
    // ...
    public GuestSystem(Func<string[]> getAvailableOrders)
    {
        _getAvailableOrders = getAvailableOrders;
    }
```

- [ ] **Step 2: 修改 SpawnNormal 使用动态列表**

当前 SpawnNormal 第 71 行：

```csharp
            OrderKey = _normalOrders[_rng.Next(_normalOrders.Length)],
```

改为：

```csharp
            var orders = _getAvailableOrders();
            OrderKey = orders[_rng.Next(orders.Length)],
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/GuestSystem.cs
git commit -m "feat: use dynamic unlocked recipe list for guest orders"
```

---

### Task 7: DayMapView 商店 UI

**Files:**
- Modify: `scripts/ui/DayMapView.cs`
- Modify: `scenes/ui/DayMap.tscn`

- [ ] **Step 1: DayMap.tscn 添加 GoldLabel**

在 `TopBar/StaminaLabel` 节点之后添加 GoldLabel：

在 `DayMap.tscn` 的 `[node name="StaminaLabel" ...]` 块之后（第 36 行后），GoButton 节点之前，插入：

```
[node name="GoldLabel" type="Label" parent="TopBar"]
layout_mode = 0
offset_left = 800.0
offset_top = 10.0
offset_right = 990.0
offset_bottom = 50.0
text = "金币：0"
horizontal_alignment = 2
```

- [ ] **Step 2: DayMapView.cs 添加新字段**

在现有字段区域（`_locSubBtns` 字典之后，`GatheringConfirmed` 事件之前）添加：

```csharp
    // ── 商店 ──
    private bool _isShopTab;
    private Button _gatherTabBtn;
    private Button _shopTabBtn;
    private Control _shopPanel;
    private Label _shopTitle;
    private Label _goldLabel;
    private VBoxContainer _materialList;
    private VBoxContainer _recipeList;
    private bool _isMiraShop;
    private Dictionary<string, Label> _matQtyLabels = new();
```

- [ ] **Step 3: DayMapView.cs _Ready() 末尾添加初始化代码**

在 `_Ready()` 方法的 `BuildLocationUI();` 之后、背景加载代码之前，添加：

```csharp
        // Gold label
        _goldLabel = GetNode<Label>("TopBar/GoldLabel");
        _goldLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
        _goldLabel.AddThemeFontSizeOverride("font_size", 20);

        // Tab buttons
        BuildTabButtons();
        BuildShopUI();
```

- [ ] **Step 4: 在 ShowDay 方法中刷新金币和重置标签**

在 `ShowDay` 方法末尾（`_goButton.Disabled = false;` 之前或之后），添加：

```csharp
        _isShopTab = false;
        UpdateTabAppearance();
        RefreshShopUI();
        UpdateGoldDisplay();
```

并在 `ShowDay` 方法参数中不再需要单独设置 — 改为 GameManager 推送金币。添加公开方法：

```csharp
    public void UpdateGoldDisplay()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        if (gm != null)
            _goldLabel.Text = $"金币：{gm.Economy.Gold}";
    }
```

- [ ] **Step 5: 添加 BuildTabButtons 方法**

在 `BuildLocationUI()` 方法之后添加：

```csharp
    private void BuildTabButtons()
    {
        var mapArea = GetNode<Control>("MapArea");
        var tabRow = new HBoxContainer();
        tabRow.AddThemeConstantOverride("separation", 8);
        tabRow.CustomMinimumSize = new Vector2(0, 40);

        _gatherTabBtn = new Button { Text = "采集", CustomMinimumSize = new Vector2(100, 36) };
        ThemeColors.StyleButton(_gatherTabBtn, 16);
        _gatherTabBtn.Pressed += () => SwitchTab(false);
        tabRow.AddChild(_gatherTabBtn);

        _shopTabBtn = new Button { Text = "商店", CustomMinimumSize = new Vector2(100, 36) };
        ThemeColors.StyleButton(_shopTabBtn, 16);
        _shopTabBtn.Pressed += () => SwitchTab(true);
        tabRow.AddChild(_shopTabBtn);

        // Insert tab row at the top of MapArea (above TitleLabel and LocationList)
        mapArea.AddChild(tabRow);
        mapArea.MoveChild(tabRow, 0);

        UpdateTabAppearance();
    }
```

- [ ] **Step 6: 添加 SwitchTab 和 UpdateTabAppearance 方法**

```csharp
    private void SwitchTab(bool shop)
    {
        _isShopTab = shop;
        UpdateTabAppearance();

        var mapArea = GetNode<Control>("MapArea");
        var titleLabel = mapArea.GetNode<Label>("TitleLabel");
        var locationList = mapArea.GetNode<VBoxContainer>("LocationList");

        titleLabel.Visible = !shop;
        locationList.Visible = !shop;
        _shopPanel.Visible = shop;

        if (shop)
            RefreshShopUI();
    }

    private void UpdateTabAppearance()
    {
        if (_gatherTabBtn == null || _shopTabBtn == null) return;

        _gatherTabBtn.Modulate = _isShopTab ? Colors.DimGray : Colors.White;
        _shopTabBtn.Modulate = _isShopTab ? Colors.White : Colors.DimGray;
    }
```

- [ ] **Step 7: 添加 BuildShopUI 方法**

```csharp
    private void BuildShopUI()
    {
        _shopPanel = new Control();
        _shopPanel.LayoutMode = 0;
        _shopPanel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect, Control.LayoutPresetMode.MinSize);
        _shopPanel.OffsetLeft = 0;
        _shopPanel.OffsetTop = 90;
        _shopPanel.OffsetRight = 1000;
        _shopPanel.OffsetBottom = 420;
        _shopPanel.Visible = false;
        GetNode<Control>("MapArea").AddChild(_shopPanel);

        // Shop title
        _shopTitle = new Label();
        _shopTitle.CustomMinimumSize = new Vector2(0, 36);
        ThemeColors.StyleHeader(_shopTitle, 22);
        _shopPanel.AddChild(_shopTitle);

        // ── 材料购买区域 ──
        var matTitle = new Label { Text = "—— 购买材料 ——" };
        matTitle.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        matTitle.AddThemeFontSizeOverride("font_size", 16);
        matTitle.CustomMinimumSize = new Vector2(0, 30);
        _shopPanel.AddChild(matTitle);

        _materialList = new VBoxContainer();
        _materialList.AddThemeConstantOverride("separation", 4);
        _shopPanel.AddChild(_materialList);

        // ── 配方解锁区域 ──
        var recipeTitle = new Label { Text = "—— 解锁配方 ——" };
        recipeTitle.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        recipeTitle.AddThemeFontSizeOverride("font_size", 16);
        recipeTitle.CustomMinimumSize = new Vector2(0, 30);
        var yAfterMats = 30 + 5 * 44 + 30;
        recipeTitle.OffsetTop = yAfterMats;
        _shopPanel.AddChild(recipeTitle);

        _recipeList = new VBoxContainer();
        _recipeList.AddThemeConstantOverride("separation", 4);
        _shopPanel.AddChild(_recipeList);
    }
```

- [ ] **Step 8: 添加 RefreshShopUI 方法**

```csharp
    private void RefreshShopUI()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        if (gm == null) return;

        _isMiraShop = gm.Shop.IsMiraShopToday(gm.Economy.CurrentDay, gm.Narrative);
        _shopTitle.Text = _isMiraShop ? "米拉的旅行商店" : "商店";

        BuildMaterialRows(gm);
        BuildRecipeRows(gm);
        UpdateGoldDisplay();
    }

    private void BuildMaterialRows(GameManager gm)
    {
        foreach (var child in _materialList.GetChildren())
            child.QueueFree();
        _matQtyLabels.Clear();

        var materials = new[] { ("Ale", "麦芽"), ("Wine", "葡萄"), ("Bread", "面粉"), ("Meat", "生肉"), ("Herb", "草药") };

        foreach (var (key, name) in materials)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            row.CustomMinimumSize = new Vector2(0, 40);

            var nameLabel = new Label
            {
                Text = $"{name}",
                CustomMinimumSize = new Vector2(70, 0)
            };
            nameLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            nameLabel.AddThemeFontSizeOverride("font_size", 16);
            row.AddChild(nameLabel);

            int price = gm.Shop.GetMaterialPrice(key, _isMiraShop);
            var priceLabel = new Label
            {
                Text = _isMiraShop
                    ? $"{gm.Shop.GetMaterialPrice(key)}→{price}金"
                    : $"{price}金",
                CustomMinimumSize = new Vector2(70, 0)
            };
            priceLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
            priceLabel.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(priceLabel);

            var subBtn = new Button { Text = "-", CustomMinimumSize = new Vector2(36, 30) };
            ThemeColors.StyleButton(subBtn, 14);
            string matKey = key;
            var qtyLabel = new Label
            {
                Text = "0",
                CustomMinimumSize = new Vector2(30, 0),
                HorizontalAlignment = HorizontalAlignment.Center
            };
            qtyLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
            qtyLabel.AddThemeFontSizeOverride("font_size", 18);
            _matQtyLabels[key] = qtyLabel;
            var addBtn = new Button { Text = "+", CustomMinimumSize = new Vector2(36, 30) };
            ThemeColors.StyleButton(addBtn, 14);
            subBtn.Pressed += () => {
                var cur = int.Parse(qtyLabel.Text);
                if (cur > 0) { cur--; qtyLabel.Text = cur.ToString(); }
            };
            addBtn.Pressed += () => {
                var cur = int.Parse(qtyLabel.Text);
                cur++; qtyLabel.Text = cur.ToString();
            };

            var buyBtn = new Button { Text = "购买", CustomMinimumSize = new Vector2(56, 30) };
            ThemeColors.StyleButton(buyBtn, 14);
            buyBtn.Pressed += () => {
                var qty = int.Parse(qtyLabel.Text);
                if (qty < 1) return;
                if (gm.BuyMaterial(matKey, qty, _isMiraShop))
                {
                    qtyLabel.Text = "0";
                    UpdateGoldDisplay();
                }
            };

            row.AddChild(subBtn);
            row.AddChild(qtyLabel);
            row.AddChild(addBtn);
            row.AddChild(buyBtn);

            _materialList.AddChild(row);
        }
    }

    private void BuildRecipeRows(GameManager gm)
    {
        foreach (var child in _recipeList.GetChildren())
            child.QueueFree();

        var unlocks = new[] {
            ("Herbal Ale", "草药麦酒"), ("SpicedWine", "香料红酒"),
            ("MeatSand", "肉夹面包"), ("Meat Stew", "肉汤")
        };

        foreach (var (key, name) in unlocks)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            row.CustomMinimumSize = new Vector2(0, 40);

            var nameLabel = new Label
            {
                Text = name,
                CustomMinimumSize = new Vector2(100, 0)
            };
            nameLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            nameLabel.AddThemeFontSizeOverride("font_size", 16);
            row.AddChild(nameLabel);

            if (gm.Craft.IsRecipeUnlocked(key))
            {
                var owned = new Label
                {
                    Text = "已拥有",
                    CustomMinimumSize = new Vector2(80, 0)
                };
                owned.AddThemeColorOverride("font_color", ThemeColors.TextDim);
                owned.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(owned);
            }
            else
            {
                int price = gm.Shop.GetRecipeUnlockPrice(key);
                var priceLabel = new Label
                {
                    Text = $"{price}金",
                    CustomMinimumSize = new Vector2(60, 0)
                };
                priceLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
                priceLabel.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(priceLabel);

                var unlockBtn = new Button { Text = "解锁", CustomMinimumSize = new Vector2(56, 30) };
                ThemeColors.StyleButton(unlockBtn, 14);
                string rKey = key;
                unlockBtn.Pressed += () => {
                    if (gm.BuyRecipeUnlock(rKey))
                    {
                        UpdateGoldDisplay();
                        BuildRecipeRows(gm);
                    }
                };
                row.AddChild(unlockBtn);
            }

            _recipeList.AddChild(row);
        }
    }
```

- [ ] **Step 9: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 10: Commit**

```bash
git add scripts/ui/DayMapView.cs scenes/ui/DayMap.tscn
git commit -m "feat: add shop UI with tab switching to DayMap"
```

---

### Task 8: Tavern 锁定配方 UI 处理

**Files:**
- Modify: `scripts/ui/TavernView.cs`

- [ ] **Step 1: 修改 BuildRecipeList 对锁定配方显示 "???"**

在 `BuildRecipeList` 方法中（第 229 行起），修改配方遍历逻辑。

当前 `foreach (var (key, recipe) in craft.Recipes)` 块中，在创建 row 之前添加锁定检查。将整个 row 构建逻辑包裹在条件判断中：

在 `foreach (var (key, recipe) in craft.Recipes)` 行之后，`var row = new HBoxContainer();` 行之前，没有一个好的插入点。改为在 arrow label 之后、row.AddChild(arrow) 之后添加处理：

当前第 269-275 行：
```csharp
                    row.AddChild(plus);
                }
            }

            var arrow = new Label { Text = $" = {recipe.Name}  {recipe.Price}金" };
            arrow.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            arrow.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(arrow);
```

将 `var arrow = ...` 这一块替换为：

```csharp
                    row.AddChild(plus);
                }
            }

            if (craft.IsRecipeUnlocked(key))
            {
                var arrow = new Label { Text = $" = {recipe.Name}  {recipe.Price}金" };
                arrow.AddThemeColorOverride("font_color", ThemeColors.TextLight);
                arrow.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(arrow);
            }
            else
            {
                var locked = new Label { Text = " = ??? (未解锁)" };
                locked.AddThemeColorOverride("font_color", ThemeColors.TextDim);
                locked.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(locked);
            }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/TavernView.cs
git commit -m "feat: show locked recipes as ??? in overlay menu"
```

---

### Task 9: 全量编译 + Godot 验证

- [ ] **Step 1: 最终编译**

Run: `dotnet build`
Expected: Build succeeded with 0 Error(s).

- [ ] **Step 2: Godot 运行验证**

通过 Godot 编辑器运行游戏，验证核心路径：

1. TitleScreen → 开始营业 → DayMap
2. 点击"商店"标签，确认看到 5 种材料行 + 4 种配方行
3. 购买材料（如买 3 个麦芽），确认金币减少、数量清零
4. 切回"采集"标签，正常分配体力
5. 出发 → Tavern → 确认 OverlayMenu 配方面板中锁定配方显示"???"
6. 尝试用正确材料合成锁定配方（如草药+麦芽），确认提示"配方未解锁"
7. 服务客人 → 打烊 → 下一天
8. Day 4 时确认商店是否变为"米拉的旅行商店"，材料价格打折
9. 赚够金币后解锁一个配方 → 确认按钮变"已拥有"
10. 解锁后在 Tavern 确认 OverlayMenu 中该配方正常显示、可合成

- [ ] **Step 3: 覆盖边缘情况**

- 金币为 0 时点击购买 → 购买失败，金币不变
- 对已解锁配方点"解锁" → 无操作（因为按钮已变"已拥有"）
- 开局客人只会点 5 种单品配方（未解锁合成配方前）
- DayMap 标签切换状态在每天重置为"采集"标签

---

## Self-Review

**1. Spec coverage:**
- [x] shop.json 创建 → Task 1
- [x] EconomySystem.SpendGold → Task 2
- [x] CraftSystem.UnlockedRecipes → Task 3
- [x] ShopSystem 价格查询 + 米拉判定 → Task 4
- [x] GameManager 购买方法 + 配方解锁检查 → Task 5
- [x] GuestSystem 动态配方过滤 → Task 6
- [x] DayMapView 商店 UI（标签切换/材料/配方）→ Task 7
- [x] OverlayMenu 锁定配方显示 → Task 8
- [x] 合成台锁定配方拒绝 → Task 5 Step 4
- [x] 米拉打折显示 → Task 7 Step 8
- [x] 米拉商店标题 → Task 7 Step 8
- [x] 初始 5 种单品解锁 → Task 3 Step 2

**2. Placeholder scan:** No TBD/TODO/incomplete sections. All code is concrete.

**3. Type consistency:**
- `ShopSystem.IsMiraShopToday(int currentDay, NarrativeManager narrative)` — matches call site in Task 7 where `gm.Shop.IsMiraShopToday(gm.Economy.CurrentDay, gm.Narrative)` is used. ✓
- `GuestSystem(Func<string[]> getAvailableOrders)` — matches `new GuestSystem(() => Craft.UnlockedRecipes.ToArray())` in Task 5. ✓
- `Craft.UnlockedRecipes` is `HashSet<string>` — `.ToArray()` returns `string[]` matching `Func<string[]>`. ✓
- `GameManager.BuyMaterial(string key, int quantity, bool miraActive)` — matches call `gm.BuyMaterial(matKey, qty, _isMiraShop)` in Task 7. ✓
- `GameManager.BuyRecipeUnlock(string key)` — matches call `gm.BuyRecipeUnlock(rKey)` in Task 7. ✓
