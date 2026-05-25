# 合成系统重制 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有"拖 2 材料→点按钮→匹配配方"替换为调和区 + 加工图 + 动态操作 + 香料后处理的沉浸式合成系统

**Architecture:** 数据驱动加工图 (items.json + operations.json) → CraftSystem 引擎 → MixingArea 调和区 UI + ProductPanel 侧栏 → CraftStation 编排所有 UI 组件 → GameManager 上菜流程。SeasoningSystem 独立模块，成品产出后可选附加。

**Tech Stack:** Godot 4.6 .NET/C#, JSON 数据文件

---

## 文件结构

| 文件 | 职责 | 操作 |
|------|------|------|
| `data/items.json` | 25 种物品定义（名称/颜色/价格） | 新建 |
| `data/operations.json` | 16 条加工边（物品→操作→产物） | 新建 |
| `data/seasonings.json` | 3 种香料定义 | 新建 |
| `scripts/systems/CraftSystem.cs` | 加工图引擎：查询操作/组合/产物 | 重写 |
| `scripts/systems/SeasoningSystem.cs` | 香料逻辑：加载/查询/消耗 | 新建 |
| `scripts/ui/MixingArea.cs` | 调和区容器：拖入/拖出/内容管理 | 新建 |
| `scripts/ui/ProductPanel.cs` | 侧栏：实时显示可能产物 | 新建 |
| `scripts/ui/SeasoningPanel.cs` | 香料选择面板 | 新建 |
| `scripts/ui/CraftStation.cs` | 编排器：调和区+产物面板+操作按钮+香料+上菜 | 重写 |
| `scripts/GameManager.cs` | 适配新 CraftStation 接口 | 修改 |
| `scenes/ui/Tavern.tscn` | 重构 CraftStation 节点树 | 修改 |
| `data/recipes.json` | (迁移后) | 删除 |

---

### Task 1: 创建数据文件

**Files:**
- Create: `data/items.json`
- Create: `data/operations.json`
- Create: `data/seasonings.json`

- [ ] **Step 1: 创建 items.json**

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

- [ ] **Step 2: 创建 operations.json**

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

- [ ] **Step 3: 创建 seasonings.json**

```json
{
  "spice":      { "name": "辣",   "tag": "spicy",  "color": [0.9, 0.2, 0.1] },
  "herb_spice": { "name": "香草", "tag": "herbal",  "color": [0.2, 0.8, 0.3] },
  "salt":       { "name": "盐",   "tag": "salty",   "color": [0.9, 0.9, 0.9] }
}
```

- [ ] **Step 4: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add data/items.json data/operations.json data/seasonings.json
git commit -m "feat: add item, operation, and seasoning data files for craft redesign"
```

---

### Task 2: 重写 CraftSystem（加工图引擎）

**Files:**
- Rewrite: `scripts/systems/CraftSystem.cs`

- [ ] **Step 1: 编写新 CraftSystem**

```csharp
using Godot;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

public class ItemData
{
    public string Name { get; set; }
    public float[] Color { get; set; }
    public int Price { get; set; }
}

public class CombineRule
{
    public string A { get; set; }
    public string B { get; set; }
    public string Result { get; set; }
}

public class CombineFile
{
    public CombineRule[] Combines { get; set; }
}

public class CraftSystem
{
    // 物品字典
    public Dictionary<string, ItemData> Items { get; private set; } = new();

    // 加工图: item_key → { operation → result_key }
    private Dictionary<string, Dictionary<string, string>> _ops = new();

    // 组合规则: 按 (a,b) 排序存储
    private Dictionary<(string, string), string> _combine = new();

    // 配方解锁（兼容旧 ShopSystem）
    public HashSet<string> UnlockedRecipes { get; private set; } = new();
    public bool IsRecipeUnlocked(string key) => UnlockedRecipes.Contains(key);
    public void UnlockRecipe(string key) => UnlockedRecipes.Add(key);

    // ── 加载 ──

    public void LoadData()
    {
        LoadItems();
        LoadOperations();
        LoadCombines();
        GD.Print($"[Craft] 加载 {Items.Count} 种物品, {_ops.Count} 个加工节点, {_combine.Count} 条组合规则");
    }

    private void LoadItems()
    {
        using var file = FileAccess.Open("res://data/items.json", FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        Items = JsonSerializer.Deserialize<Dictionary<string, ItemData>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
    }

    private void LoadOperations()
    {
        using var file = FileAccess.Open("res://data/operations.json", FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        var raw = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        _ops = raw ?? new();
    }

    private void LoadCombines()
    {
        // 组合规则以硬编码方式加载（数据量小，不放单独文件）
        foreach (var (a, b, r) in new[] {
            ("dough", "meat_raw", "dough_meat"),
            ("ale", "herb", "ale_herb"),
            ("grape", "herb", "grape_herb"),
            ("meat_raw", "ale", "meat_stew_raw"),
        })
        {
            _combine[(a, b)] = r;
            _combine[(b, a)] = r; // 对称
        }
    }

    // ── 查询 ──

    public ItemData GetItem(string key) =>
        Items.TryGetValue(key, out var item) ? item : null;

    /// 返回某物品的所有可用操作及产物
    public Dictionary<string, string> GetOperations(string key) =>
        _ops.TryGetValue(key, out var ops) ? ops : new();

    /// 是否有可用操作（有操作 = 可继续加工 = 非成品/非死胡同）
    public bool HasOperations(string key) => _ops.ContainsKey(key);

    /// price > 0 视为可售成品
    public bool IsProduct(string key) =>
        Items.TryGetValue(key, out var item) && item.Price > 0;

    /// 检查两物品是否可组合
    public string GetCombineResult(string a, string b)
    {
        if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return null;
        return _combine.TryGetValue((a, b), out var result) ? result : null;
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/CraftSystem.cs
git commit -m "feat: rewrite CraftSystem as processing graph engine"
```

---

### Task 3: 创建 MixingArea（调和区 UI 组件）

**Files:**
- Create: `scripts/ui/MixingArea.cs`

`MixingArea` 是一个 `Control`，调和区的可视化容器。内部维护物品列表，支持拖入/拖出，发出内容变化信号。

- [ ] **Step 1: 编写 MixingArea**

```csharp
using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class MixingArea : Control
{
    // 内部物品列表
    private readonly List<string> _items = new();
    public IReadOnlyList<string> Contents => _items;

    // 信号：内容变化（物品增减/替换）
    public event Action ContentsChanged;

    // 信号：检测到异类物品 → 询问是否混合
    public event Action<string, string> CombineQuery;

    private GameManager _gm;

    // ── 物品渲染相关引用（在 _Ready 中创建） ──
    private readonly List<ColorRect> _itemRects = new();

    private static readonly Dictionary<string, string> _matNames = new()
    {
        ["flour"]="面粉",["dough"]="面团",["bread"]="面包",["bread_burnt"]="焦面包",
        ["meat_raw"]="生肉",["meat_cooked"]="烤肉",["meat_burnt"]="焦肉",
        ["ale"]="麦芽",["ale_roasted"]="烤麦芽",["ale_beer"]="麦芽酒",["ale_burnt"]="焦麦芽",
        ["grape"]="葡萄",["grape_juice"]="葡萄汁",["wine"]="葡萄酒",
        ["herb"]="草药",["herb_tea"]="草药茶",
        ["dough_meat"]="肉夹生面团",["meat_sand"]="肉夹面包",
        ["ale_herb"]="草药麦芽",["herbal_ale"]="草药麦酒",
        ["grape_herb"]="香料葡萄",["spiced_wine"]="香料红酒",
        ["meat_stew_raw"]="生肉汤",["meat_stew"]="肉汤",
        ["sleep_powder"]="沉睡花粉"
    };

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        MouseFilter = MouseFilterEnum.Stop; // 调和区自己接收拖放
    }

    public void AddItem(string key)
    {
        if (string.IsNullOrEmpty(key)) return;

        // 检查是否已有异类物品 → 发出混合询问
        var distinct = _items.Where(i => i != key).Distinct().ToList();
        if (distinct.Count > 0 && !_items.Contains(key))
        {
            CombineQuery?.Invoke(key, distinct[0]);
            return; // 等用户确认
        }

        _items.Add(key);
        RefreshDisplay();
    }

    /// 强制添加，跳过混合询问（用于"否"路径和内部操作）
    public void ForceAddItem(string key)
    {
        if (string.IsNullOrEmpty(key)) return;
        _items.Add(key);
        RefreshDisplay();
    }

    public void RemoveItem(string key)
    {
        var idx = _items.IndexOf(key);
        if (idx >= 0)
        {
            _items.RemoveAt(idx);
            RefreshDisplay();
        }
    }

    public void Clear()
    {
        _items.Clear();
        RefreshDisplay();
    }

    /// 消耗所有材料并替换为新物品（用于组合/操作后）
    public void ConsumeAndReplace(string newKey)
    {
        _items.Clear();
        _items.Add(newKey);
        RefreshDisplay();
    }

    /// 消耗指定材料列表并替换为新物品（ProductPanel 点击产物时使用）
    public void ConsumeAndReplace(string[] consumed, string newKey)
    {
        foreach (var c in consumed)
            _items.Remove(c);
        _items.Add(newKey);
        RefreshDisplay();
    }

    private void RefreshDisplay()
    {
        ContentsChanged?.Invoke();
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_items.Count == 0) return;

        var rect = GetRect();
        var margin = 8f;
        float itemW = (rect.Size.X - margin * (_items.Count + 1)) / Math.Max(1, _items.Count);
        itemW = Math.Min(itemW, 100f);

        for (int i = 0; i < _items.Count; i++)
        {
            var item = _gm.Craft.GetItem(_items[i]);
            var c = item != null ? new Color(item.Color[0], item.Color[1], item.Color[2]) : Colors.Gray;
            var x = margin + i * (itemW + margin);
            var y = rect.Size.Y * 0.25f;
            var h = rect.Size.Y * 0.5f;

            DrawRect(new Rect2(x, y, itemW, h), c);
            DrawRect(new Rect2(x, y, itemW, h), Colors.White, false);

            var name = item?.Name ?? _items[i];
            DrawString(ThemeDB.FallbackFont, new Vector2(x + 2, y + 14), name,
                HorizontalAlignment.Left, itemW - 4, 14);
        }
    }
}
```

- [ ] **Step 2: 验证构建**

```bash
dotnet build
```
Expected: 0 errors. `_Draw` 中的 `DrawString` 需要 `ThemeDB.FallbackFont`（Godot 4.x API）。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/MixingArea.cs
git commit -m "feat: add MixingArea — mixing container with item rendering"
```

---

### Task 4: 创建 ProductPanel（产物侧栏）

**Files:**
- Create: `scripts/ui/ProductPanel.cs`

- [ ] **Step 1: 编写 ProductPanel**

```csharp
using Godot;
using System;
using System.Collections.Generic;

public partial class ProductPanel : Control
{
    private VBoxContainer _list;
    private GameManager _gm;
    private MixingArea _mixingArea;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _mixingArea = GetNode<MixingArea>("../MixingArea");
        _list = new VBoxContainer();
        AddChild(_list);

        _mixingArea.ContentsChanged += Refresh;
    }

    public override void _ExitTree()
    {
        if (_mixingArea != null)
            _mixingArea.ContentsChanged -= Refresh;
    }

    private void Refresh()
    {
        // 清空旧列表
        foreach (var child in _list.GetChildren())
            child.QueueFree();

        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;

        // 收集所有可能产物
        var products = new HashSet<string>();

        // 各物品自己的操作产物
        foreach (var key in contents)
        {
            foreach (var (op, result) in _gm.Craft.GetOperations(key))
                products.Add(result);
        }

        // 组合产物（如果有多种不同物品）
        var distinct = new HashSet<string>(contents);
        if (distinct.Count >= 2)
        {
            var arr = new List<string>(distinct);
            for (int i = 0; i < arr.Count; i++)
                for (int j = i + 1; j < arr.Count; j++)
                {
                    var combined = _gm.Craft.GetCombineResult(arr[i], arr[j]);
                    if (combined != null) products.Add(combined);
                }
        }

        foreach (var key in products)
        {
            var item = _gm.Craft.GetItem(key);
            if (item == null) continue;
            var btn = new Button
            {
                Text = $"{item.Name}",
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
            };
            ThemeColors.StyleSmallButton(btn, 12);
            btn.Pressed += () => OnProductSelected(key);
            _list.AddChild(btn);
        }
    }

    private void OnProductSelected(string key)
    {
        // 找到生产中消耗的材料
        var contents = new List<string>(_mixingArea.Contents);
        if (contents.Count == 1 && contents[0] == key) return; // 是自己，跳过

        // 尝试单物品操作
        foreach (var c in contents)
        {
            var ops = _gm.Craft.GetOperations(c);
            if (ops.ContainsValue(key))
            {
                _mixingArea.ConsumeAndReplace(new[] { c }, key);
                return;
            }
        }

        // 尝试组合
        if (contents.Count >= 2)
        {
            for (int i = 0; i < contents.Count; i++)
                for (int j = i + 1; j < contents.Count; j++)
                {
                    if (_gm.Craft.GetCombineResult(contents[i], contents[j]) == key)
                    {
                        _mixingArea.ConsumeAndReplace(
                            new[] { contents[i], contents[j] }, key);
                        return;
                    }
                }
        }
    }

    public event Action<string> ProductSelected;
}
```

- [ ] **Step 2: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/ProductPanel.cs
git commit -m "feat: add ProductPanel — side panel showing possible products"
```

---

### Task 5: 创建 SeasoningSystem

**Files:**
- Create: `scripts/systems/SeasoningSystem.cs`

- [ ] **Step 1: 编写 SeasoningSystem**

```csharp
using Godot;
using System.Collections.Generic;
using System.Text.Json;

public class SeasoningData
{
    public string Name { get; set; }
    public string Tag { get; set; }
    public float[] Color { get; set; }
}

public class SeasoningSystem
{
    public Dictionary<string, SeasoningData> Seasonings { get; private set; } = new();

    public void Load()
    {
        using var file = FileAccess.Open("res://data/seasonings.json", FileAccess.ModeFlags.Read);
        if (file == null) return;
        var json = file.GetAsText();
        Seasonings = JsonSerializer.Deserialize<Dictionary<string, SeasoningData>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? new();
        GD.Print($"[Seasoning] 加载 {Seasonings.Count} 种香料");
    }

    public SeasoningData GetSeasoning(string key) =>
        Seasonings.TryGetValue(key, out var s) ? s : null;
}
```

- [ ] **Step 2: 在 GameManager 中初始化**

```csharp
// 在 GameManager._Ready() 中，Shop.LoadConfig() 之后添加：
Seasoning.Load();
```

需要在 GameManager 类中添加属性:
```csharp
public SeasoningSystem Seasoning { get; private set; } = new();
```

- [ ] **Step 3: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add scripts/systems/SeasoningSystem.cs scripts/GameManager.cs
git commit -m "feat: add SeasoningSystem with config loading"
```

---

### Task 6: 创建 SeasoningPanel

**Files:**
- Create: `scripts/ui/SeasoningPanel.cs`

- [ ] **Step 1: 编写 SeasoningPanel**

```csharp
using Godot;
using System;

public partial class SeasoningPanel : Control
{
    private HBoxContainer _btnRow;
    private GameManager _gm;
    private string _currentItemKey;

    public event Action<string> SeasoningApplied; // seasoning key
    public event Action SeasoningSkipped;         // 不加香料

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _btnRow = new HBoxContainer();
        AddChild(_btnRow);
        Visible = false;
    }

    /// 对某个成品显示香料选项
    public void ShowFor(string itemKey)
    {
        if (!_gm.Craft.IsProduct(itemKey)) { Visible = false; return; }

        _currentItemKey = itemKey;
        Visible = true;

        // 清旧按钮
        foreach (var child in _btnRow.GetChildren()) child.QueueFree();

        foreach (var (key, data) in _gm.Seasoning.Seasonings)
        {
            var btn = new Button { Text = data.Name };
            ThemeColors.StyleSmallButton(btn, 12);
            btn.Pressed += () => {
                SeasoningApplied?.Invoke(key);
                Hide();
            };
            _btnRow.AddChild(btn);
        }

        var skipBtn = new Button { Text = "不加" };
        ThemeColors.StyleSmallButton(skipBtn, 12);
        skipBtn.Pressed += () => { SeasoningSkipped?.Invoke(); Hide(); };
        _btnRow.AddChild(skipBtn);
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/SeasoningPanel.cs
git commit -m "feat: add SeasoningPanel for optional seasoning selection"
```

---

### Task 7: 重写 CraftStation（编排器）

**Files:**
- Rewrite: `scripts/ui/CraftStation.cs`

这是最大的改动。CraftStation 作为编排器，托管 MixingArea、ProductPanel、SeasoningPanel、操作按钮和 Serve/Clear 按钮。保留快捷栏同步和拖拽逻辑，但移除旧的双槽位逻辑。

- [ ] **Step 1: 编写新 CraftStation**

```csharp
using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class CraftStation : Control
{
    // ── 子组件引用 ──
    private MixingArea _mixingArea;
    private ProductPanel _productPanel;
    private SeasoningPanel _seasoningPanel;
    private Control _operationButtons; // HBoxContainer holding dynamic op buttons
    private Button _serveBtn;
    private Button _clearBtn;
    private ColorRect _resultSlot;
    private Label _resultLabel;

    // ── 内联询问条 ──
    private HBoxContainer _combineQueryBar;
    private Label _combineQueryLabel;
    private Button _combineYesBtn;
    private Button _combineNoBtn;
    private string _pendingA, _pendingB;

    // ── 快捷栏拖拽 ──
    private bool _dragging;
    private string _dragMaterial;
    private ColorRect _dragPanel;
    private Control _overlayMenu;
    private ColorRect _dialogueOverlay;

    // ── 快捷栏缓存 ──
    private string[] BarMaterials = new string[10];
    private int[] BarCounts = new int[10];
    private ColorRect[] _shortcutSlots = new ColorRect[10];
    private Label[] _shortcutLabels = new Label[10];

    private GameManager _gm;

    // ── 事件 ──
    public event Action<string, string> ServeRequested; // (itemKey, seasoningTag or null)
    public event Action ClearRequested;
    public event Action<string> GestureCompleted; // 保留兼容

    // ── 操作加热进度 ──
    private bool _heating;
    private double _heatProgress;
    private const double HeatTime = 1.5;
    private string _heatTargetOp;
    private Button _heatBtnRef;

    // ── 搅拌进度 ──
    private bool _stirring;
    private int _stirCircles;
    private const int StirTarget = 3;
    private Vector2 _stirLastMouse;
    private double _stirTotalAngle;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");

        // 查找子组件
        _mixingArea = GetNode<MixingArea>("MixingArea");
        _productPanel = GetNode<ProductPanel>("ProductPanel");
        _seasoningPanel = GetNode<SeasoningPanel>("SeasoningPanel");
        _operationButtons = GetNode<Control>("OperationButtons");
        _serveBtn = GetNode<Button>("ServeBtn");
        _clearBtn = GetNode<Button>("ClearBtn");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _resultLabel = GetNode<Label>("ResultSlot/Label");
        _overlayMenu = GetNodeOrNull<Control>("../OverlayMenu");
        _dialogueOverlay = GetNodeOrNull<ColorRect>("../DialogueOverlay");

        // 内联询问条
        _combineQueryBar = GetNode<HBoxContainer>("CombineQueryBar");
        _combineQueryLabel = GetNode<Label>("CombineQueryBar/Label");
        _combineYesBtn = GetNode<Button>("CombineQueryBar/YesBtn");
        _combineNoBtn = GetNode<Button>("CombineQueryBar/NoBtn");
        _combineQueryBar.Visible = false;

        // ── 调和区事件 ──
        _mixingArea.CombineQuery += (a, b) => ShowCombineQuery(a, b);
        _mixingArea.ContentsChanged += RefreshOperationButtons;
        _mixingArea.ContentsChanged += CheckResultReady;

        // ── 询问条按钮 ──
        _combineYesBtn.Pressed += () => {
            _combineQueryBar.Visible = false;
            // "是" → 执行组合，直接放入结果
            var result = _gm.Craft.GetCombineResult(_pendingA, _pendingB);
            if (result != null)
                _mixingArea.ForceAddItem(result);
            else
            {
                _mixingArea.ForceAddItem(_pendingA);
                _mixingArea.ForceAddItem(_pendingB);
            }
        };
        _combineNoBtn.Pressed += () => {
            _combineQueryBar.Visible = false;
            _mixingArea.ForceAddItem(_pendingA);
            _mixingArea.ForceAddItem(_pendingB);
        };

        // ── 操作按钮 ──
        _serveBtn.Pressed += () => {
            var resultKey = _resultLabel.Text;
            // 从结果槽取成品 key
            if (string.IsNullOrEmpty(resultKey) || resultKey == "空") return;
            // resultKey is the item key in result slot
            var serveKey = _resultSlot.GetMeta("item_key", "").AsString();
            if (string.IsNullOrEmpty(serveKey)) return;
            var seasoning = _resultSlot.GetMeta("seasoning", "").AsString();
            if (string.IsNullOrEmpty(seasoning)) seasoning = null;
            ServeRequested?.Invoke(serveKey, seasoning);
        };

        _clearBtn.Pressed += () => {
            // 把调和区内容退回库存
            foreach (var item in _mixingArea.Contents)
                AddToInventory(item);
            _mixingArea.Clear();
            ClearResultSlot();
            _seasoningPanel.Visible = false;
            ClearRequested?.Invoke();
        };

        // ── 香料事件 ──
        _seasoningPanel.SeasoningApplied += (seasoning) => {
            _resultSlot.SetMeta("seasoning", seasoning);
        };
        _seasoningPanel.SeasoningSkipped += () => { };

        // ── 快捷栏初始化 ──
        InitShortcutBar();
        InitDragPanel();

        SyncFromInventory();
        _gm.InventoryChanged += SyncFromInventory;
    }

    public override void _ExitTree()
    {
        if (_gm != null) _gm.InventoryChanged -= SyncFromInventory;
    }

    // ── 询问条 ──
    private void ShowCombineQuery(string a, string b)
    {
        _pendingA = a;
        _pendingB = b;
        var itemA = _gm.Craft.GetItem(a);
        var itemB = _gm.Craft.GetItem(b);
        _combineQueryLabel.Text = $"混合 {itemA?.Name ?? a} 和 {itemB?.Name ?? b}？";
        _combineQueryBar.Visible = true;
    }

    // ── 操作按钮刷新 ──
    private void RefreshOperationButtons()
    {
        // 清空
        foreach (var child in _operationButtons.GetChildren())
            child.QueueFree();

        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;

        // 获取所有可用的操作（取第一个物品的操作）
        // 如果有多个同类物品，操作相同
        var firstKey = contents[0];
        var ops = _gm.Craft.GetOperations(firstKey);

        // 如果没有操作但有异类物品，不出操作按钮（等混合确认）
        if (ops.Count == 0) return;

        foreach (var (op, result) in ops)
        {
            var btn = CreateOperationButton(op, result);
            _operationButtons.AddChild(btn);
        }
    }

    private Button CreateOperationButton(string op, string resultKey)
    {
        var label = op switch { "heat" => "加热", "stir" => "搅拌", "shake" => "摇晃", "pour" => "倒出", _ => op };
        var btn = new Button { Text = label };
        ThemeColors.StyleSmallButton(btn, 12);

        switch (op)
        {
            case "heat":
                btn.ButtonDown += () => StartHeat(btn, resultKey);
                break;
            case "stir":
                btn.ButtonDown += () => StartStir(btn, resultKey);
                break;
            case "shake":
                btn.Pressed += () => ExecuteOperation(resultKey); // 点击完成
                break;
            default:
                btn.Pressed += () => ExecuteOperation(resultKey);
                break;
        }
        return btn;
    }

    // ── 加热 ──
    private void StartHeat(Button btn, string resultKey)
    {
        _heating = true;
        _heatProgress = 0;
        _heatTargetOp = resultKey;
        _heatBtnRef = btn;
        btn.Text = "加热中...";
        btn.Disabled = true;
    }

    // ── 搅拌 ──
    private void StartStir(Button btn, string resultKey)
    {
        _stirring = true;
        _stirCircles = 0;
        _stirTotalAngle = 0;
        _stirLastMouse = GetViewport().GetMousePosition();
        _heatTargetOp = resultKey;
        _heatBtnRef = btn;
        btn.Text = "搅拌中... (转圈)";
    }

    private void ExecuteOperation(string resultKey)
    {
        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;
        // 消耗第一个材料，替换为结果
        _mixingArea.ConsumeAndReplace(new[] { contents[0] }, resultKey);
        GestureCompleted?.Invoke("done");
    }

    // ── 检查是否产出成品 → 放入结果槽 ──
    private void CheckResultReady()
    {
        var contents = _mixingArea.Contents;
        if (contents.Count == 1)
        {
            var key = contents[0];
            if (!_gm.Craft.HasOperations(key))
            {
                // 无操作可用 → 这是成品或失败品 → 移入结果槽
                MoveToResultSlot(key);
                _mixingArea.Clear();
                return;
            }
        }
    }

    private void MoveToResultSlot(string key)
    {
        var item = _gm.Craft.GetItem(key);
        if (item != null)
        {
            _resultSlot.Color = new Color(item.Color[0], item.Color[1], item.Color[2]);
            _resultLabel.Text = item.Name;
        }
        else
        {
            _resultLabel.Text = key;
        }
        _resultSlot.SetMeta("item_key", key);
        _resultSlot.SetMeta("seasoning", "");

        // 成品显示香料面板
        _seasoningPanel.ShowFor(key);
    }

    private void ClearResultSlot()
    {
        _resultLabel.Text = "";
        _resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);
        _resultSlot.RemoveMeta("item_key");
        _resultSlot.RemoveMeta("seasoning");
        _seasoningPanel.Visible = false;
    }

    // ── _Process ──
    public override void _Process(double dt)
    {
        if (_overlayMenu?.Visible == true) return;

        if (_dragging)
            _dragPanel.Position = GetViewport().GetMousePosition() - new Vector2(32, 32);

        if (_heating)
        {
            _heatProgress += dt;
            float ratio = (float)(_heatProgress / HeatTime);
            if (_heatProgress >= HeatTime)
            {
                _heating = false;
                _heatBtnRef.Text = "加热 ✓";
                GestureCompleted?.Invoke("heat");
                ExecuteOperation(_heatTargetOp);
            }
            else
            {
                _heatBtnRef.Text = $"加热中 {ratio * 100:F0}%";
            }
        }

        if (_stirring)
        {
            var mouse = GetViewport().GetMousePosition();
            var prev = _stirLastMouse - _heatBtnRef.GlobalPosition;
            var cur = mouse - _heatBtnRef.GlobalPosition;
            // 计算绕按钮中心的旋转角度
            var anglePrev = Math.Atan2(prev.Y, prev.X);
            var angleCur = Math.Atan2(cur.Y, cur.X);
            var delta = angleCur - anglePrev;
            if (Math.Abs(delta) > 0.01) _stirTotalAngle += delta;
            _stirLastMouse = mouse;

            _stirCircles = (int)(Math.Abs(_stirTotalAngle) / (Math.PI * 2));
            _heatBtnRef.Text = $"搅拌中... {_stirCircles}/{StirTarget}";
            if (_stirCircles >= StirTarget)
            {
                _stirring = false;
                _heatBtnRef.Text = "搅拌 ✓";
                GestureCompleted?.Invoke("stir");
                ExecuteOperation(_heatTargetOp);
            }
        }
    }

    // ── 拖拽（保留快捷栏 ↔ 调和区交互） ──
    public override void _Input(InputEvent e)
    {
        if (_overlayMenu?.Visible == true) return;
        if (_dialogueOverlay?.Visible == true) return;

        if (e is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed && !_dragging) TryPickUp(mb.Position);
            else if (!mb.Pressed && _dragging) TryDrop(mb.Position);
        }
    }

    private void TryPickUp(Vector2 pos) { /* 从快捷栏/结果槽拾取...保持现有逻辑 */ }
    private void TryDrop(Vector2 pos)
    {
        // 如果拖到调和区 → 加进去
        if (HitTest(_mixingArea, pos) && !string.IsNullOrEmpty(_dragMaterial))
        {
            _mixingArea.AddItem(_dragMaterial);
            EndDrag();
            return;
        }
        // 否则退回库存
        ReturnDrag();
        EndDrag();
    }

    private void StartDrag(Vector2 pos, string mat) { /* 同现有逻辑 */ }
    private void EndDrag() { /* 同现有逻辑 */ }
    private void ReturnDrag() { AddToInventory(_dragMaterial); }

    // ── 快捷栏同步（同现有逻辑） ──
    private void SyncFromInventory() { /* 同现有逻辑 */ }
    private void InitShortcutBar() { /* 同现有逻辑 */ }
    private void InitDragPanel() { /* 同现有逻辑 */ }
    private void AddToInventory(string key, int amount = 1) { /* 同现有逻辑 */ }
    private void RemoveFromInventory(string key, int amount = 1) { /* 同现有逻辑 */ }
    private void RefreshShortcut(int i) { /* 同现有逻辑 */ }

    private static bool HitTest(Control c, Vector2 p)
    {
        var r = c.GetGlobalRect();
        return p.X >= r.Position.X && p.X <= r.End.X && p.Y >= r.Position.Y && p.Y <= r.End.Y;
    }
}
```

> **注意:** Step 1 中的拖拽/快捷栏/库存同步方法（TryPickUp, TryDrop, StartDrag, EndDrag, SyncFromInventory 等）需要从现有的 `CraftStation.cs` 中**复制**完整实现。上面用 `/* 同现有逻辑 */` 标注的部分即复制现有代码，不在此处给出完整展开以避免计划文件过长。

- [ ] **Step 2: 构建验证**

```bash
dotnet build
```
Expected: 0 errors（可能需要处理旧 GestureCompleted 的 switch 引用）

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/CraftStation.cs
git commit -m "feat: rewrite CraftStation as orchestrator with MixingArea+ProductPanel+SeasoningPanel"
```

---

### Task 8: 修改 GameManager 适配新接口

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 更新 RegisterView 中的 CraftStation 连接**

`GameManager.RegisterView` 方法中，旧的 `craftStation.CraftRequested`、`craftStation.GestureCompleted`、`craftStation.ServeRequested`、`craftStation.ClearRequested` 事件处理需要适配新接口。

核心变更：
1. 删除 `CraftRequested` 事件处理（配方匹配现在由 Harmony 区 + 操作按钮完成）
2. 删除 `GestureCompleted` switch 逻辑（手势状态由 CraftStation 自己管理）
3. `ServeRequested` 签名改为 `(string itemKey, string seasoningTag)`
4. `ClearRequested` 不变

修改 `RegisterView` 方法中约 120 行代码：

```csharp
// 删除整段旧代码（从 craftStation.GestureCompleted += ... 到 craftStation.ClearRequested += ...）
// 替换为：

craftStation.ServeRequested += (itemKey, seasoningTag) => {
    if (!Guests.HasGuest || string.IsNullOrEmpty(itemKey)) return;

    var isImportant = Guests.CurrentGuest.HasDialogue;
    var npcId = Guests.CurrentGuest.NpcId;

    // 获取物品数据
    var item = Craft.GetItem(itemKey);
    var itemPrice = item?.Price ?? 0;

    if (itemKey == Guests.CurrentGuest.OrderKey)
    {
        Economy.AddGold(itemPrice);
        Economy.AddReputation(2);
        Guests.RecordOrderSuccess();
        _tavernView.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
        if (isImportant) Narrative.SetVar("serve_result", "success");
    }
    else
    {
        // 上错菜但价格>0 说明是正常成品但客人不要 → 判定失败
        // 价格=0 说明是失败品 → 同样判定失败（性格系统未来覆盖）
        Guests.RecordOrderFailed();
        _tavernView.ShowMessage(
            itemPrice > 0 ? $"错了！{Guests.CurrentGuest.Name} 要的不是这个！" :
            $"这看起来不太对劲……{Guests.CurrentGuest.Name} 很失望。",
            Colors.Red);
        if (isImportant) Narrative.SetVar("serve_result", "fail");
    }

    // 如果有香料标签，暂存在 Narrative 变量中供对话使用
    if (!string.IsNullOrEmpty(seasoningTag))
        Narrative.SetVar("seasoning_used", seasoningTag);

    Guests.RecordGuestServed();
    // CraftStation 自行管理清空; 不在此处调用 Craft.ClearCraftSlots()

    if (isImportant && !string.IsNullOrEmpty(npcId))
    {
        var postPath = $"res://dialogue/{npcId}_day{Economy.CurrentDay}.post.dialogue";
        if (FileAccess.FileExists(postPath))
        {
            _dialoguePhase = "post";
            _tavernView.SetDialogueMode(true);
            CallDeferred(nameof(StartDialogueDeferred), postPath);
        }
        else
        {
            Guests.ClearGuest();
        }
    }
    else
    {
        Guests.ClearGuest();
    }
};

craftStation.ClearRequested += () => {
    // CraftStation 内部已处理材料退回库存，无需额外操作
};
```

- [ ] **Step 2: 确认 _Ready 中 Craft.LoadData 替换旧的 LoadRecipes**

```csharp
// GameManager._Ready() 中，将
Craft.LoadRecipes();
// 替换为
Craft.LoadData();
```

- [ ] **Step 3: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: adapt GameManager to new CraftStation serve/clear interface"
```

---

### Task 9: 重构 Tavern.tscn 的 CraftStation 节点树

**Files:**
- Modify: `scenes/ui/Tavern.tscn`

操作：在 Godot 编辑器中手动操作（或通过 MCP），调整 CraftStation 节点的子节点结构。

当前结构（近似）：
```
CraftStation (Control)
├── Slot1 (ColorRect)
│   └── Label
├── Slot2 (ColorRect)
│   └── Label
├── ResultSlot (ColorRect)
│   └── Label
├── HeatBtn (Button)
├── ShakeBtn (Button)
├── StirBtn (Button)
├── CraftBtn (Button)
├── ServeBtn (Button)
├── ClearBtn (Button)
└── ShortcutBar (Control)
```

新结构：
```
CraftStation (Control)
├── MixingArea (Control)          ← 调和区（新的拖放目标）
├── ProductPanel (Control)        ← 侧栏产物列表（VBoxContainer）
│
├── CombineQueryBar (HBoxContainer) ← 混合询问条（默认隐藏）
│   ├── Label
│   ├── YesBtn (Button)
│   └── NoBtn (Button)
│
├── OperationButtons (HBoxContainer) ← 动态操作按钮区（默认空）
│
├── ResultSlot (ColorRect)        ← 成品槽
│   └── Label
├── SeasoningPanel (Control)     ← 香料面板（默认隐藏）
├── ServeBtn (Button)
├── ClearBtn (Button)
│
└── ShortcutBar (Control)         ← 保留
    ├── Slot0..9 (ColorRect)
    └── ...
```

- [ ] **Step 1: 通过 MCP 重构 CraftStation 节点树**

使用 Godot MCP 工具：

1. 删除旧节点：Slot1, Slot2, HeatBtn, ShakeBtn, StirBtn, CraftBtn
2. 添加新节点：MixingArea, ProductPanel, CombineQueryBar, OperationButtons, SeasoningPanel
3. 在 MixingArea 和 SeasoningPanel 上挂载对应脚本
4. 调整按钮位置（ServeBtn 移到 ResultSlot 旁边，ClearBtn 留在下方）

- [ ] **Step 2: 构建验证**

```bash
dotnet build
```
Expected: 0 errors

- [ ] **Step 3: 在编辑器中运行验证**

启动 Godot 编辑器 → 运行 TitleScreen → 开始营业 → 确认：
- 调和区显示为空（无按钮）
- 快捷键拖材料到调和区有效
- 操作按钮动态出现
- 成品产出后香料面板出现

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/Tavern.tscn
git commit -m "feat: restructure CraftStation node tree for mixing area design"
```

---

### Task 10: 清理与最终验证

**Files:**
- Delete: `data/recipes.json`

- [ ] **Step 1: 删除旧数据文件**

```bash
git rm data/recipes.json
```

- [ ] **Step 2: 最终构建**

```bash
dotnet build
```

- [ ] **Step 3: 确认所有引用已清除**

```bash
grep -r "recipes.json" --include="*.cs" .
```
Expected: 无结果

```
grep -r "Slot1\|Slot2\|CraftRequested\|AllGesturesDone\|ResetGestures\|ClearCraftSlots\|GestureDragDone\|GestureShakeDone\|GestureHeatDone\|GestureStirDone" --include="*.cs" .
```
Expected: 无结果（或仅在注释中）

- [ ] **Step 4: Commit**

```bash
git add -u data/recipes.json
git commit -m "refactor: remove deprecated recipes.json after craft system rewrite"
```

---

## 验证清单（所有 Task 完成后）

- [ ] `dotnet build` 0 errors
- [ ] TitleScreen → 开始营业 → Tavern 场景正常加载
- [ ] 调和区空时无操作按钮
- [ ] 快捷栏拖材料到调和区有效
- [ ] 同材料可堆叠，异材料弹出询问条
- [ ] 加热按钮按住 1.5s 完成
- [ ] 搅拌按钮转圈 3 圈完成
- [ ] 产物侧栏正确显示
- [ ] 成品产出后香料面板出现
- [ ] 上菜逻辑正常（匹配/不匹配/失败品均可上菜）
- [ ] 快捷栏库存同步正确
- [ ] E 键菜单打开时拖拽锁定
- [ ] 打烊结算正常
- [ ] 旧配方引用全部清除
