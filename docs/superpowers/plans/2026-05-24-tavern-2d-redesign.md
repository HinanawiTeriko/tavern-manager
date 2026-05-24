# 地下城酒馆 2D 重设计·实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 MVP 重制为 VA-11 Hall-A 式吧台视角 2D 经营游戏，含 NPC 网状叙事、手势合成、昼夜双循环。

**Architecture:** 保留 GameManager 作为 Autoload 协调器，拆分出 5 个子系统（DayCycleSystem, NarrativeManager, CraftSystem, GuestSystem, EconomySystem）。配方/采集点数据迁移到 JSON 文件。4 个场景（标题、白天采集、晚上酒馆、结局）。

**Tech Stack:** Godot 4.6 .NET (C#), GL Compatibility 渲染, Dialogue Manager 插件

**Estimated tasks:** 25 | **Duration:** ~4 weeks

---

### Task 1: 创建配方 JSON 数据文件

**Files:**
- Create: `data/recipes.json`

将硬编码在 GameManager.cs 的配方字典提取到独立数据文件，方便后续扩展。

- [ ] **Step 1: 创建 data/ 目录和 recipes.json**

```bash
mkdir -p data
```

- [ ] **Step 2: 写入 recipes.json**

```json
{
  "recipes": [
    { "key": "Ale", "name": "麦芽酒", "materials": ["Ale"], "price": 5, "gestures": ["drag"], "icon": "" },
    { "key": "Wine", "name": "葡萄酒", "materials": ["Wine"], "price": 5, "gestures": ["drag"], "icon": "" },
    { "key": "Bread", "name": "面包", "materials": ["Bread"], "price": 3, "gestures": ["drag", "heat"], "icon": "" },
    { "key": "Meat", "name": "烤肉", "materials": ["Meat"], "price": 4, "gestures": ["drag", "heat"], "icon": "" },
    { "key": "Herb Tea", "name": "草药茶", "materials": ["Herb"], "price": 3, "gestures": ["drag", "heat"], "icon": "" },
    { "key": "Herbal Ale", "name": "草药麦酒", "materials": ["Ale", "Herb"], "price": 10, "gestures": ["drag", "shake"], "icon": "" },
    { "key": "Meat Stew", "name": "肉汤", "materials": ["Meat", "Ale"], "price": 12, "gestures": ["drag", "stir", "heat"], "icon": "" },
    { "key": "MeatSand", "name": "肉夹面包", "materials": ["Bread", "Meat"], "price": 9, "gestures": ["drag", "heat"], "icon": "" },
    { "key": "SpicedWine", "name": "香料红酒", "materials": ["Wine", "Herb"], "price": 11, "gestures": ["drag", "shake"], "icon": "" }
  ],
  "materials": {
    "Ale": { "name": "麦芽", "color": [0.8, 0.6, 0.2] },
    "Wine": { "name": "葡萄", "color": [0.6, 0.1, 0.2] },
    "Bread": { "name": "面粉", "color": [0.7, 0.55, 0.3] },
    "Meat": { "name": "生肉", "color": [0.65, 0.2, 0.1] },
    "Herb": { "name": "草药", "color": [0.2, 0.7, 0.2] }
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add data/recipes.json
git commit -m "feat: 新增配方 JSON 数据文件，从 GameManager 硬编码提取"
```

---

### Task 2: 创建采集点 JSON 数据文件

**Files:**
- Create: `data/locations.json`

- [ ] **Step 1: 创建采集点配置文件**

```json
{
  "maxStamina": 5,
  "locations": [
    { "id": "mushroom_forest", "name": "菌菇林地", "cost": 1, "materials": ["Herb"], "description": "潮湿的洞穴林地，生长着各种菌类和草药" },
    { "id": "abandoned_mine", "name": "废弃矿道", "cost": 2, "materials": ["Ale"], "description": "废弃已久的矿道，偶尔能找到野生麦穗" },
    { "id": "dark_river", "name": "暗河沿岸", "cost": 2, "materials": ["Meat"], "description": "地下暗河旁，小型野兽和鱼类出没" },
    { "id": "grape_trellis", "name": "葡萄藤架", "cost": 1, "materials": ["Wine"], "description": "地牢里罕见的天然葡萄藤" },
    { "id": "mill_farm", "name": "农庄磨坊", "cost": 1, "materials": ["Bread"], "description": "地牢入口附近的农庄，可以交换面粉" }
  ]
}
```

- [ ] **Step 2: 提交**

```bash
git add data/locations.json
git commit -m "feat: 新增采集点 JSON 配置文件"
```

---

### Task 3: 创建 EconomySystem

**Files:**
- Create: `scripts/systems/EconomySystem.cs`

从 GameManager 中提取金币/声望/酒馆等级逻辑。

- [ ] **Step 1: 编写 EconomySystem.cs**

```csharp
using Godot;
using System;

public class EconomySystem
{
    public int Gold { get; private set; } = 0;
    public int Reputation { get; private set; } = 0;
    public int TavernLevel { get; private set; } = 1;
    public int CurrentDay { get; set; } = 1;
    public const int MaxDays = 30;

    private readonly int[] _levelRepThresholds = { 0, 50, 150 };

    public int LevelRepThreshold =>
        TavernLevel < _levelRepThresholds.Length ? _levelRepThresholds[TavernLevel] : int.MaxValue;

    public void AddGold(int amount)
    {
        Gold += amount;
        EmitChanged();
    }

    public void AddReputation(int amount)
    {
        Reputation += amount;
        CheckLevelUp();
        EmitChanged();
    }

    private void CheckLevelUp()
    {
        if (TavernLevel < 3 && Reputation >= _levelRepThresholds[TavernLevel])
        {
            TavernLevel++;
            GD.Print($"[Economy] 酒馆升级到 Lv.{TavernLevel}");
        }
    }

    public bool IsLastDay() => CurrentDay >= MaxDays;

    public event Action Changed;

    private void EmitChanged() => Changed?.Invoke();
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/systems/EconomySystem.cs
git commit -m "feat: 新增 EconomySystem — 金币/声望/酒馆等级/天数"
```

---

### Task 4: 创建 DayCycleSystem

**Files:**
- Create: `scripts/systems/DayCycleSystem.cs`

管理昼夜切换和体力分配。

- [ ] **Step 1: 编写 DayCycleSystem.cs**

```csharp
using Godot;

public enum DayPhase { Day, Night }

public class DayCycleSystem
{
    public DayPhase Phase { get; private set; } = DayPhase.Day;
    public int Stamina { get; private set; } = 5;
    public int MaxStamina { get; private set; } = 5;

    public event System.Action<DayPhase> PhaseChanged;
    public event System.Action StaminaChanged;

    public void StartDay()
    {
        Phase = DayPhase.Day;
        Stamina = MaxStamina;
        StaminaChanged?.Invoke();
    }

    public bool SpendStamina(int amount)
    {
        if (Phase != DayPhase.Day || Stamina < amount) return false;
        Stamina -= amount;
        StaminaChanged?.Invoke();
        return true;
    }

    public void NextPhase()
    {
        if (Phase == DayPhase.Day)
        {
            Phase = DayPhase.Night;
            PhaseChanged?.Invoke(Phase);
        }
        else
        {
            Phase = DayPhase.Day;
            StartDay();
            PhaseChanged?.Invoke(Phase);
        }
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/systems/DayCycleSystem.cs
git commit -m "feat: 新增 DayCycleSystem — 昼夜切换与体力分配"
```

---

### Task 5: 创建 NarrativeManager 骨架

**Files:**
- Create: `scripts/systems/NarrativeManager.cs`

管理 NPC 故事状态和叙事变量，与 Dialogue Manager 插件通信。

- [ ] **Step 1: 编写 NarrativeManager.cs**

```csharp
using Godot;
using System.Collections.Generic;

public class NarrativeManager
{
    // 叙事变量池（供 .dialogue 文件读取）
    private Dictionary<string, object> _vars = new();

    // 关键道具
    public HashSet<string> KeyItems { get; } = new();

    // NPC 好感度 (npc_id → value)
    public Dictionary<string, int> Affection { get; } = new();

    // NPC 结局标记 (npc_id → ending_key)
    public Dictionary<string, string> Endings { get; } = new();

    // 今日应到访的重要 NPC（由故事配置决定）
    public string TodayImportantNpc { get; set; }

    // 今日是否已在白天触发过 NPC 偶遇
    public bool DayEncounterTriggered { get; set; }

    public void SetVar(string key, object value)
    {
        _vars[key] = value;
        // 同步到 Dialogue Manager
        if (DialogueManager.IsInstanceValid())
            ((GodotObject)DialogueManager.Instance).Call("set_variable", key, value);
    }

    public object GetVar(string key) =>
        _vars.TryGetValue(key, out var v) ? v : null;

    public bool HasKeyItem(string itemId) => KeyItems.Contains(itemId);

    public void AddKeyItem(string itemId)
    {
        KeyItems.Add(itemId);
        SetVar($"has_{itemId}", true);
    }

    public void SetAffection(string npcId, int value)
    {
        Affection[npcId] = value;
        SetVar($"aff_{npcId}", value);
    }

    public int GetAffection(string npcId) =>
        Affection.TryGetValue(npcId, out var v) ? v : 0;

    public void SetEnding(string npcId, string ending)
    {
        Endings[npcId] = ending;
        GD.Print($"[Narrative] {npcId} 结局 → {ending}");
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/systems/NarrativeManager.cs
git commit -m "feat: 新增 NarrativeManager 骨架 — 叙事变量与好感度"
```

---

### Task 6: 创建 GuestSystem

**Files:**
- Create: `scripts/systems/GuestSystem.cs`

管理普通客人和重要 NPC 的生成、排队、耐心倒计时。

- [ ] **Step 1: 编写 GuestSystem.cs**

```csharp
using Godot;
using System;
using System.Collections.Generic;

public enum GuestType { Normal, Important }

public class GuestData
{
    public string Name;
    public GuestType Type;
    public string OrderKey;    // 配方 key，如 "Ale"
    public string NpcId;       // 仅重要 NPC 使用
    public double Patience;    // 剩余耐心（秒）
    public bool HasDialogue;   // 是否需要触发对话

    public const double BasePatience = 60.0;
}

public class GuestSystem
{
    public GuestData CurrentGuest { get; private set; }
    public bool HasGuest => CurrentGuest != null;

    private readonly string[] _normalNames = {
        "铁锤格鲁姆","冰霜莱拉","暗影德恩","圣光凯尔","疾风维克斯",
        "暗夜尼克斯","山丘伯林","银弦艾莉亚","怒血索恩","黎明扎拉",
        "磐石芬恩","毒刃鲁克"
    };

    private readonly string[] _normalOrders; // 从配方表取

    private readonly Random _rng = new();
    private double _spawnTimer;
    private double _nextSpawn = 2.0;

    public event Action<GuestData> GuestArrived;
    public event Action GuestLeft;
    public event Action PatienceLow; // 耐心<15s时触发

    public GuestSystem(string[] recipeKeys)
    {
        _normalOrders = recipeKeys;
    }

    public void Update(double dt, bool hasGuest, bool menuOpen)
    {
        // 没有客人时累计生成计时
        if (!hasGuest && !menuOpen)
        {
            _spawnTimer += dt;
            if (_spawnTimer >= _nextSpawn)
            {
                _spawnTimer = 0;
                _nextSpawn = _rng.NextDouble() * 3 + 2; // 2-5s
                SpawnNormal();
            }
        }

        // 客人耐心倒计时
        if (hasGuest && !menuOpen)
        {
            CurrentGuest.Patience -= dt;
            if (CurrentGuest.Patience <= 15 && CurrentGuest.Patience + dt > 15)
                PatienceLow?.Invoke();
            if (CurrentGuest.Patience <= 0)
                ClearGuest();
        }
    }

    private void SpawnNormal()
    {
        CurrentGuest = new GuestData
        {
            Name = _normalNames[_rng.Next(_normalNames.Length)],
            Type = GuestType.Normal,
            OrderKey = _normalOrders[_rng.Next(_normalOrders.Length)],
            Patience = GuestData.BasePatience,
            HasDialogue = false
        };
        GuestArrived?.Invoke(CurrentGuest);
    }

    public void SpawnImportant(string npcId, string orderKey)
    {
        CurrentGuest = new GuestData
        {
            Name = npcId,
            Type = GuestType.Important,
            OrderKey = orderKey,
            NpcId = npcId,
            Patience = GuestData.BasePatience * 1.5, // 重要 NPC 耐心更高
            HasDialogue = true
        };
        GuestArrived?.Invoke(CurrentGuest);
    }

    public void ClearGuest()
    {
        GuestLeft?.Invoke();
        CurrentGuest = null;
        _spawnTimer = 0;
        _nextSpawn = _rng.NextDouble() * 2 + 2;
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/systems/GuestSystem.cs
git commit -m "feat: 新增 GuestSystem — 客人生成/排队/耐心管理"
```

---

### Task 7: 创建 CraftSystem 骨架（配方匹配部分）

**Files:**
- Create: `scripts/systems/CraftSystem.cs`

先实现配方匹配逻辑，手势检测在后续 Task 中逐步加入。

- [ ] **Step 1: 编写 CraftSystem.cs**

```csharp
using Godot;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.IO;

public class RecipeData
{
    public string Key { get; set; }
    public string Name { get; set; }
    public string[] Materials { get; set; }
    public int Price { get; set; }
    public string[] Gestures { get; set; }
    public string Icon { get; set; }
}

public class MaterialData
{
    public string Name { get; set; }
    public float[] Color { get; set; }
}

public class RecipeFile
{
    public RecipeData[] Recipes { get; set; }
    public Dictionary<string, MaterialData> Materials { get; set; }
}

public class CraftSystem
{
    public Dictionary<string, RecipeData> Recipes { get; private set; } = new();
    public Dictionary<string, MaterialData> Materials { get; private set; } = new();
    public string[] RecipeKeys { get; private set; }

    // 当前合成状态
    public string Slot1 { get; set; }
    public string Slot2 { get; set; }
    public string CraftedKey { get; private set; }

    // 手势完成状态
    public bool GestureDragDone { get; set; }
    public bool GestureShakeDone { get; set; }
    public bool GestureHeatDone { get; set; }
    public bool GestureStirDone { get; set; }

    public void LoadRecipes()
    {
        var path = "res://data/recipes.json";
        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        var data = JsonSerializer.Deserialize<RecipeFile>(json);

        foreach (var r in data.Recipes)
            Recipes[r.Key] = r;
        Materials = data.Materials;
        RecipeKeys = Recipes.Keys.ToArray();
        GD.Print($"[Craft] 加载 {Recipes.Count} 个配方, {Materials.Count} 种材料");
    }

    public bool TryMatch(string mat1, string mat2, out string recipeKey)
    {
        recipeKey = null;
        var input = new List<string>();
        if (!string.IsNullOrEmpty(mat1)) input.Add(mat1);
        if (!string.IsNullOrEmpty(mat2)) input.Add(mat2);
        input.Sort();

        foreach (var (key, recipe) in Recipes)
        {
            var required = new List<string>(recipe.Materials);
            required.Sort();
            if (input.SequenceEqual(required))
            {
                recipeKey = key;
                return true;
            }
        }
        return false;
    }

    public bool AllGesturesDone(string recipeKey)
    {
        if (!Recipes.TryGetValue(recipeKey, out var recipe)) return false;
        foreach (var g in recipe.Gestures)
        {
            switch (g)
            {
                case "drag": if (!GestureDragDone) return false; break;
                case "shake": if (!GestureShakeDone) return false; break;
                case "heat": if (!GestureHeatDone) return false; break;
                case "stir": if (!GestureStirDone) return false; break;
            }
        }
        return true;
    }

    public void ResetGestures()
    {
        GestureDragDone = false;
        GestureShakeDone = false;
        GestureHeatDone = false;
        GestureStirDone = false;
    }

    public void ClearCraftSlots()
    {
        Slot1 = null;
        Slot2 = null;
        CraftedKey = null;
        ResetGestures();
    }

    public RecipeData GetRecipe(string key) =>
        Recipes.TryGetValue(key, out var r) ? r : null;

    public static Godot.Color MaterialColor(string key)
    {
        var self = new CraftSystem();
        if (self.Materials.TryGetValue(key, out var m))
        {
            var c = m.Color;
            return new Godot.Color(c[0], c[1], c[2]);
        }
        return Colors.Gray;
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/systems/CraftSystem.cs
git commit -m "feat: 新增 CraftSystem — 配方加载/匹配/手势状态"
```

---

### Task 8: 创建 TavernView 场景（晚上酒馆）

**Files:**
- Create: `scripts/ui/TavernView.cs`
- Create: `scenes/ui/Tavern.tscn`

吧台视角的酒馆主场景。

- [ ] **Step 1: 编写 TavernView.cs 骨架**

```csharp
using Godot;

public partial class TavernView : Node2D
{
    // 从场景引用
    private ColorRect _bgPlaceholder;       // 背景占位（之后替换为纹理）
    private ColorRect _customerSprite;      // 客人形象占位
    private Label _customerName;
    private Label _orderBubble;
    private ProgressBar _timerBar;
    private Label _goldLabel;
    private Label _repLabel;
    private Label _dayLabel;
    private Panel _menuPanel;
    private Button _menuToggle;
    private Label _messageLabel;
    private Control _craftStationNode;
    private Control _shortcutBarNode;

    public Control CraftStation => _craftStationNode;
    public Control ShortcutBar => _shortcutBarNode;

    public override void _Ready()
    {
        _bgPlaceholder = GetNode<ColorRect>("Background");
        _customerSprite = GetNode<ColorRect>("CustomerArea/CustomerSprite");
        _customerName = GetNode<Label>("CustomerArea/CustomerName");
        _orderBubble = GetNode<Label>("CustomerArea/OrderBubble");
        _timerBar = GetNode<ProgressBar>("CustomerArea/TimerBar");
        _goldLabel = GetNode<Label>("TopPanel/GoldLabel");
        _repLabel = GetNode<Label>("TopPanel/ReputationLabel");
        _dayLabel = GetNode<Label>("TopPanel/DayLabel");
        _messageLabel = GetNode<Label>("BottomBar/MessageLabel");

        _menuPanel = GetNode<Panel>("OverlayMenu");
        _menuToggle = GetNode<Button>("TopPanel/MenuButton");
        _menuToggle.Pressed += ToggleMenu;
        _menuPanel.Visible = false;

        _craftStationNode = GetNode<Control>("CraftStation");
        _shortcutBarNode = GetNode<Control>("ShortcutBar");

        GetNode<Button>("OverlayMenu/CloseBtn").Pressed += ToggleMenu;
    }

    public void SetBackgroundColor(Color c) => _bgPlaceholder.Color = c;

    public void ShowCustomer(string name, string order, Color color)
    {
        _customerSprite.Color = color;
        _customerSprite.Visible = true;
        _customerName.Text = name;
        _orderBubble.Text = $"「来一份{order}！」";
        _orderBubble.Visible = true;
    }

    public void HideCustomer()
    {
        _customerSprite.Visible = false;
        _customerName.Text = "等待中……";
        _orderBubble.Visible = false;
    }

    public void UpdateTimer(double ratio) => _timerBar.Value = ratio * 100;

    public void UpdateTopBar(int gold, int rep, int day, int maxDay)
    {
        _goldLabel.Text = $"金币：{gold}";
        _repLabel.Text = $"声望：{rep}";
        _dayLabel.Text = $"第{day}/{maxDay}天";
    }

    public void ShowMessage(string text, Color color)
    {
        _messageLabel.Text = text;
        _messageLabel.AddThemeColorOverride("font_color", color);
    }

    private void ToggleMenu()
    {
        _menuPanel.Visible = !_menuPanel.Visible;
        // 通知 GameManager 菜单状态改变
    }

    public void SetGuestVisible(bool visible) => _customerSprite.Visible = visible;
}
```

- [ ] **Step 2: 在 Godot 编辑器中手动创建 Tavern.tscn 场景**

场景结构（使用 Godot 编辑器 MCP 或手动创建）：

```
Tavern (Node2D, script: res://scripts/ui/TavernView.cs)
├── Background (ColorRect) — 全屏 1280x720，深棕色 #2a1a0e
├── CustomerArea (Control, 锚定: 中上)
│   ├── CustomerSprite (ColorRect, 200x280, 居中)
│   ├── CustomerName (Label, 在 CustomerSprite 上方)
│   ├── OrderBubble (Label, 在 CustomerSprite 旁)
│   └── TimerBar (ProgressBar, 在顶部)
├── CraftStation (Control, 锚定: 中下) — 合成操作区
│   ├── Slot1 (ColorRect, 120x120)
│   ├── Slot2 (ColorRect, 120x120)
│   ├── FireZone (ColorRect, 80x80, 红色) — 加热区
│   ├── ShakerZone (ColorRect, 80x80, 蓝色) — 摇晃区
│   ├── StirZone (ColorRect, 80x80, 绿色) — 搅拌区
│   └── ResultSlot (ColorRect, 100x100)
├── ShortcutBar (HBoxContainer, 锚定: 底部) — 10格快捷栏
├── TopPanel (HBoxContainer, 锚定: 顶部)
│   ├── GoldLabel (Label)
│   ├── ReputationLabel (Label)
│   ├── DayLabel (Label)
│   └── MenuButton (Button: "菜单")
├── BottomBar (Control, 锚定: 底部)
│   └── MessageLabel (Label)
└── OverlayMenu (Panel, 初始隐藏)
    ├── TabBtns (HBoxContainer)
    │   ├── BtnRecipes (Button: "配方")
    │   └── BtnBackpack (Button: "背包")
    ├── RecipePanel (ScrollContainer)
    │   └── RecipeList (VBoxContainer)
    ├── BackpackPanel (ScrollContainer)
    │   └── BackpackList (VBoxContainer)
    └── CloseBtn (Button: "关闭")
```

- [ ] **Step 3: 提交**

```bash
git add scenes/ui/Tavern.tscn scripts/ui/TavernView.cs
git commit -m "feat: 新增 Tavern 场景 — 吧台视角酒馆主界面"
```

---

### Task 9: 创建 DayMapView 场景（白天采集）

**Files:**
- Create: `scripts/ui/DayMapView.cs`
- Create: `scenes/ui/DayMap.tscn`

菜单式采集地图界面。

- [ ] **Step 1: 创建采集点数据类**

```csharp
using Godot;
using System.Collections.Generic;

public class LocationData
{
    public string Id { get; set; }
    public string Name { get; set; }
    public int Cost { get; set; }
    public string[] Materials { get; set; }
    public string Description { get; set; }
}

public class LocationsFile
{
    public int MaxStamina { get; set; }
    public LocationData[] Locations { get; set; }
}
```

- [ ] **Step 2: 编写 DayMapView.cs**

```csharp
using Godot;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

public partial class DayMapView : Node2D
{
    private VBoxContainer _locationList;
    private Label _staminaLabel;
    private Label _dayLabel;
    private Button _goButton;
    private Label _resultLabel;
    private Panel _resultPanel;

    private Dictionary<string, int> _assignments = new(); // locationId → count
    private int _staminaLeft;
    private int _maxStamina;
    private LocationData[] _locations;

    public event System.Action<Dictionary<string, int>> GatheringConfirmed;

    public override void _Ready()
    {
        _locationList = GetNode<VBoxContainer>("MapArea/LocationList");
        _staminaLabel = GetNode<Label>("TopBar/StaminaLabel");
        _dayLabel = GetNode<Label>("TopBar/DayLabel");
        _goButton = GetNode<Button>("GoButton");
        _resultPanel = GetNode<Panel>("ResultPanel");
        _resultLabel = GetNode<Label>("ResultPanel/ResultLabel");

        _goButton.Pressed += OnGoPressed;
        GetNode<Button>("ResultPanel/ContinueBtn").Pressed += OnContinue;

        LoadLocations();
        BuildLocationUI();
    }

    private void LoadLocations()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText());
        _locations = data.Locations;
        _maxStamina = data.MaxStamina;
        _staminaLeft = _maxStamina;
    }

    public void ShowDay(int day, int totalDays)
    {
        _dayLabel.Text = $"第{day}/{totalDays}天 — 白天采集";
        _staminaLeft = _maxStamina;
        _assignments.Clear();
        UpdateStaminaDisplay();
        _resultPanel.Visible = false;
        foreach (var row in _locationList.GetChildren())
            ((Button)row.GetNode<Button>("AddBtn")).Disabled = false;
    }

    private void BuildLocationUI()
    {
        foreach (var loc in _locations)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.CustomMinimumSize = new Vector2(0, 48);

            var info = new VBoxContainer();
            info.CustomMinimumSize = new Vector2(400, 0);
            var nameLabel = new Label { Text = $"{loc.Name} (消耗{loc.Cost}体力)" };
            nameLabel.AddThemeColorOverride("font_color", Colors.White);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            info.AddChild(nameLabel);
            var descLabel = new Label { Text = $"{loc.Description}  产出：{string.Join("、", loc.Materials)}" };
            descLabel.AddThemeColorOverride("font_color", Colors.Gray);
            descLabel.AddThemeFontSizeOverride("font_size", 13);
            info.AddChild(descLabel);
            row.AddChild(info);

            var countLabel = new Label { Text = "0", CustomMinimumSize = new Vector2(30, 0) };
            countLabel.AddThemeColorOverride("font_color", Colors.White);
            countLabel.AddThemeFontSizeOverride("font_size", 20);
            row.AddChild(countLabel);

            var addBtn = new Button { Text = "+" };
            string locId = loc.Id;
            addBtn.Pressed += () => { AddAssignment(locId, loc.Cost, countLabel); };
            row.AddChild(addBtn);
            row.AddChild(countLabel);
            row.AddChild(addBtn);

            _locationList.AddChild(row);
        }
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add scenes/ui/DayMap.tscn scripts/ui/DayMapView.cs
git commit -m "feat: 新增 DayMap 场景 — 白天菜单式采集界面"
```

---

### Task 10: 创建 EndingScreen 场景

**Files:**
- Create: `scripts/ui/EndingScreen.cs`
- Create: `scenes/ui/EndingScreen.tscn`

30 天后的结局结算画面。

- [ ] **Step 1: 编写 EndingScreen.cs**

```csharp
using Godot;
using System.Collections.Generic;

public partial class EndingScreen : Node2D
{
    private VBoxContainer _npcEndingsList;
    private Label _goldLabel;
    private Label _repLabel;
    private Label _titleLabel;

    public override void _Ready()
    {
        _npcEndingsList = GetNode<VBoxContainer>("Content/NPCEndingsList");
        _goldLabel = GetNode<Label>("Content/Stats/GoldLabel");
        _repLabel = GetNode<Label>("Content/Stats/RepLabel");
        _titleLabel = GetNode<Label>("Content/TitleLabel");

        GetNode<Button>("Content/QuitBtn").Pressed += () => GetTree().Quit();
        GetNode<Button>("Content/RestartBtn").Pressed += () =>
            GetTree().ChangeSceneToFile("res://scenes/ui/TitleScreen.tscn");
    }

    public void ShowEndings(int gold, int rep, Dictionary<string, string> npcEndings)
    {
        _goldLabel.Text = $"最终金币：{gold}";
        _repLabel.Text = $"最终声望：{rep}";

        foreach (var (npcId, ending) in npcEndings)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.CustomMinimumSize = new Vector2(0, 40);
            var nameLabel = new Label { Text = npcId, CustomMinimumSize = new Vector2(120, 0) };
            nameLabel.AddThemeColorOverride("font_color", Colors.White);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            row.AddChild(nameLabel);
            var endingLabel = new Label { Text = ending };
            endingLabel.AddThemeColorOverride("font_color", Colors.LightGray);
            endingLabel.AddThemeFontSizeOverride("font_size", 15);
            row.AddChild(endingLabel);
            _npcEndingsList.AddChild(row);
        }
    }
}
```

- [ ] **Step 2: 在 Godot 编辑器中创建 EndingScreen.tscn**

```
EndingScreen (Node2D, script: res://scripts/ui/EndingScreen.cs)
├── Background (ColorRect, 全屏, #0a0a0a)
├── Content (VBoxContainer, 居中 600x500)
│   ├── TitleLabel (Label: "三十日酒馆记")
│   ├── Stats (HBoxContainer)
│   │   ├── GoldLabel (Label)
│   │   └── RepLabel (Label)
│   ├── NPCEndingsList (VBoxContainer)
│   ├── QuitBtn (Button: "退出游戏")
│   └── RestartBtn (Button: "重新开始")
```

- [ ] **Step 3: 提交**

```bash
git add scenes/ui/EndingScreen.tscn scripts/ui/EndingScreen.cs
git commit -m "feat: 新增 EndingScreen — 结局结算画面"
```

---

### Task 11: 改造 TitleScreen 适配新流程

**Files:**
- Modify: `scripts/ui/TitleScreen.cs`
- Modify: `scenes/ui/TitleScreen.tscn`

标题界面点"开始营业"后进入白天采集，而非直接进 Main。

- [ ] **Step 1: 修改 TitleScreen.cs**

```csharp
using Godot;

public partial class TitleScreen : Node2D
{
    public override void _Ready()
    {
        GetNode<Button>("UI/StartButton").Pressed += OnStart;
    }

    private void OnStart()
    {
        // 直接进入白天采集场景，GameManager 的 _Ready 会初始化
        GetTree().ChangeSceneToFile("res://scenes/ui/DayMap.tscn");
    }
}
```

- [ ] **Step 2: 更新 project.godot 中的 autoload 列表**

确保 `project.godot` 只保留 GameManager 和 DialogueManager 两个 Autoload（不需要新增 Autoload）。

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/TitleScreen.cs scenes/ui/TitleScreen.tscn project.godot
git commit -m "feat: 更新标题界面，启动后进入白天采集场景"
```

---

### Task 12: 改造 GameManager — 重构为协调器

**Files:**
- Modify: `scripts/GameManager.cs`

将 GameManager 从包含全部逻辑的大文件重构为委托子系统的协调器。保留必要的 UI 绑定逻辑。

- [ ] **Step 1: 重写 GameManager.cs — 字段和初始化**

```csharp
using Godot;
using System;
using System.Collections.Generic;

public partial class GameManager : Node
{
    // ── 子系统 ──
    public EconomySystem Economy { get; private set; } = new();
    public DayCycleSystem DayCycle { get; private set; } = new();
    public NarrativeManager Narrative { get; private set; } = new();
    public GuestSystem Guests { get; private set; }
    public CraftSystem Craft { get; private set; } = new();

    // ── 库存 ──
    private Dictionary<string, int> _inv = new()
    { ["Ale"]=999,["Wine"]=999,["Bread"]=999,["Meat"]=999,["Herb"]=999 };

    // ── 快捷栏 ──
    private string[] _barMat = new string[10];
    private int[] _barCnt = new int[10];

    // ── 当前场景引用 ──
    private TavernView _tavernView;
    private DayMapView _dayMapView;
    private EndingScreen _endingScreen;

    private bool _initialized;

    // ── 采集结果缓存 ──
    private Dictionary<string, int> _pendingGatherResults;

    public override void _Ready()
    {
        // 加载配方数据
        Craft.LoadRecipes();

        // 初始化 GuestSystem
        Guests = new GuestSystem(Craft.RecipeKeys);
        Guests.GuestArrived += OnGuestArrived;
        Guests.GuestLeft += OnGuestLeft;
        Guests.PatienceLow += OnPatienceLow;

        // 初始化 Economy 变化事件
        Economy.Changed += OnEconomyChanged;

        // 初始化 DayCycle
        DayCycle.PhaseChanged += OnPhaseChanged;

        GD.Print("[GameManager] 初始化完成");
    }
```

- [ ] **Step 2: 场景入口和昼夜切换**

```csharp
    public override void _Process(double dt)
    {
        if (Input.IsActionJustPressed("menu_toggle") && _tavernView != null)
            _tavernView.ToggleMenu();

        // 夜晚客人逻辑
        if (DayCycle.Phase == DayPhase.Night)
            Guests.Update(dt, Guests.HasGuest, false);
    }

    public void RegisterView(Node view)
    {
        if (view is TavernView tv)
        {
            _tavernView = tv;
            RefreshTavernUI();
        }
        else if (view is DayMapView dmv)
        {
            _dayMapView = dmv;
            _dayMapView.ShowDay(Economy.CurrentDay, EconomySystem.MaxDays);
            _dayMapView.GatheringConfirmed += OnGatheringConfirmed;
        }
        else if (view is EndingScreen es)
        {
            _endingScreen = es;
            _endingScreen.ShowEndings(Economy.Gold, Economy.Reputation, Narrative.Endings);
        }
    }

    private void OnGatheringConfirmed(Dictionary<string, int> assignments)
    {
        // 存储采集结果，消耗体力，推进到夜晚
        _pendingGatherResults = new Dictionary<string, int>();
        foreach (var (locId, count) in assignments)
        {
            // 简化：每个地点产出 1-3 个随机材料
            // TODO: 读取 locations.json 中的材料类型随机产出
            if (DayCycle.SpendStamina(count))
            {
                // 先随机给生肉作为 demo
                if (!_pendingGatherResults.ContainsKey("Meat"))
                    _pendingGatherResults["Meat"] = 0;
                _pendingGatherResults["Meat"] += 2;
            }
        }
        // 导入库存
        foreach (var (mat, amount) in _pendingGatherResults)
            _inv[mat] = _inv.GetValueOrDefault(mat, 0) + amount;

        DayCycle.NextPhase(); // Day → Night
    }

    private void OnPhaseChanged(DayPhase phase)
    {
        if (phase == DayPhase.Night)
        {
            // 切换到酒馆场景
            GetTree().ChangeSceneToFile("res://scenes/ui/Tavern.tscn");
        }
        else
        {
            // 新一天
            Economy.CurrentDay++;
            if (Economy.IsLastDay())
            {
                GetTree().ChangeSceneToFile("res://scenes/ui/EndingScreen.tscn");
            }
            else
            {
                GetTree().ChangeSceneToFile("res://scenes/ui/DayMap.tscn");
            }
        }
    }
```

- [ ] **Step 3: 客人与合成逻辑**

```csharp
    private void OnGuestArrived(GuestData guest)
    {
        if (_tavernView == null) return;
        if (guest.HasDialogue)
        {
            // 重要 NPC → 先触发 Dialogue Manager
            Narrative.TodayImportantNpc = guest.NpcId;
            DialogueManager.Instance.Call("show_example_dialogue_balloon",
                $"res://dialogue/{guest.NpcId}.dialogue", "start");
        }
        else
        {
            // 普通客人 → 显示点单
            var recipe = Craft.GetRecipe(guest.OrderKey);
            _tavernView.ShowCustomer(guest.Name, recipe?.Name ?? guest.OrderKey,
                CraftSystem.MaterialColor(recipe?.Materials[0] ?? "Ale"));
        }
    }

    private void OnGuestLeft()
    {
        if (_tavernView != null)
            _tavernView.HideCustomer();
    }

    private void OnPatienceLow()
    {
        if (_tavernView != null)
            _tavernView.ShowMessage("客人等得不耐烦了……", Colors.Orange);
    }

    private void OnEconomyChanged()
    {
        RefreshTavernUI();
    }

    public void TryCraft()
    {
        if (Craft.TryMatch(Craft.Slot1, Craft.Slot2, out var key))
        {
            Craft.CraftedKey = key;
            _tavernView.ShowMessage($"制作完成：{Craft.Recipes[key].Name}！", Colors.GreenYellow);
        }
        else
        {
            Craft.CraftedKey = null;
            _tavernView.ShowMessage("没有匹配的配方！", Colors.OrangeRed);
        }
    }

    public void ServeToGuest()
    {
        if (!Guests.HasGuest || string.IsNullOrEmpty(Craft.CraftedKey)) return;

        if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
        {
            Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
            Economy.AddReputation(2);
            _tavernView.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
        }
        else
        {
            _tavernView.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
        }
        Craft.ClearCraftSlots();
        Guests.ClearGuest();
    }

    private void RefreshTavernUI()
    {
        if (_tavernView == null) return;
        _tavernView.UpdateTopBar(Economy.Gold, Economy.Reputation,
            Economy.CurrentDay, EconomySystem.MaxDays);
    }
}
```

- [ ] **Step 4: 提交**

```bash
git add scripts/GameManager.cs
git commit -m "refactor: 重构 GameManager 为子系统协调器，移除内联逻辑"
```

---

### Task 13: 实现采集系统完整逻辑

**Files:**
- Modify: `scripts/ui/DayMapView.cs`
- Modify: `scripts/systems/DayCycleSystem.cs`

完善采集地图的分配、确认、结果显示流程。

- [ ] **Step 1: 完善 DayMapView.cs — 补全采集分配与结果显示**

```csharp
using Godot;
using System.Collections.Generic;
using System.Text.Json;

public partial class DayMapView : Node2D
{
    private VBoxContainer _locationList;
    private Label _staminaLabel;
    private Label _dayLabel;
    private Button _goButton;
    private Panel _resultPanel;
    private Label _resultLabel;
    private Button _continueBtn;

    private Dictionary<string, int> _assignments = new();
    private int _staminaLeft;
    private int _maxStamina;
    private LocationData[] _locations;

    public event System.Action<Dictionary<string, int>> GatheringConfirmed;

    public override void _Ready()
    {
        _locationList = GetNode<VBoxContainer>("MapArea/LocationList");
        _staminaLabel = GetNode<Label>("TopBar/StaminaLabel");
        _dayLabel = GetNode<Label>("TopBar/DayLabel");
        _goButton = GetNode<Button>("GoButton");
        _resultPanel = GetNode<Panel>("ResultPanel");
        _resultLabel = GetNode<Label>("ResultPanel/ResultLabel");
        _continueBtn = GetNode<Button>("ResultPanel/ContinueBtn");

        _goButton.Pressed += OnGoPressed;
        _continueBtn.Pressed += OnContinue;

        LoadLocations();
        BuildLocationUI();
        UpdateStaminaDisplay();
    }

    private void LoadLocations()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText());
        _locations = data.Locations;
        _maxStamina = data.MaxStamina;
        _staminaLeft = _maxStamina;
    }

    public void ShowDay(int day, int totalDays)
    {
        _dayLabel.Text = $"第 {day}/{totalDays} 天 — 白天·采集";
        _staminaLeft = _maxStamina;
        _assignments.Clear();
        foreach (var kv in _locRows)
            _assignLabels[kv.Key].Text = "0";
        UpdateStaminaDisplay();
        _resultPanel.Visible = false;
        foreach (var btn in _locAddBtns.Values)
            btn.Disabled = false;
        _goButton.Disabled = false;
    }

    private Dictionary<string, HBoxContainer> _locRows = new();
    private Dictionary<string, Label> _assignLabels = new();
    private Dictionary<string, Button> _locAddBtns = new();

    private void BuildLocationUI()
    {
        foreach (var loc in _locations)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.CustomMinimumSize = new Vector2(0, 52);

            var info = new VBoxContainer();
            info.CustomMinimumSize = new Vector2(360, 0);
            var nameLabel = new Label { Text = $"{loc.Name}  [{loc.Cost}体力]" };
            nameLabel.AddThemeColorOverride("font_color", Colors.White);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            info.AddChild(nameLabel);
            var descLabel = new Label { Text = loc.Description };
            descLabel.AddThemeColorOverride("font_color", new Color(0.6f, 0.6f, 0.6f));
            descLabel.AddThemeFontSizeOverride("font_size", 13);
            info.AddChild(descLabel);
            row.AddChild(info);

            var countLabel = new Label { Text = "0", CustomMinimumSize = new Vector2(40, 0),
                HorizontalAlignment = HorizontalAlignment.Center };
            countLabel.AddThemeColorOverride("font_color", Colors.White);
            countLabel.AddThemeFontSizeOverride("font_size", 22);
            row.AddChild(countLabel);

            var addBtn = new Button { Text = "+", CustomMinimumSize = new Vector2(40, 36) };
            string locId = loc.Id;
            addBtn.Pressed += () => AddAssignment(locId, loc.Cost, countLabel);
            row.AddChild(addBtn);

            _locRows[loc.Id] = row;
            _assignLabels[loc.Id] = countLabel;
            _locAddBtns[loc.Id] = addBtn;

            _locationList.AddChild(row);
        }
    }

    private void AddAssignment(string locId, int cost, Label countLabel)
    {
        if (_staminaLeft < cost) return;
        _staminaLeft -= cost;
        _assignments.TryGetValue(locId, out var cur);
        _assignments[locId] = cur + 1;
        countLabel.Text = _assignments[locId].ToString();
        UpdateStaminaDisplay();
        if (_staminaLeft < 1)
        {
            foreach (var btn in _locAddBtns.Values) btn.Disabled = true;
        }
    }

    private void UpdateStaminaDisplay()
    {
        _staminaLabel.Text = $"体力：{_staminaLeft}/{_maxStamina}";
    }

    private void OnGoPressed()
    {
        if (_assignments.Count == 0)
        {
            _resultLabel.Text = "请至少分配一点体力到采集点！";
            _resultPanel.Visible = true;
            return;
        }
        _goButton.Disabled = true;

        // 生成采集结果
        var rng = new System.Random();
        var results = new List<string>();
        foreach (var (locId, count) in _assignments)
        {
            var loc = System.Array.Find(_locations, l => l.Id == locId);
            if (loc == null) continue;
            for (int i = 0; i < count; i++)
            {
                var mat = loc.Materials[rng.Next(loc.Materials.Length)];
                results.Add($"[{loc.Name}] 获得 {mat} x1");
            }
        }

        _resultLabel.Text = "采集结果：\n" + string.Join("\n", results);
        _resultPanel.Visible = true;
        _continueBtn.Visible = true;
    }

    private void OnContinue()
    {
        _resultPanel.Visible = false;
        GatheringConfirmed?.Invoke(_assignments);
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/ui/DayMapView.cs
git commit -m "feat: 完善 DayMapView 采集分配与结果展示逻辑"
```

---

### Task 14: 实现手势检测 — CraftStation UI

**Files:**
- Create: `scripts/ui/CraftStation.cs`

独立的合成操作区组件，处理四种手势的检测和反馈。

- [ ] **Step 1: 编写 CraftStation.cs**

```csharp
using Godot;
using System;
using System.Collections.Generic;

public partial class CraftStation : Control
{
    // ── UI 节点 ──
    private ColorRect _slot1, _slot2, _resultSlot;
    private ColorRect _fireZone, _shakerZone, _stirZone;
    private Label _slot1Label, _slot2Label, _resultLabel;
    private ColorRect[] _shortcutSlots = new ColorRect[10];
    private Label[] _shortcutLabels = new Label[10];

    // ── 拖拽状态 ──
    private bool _dragging;
    private string _dragMaterial;
    private int _dragCount;
    private Panel _dragPanel;
    private int _dragSourceIndex = -1;
    private enum DragSource { None, Slot1, Slot2, Shortcut }
    private DragSource _dragFrom = DragSource.None;

    // ── 热量/搅拌进度 ──
    private double _heatProgress;
    private const double HeatTime = 1.5;
    private bool _heating;

    // ── 摇晃检测 ──
    private bool _shaking;
    private Vector2 _lastShakePos;
    private int _shakeCount;
    private const int ShakeThreshold = 8;

    // ── 搅拌检测 ──
    private bool _stirring;
    private List<Vector2> _stirPath = new();
    private const int StirThreshold = 12;
    private const float StirMinRadius = 20f;

    // ── 快捷栏数据(由 GameManager 提供) ──
    public string[] BarMaterials = new string[10];
    public int[] BarCounts = new int[10];

    public event Action CraftRequested;
    public event Action ServeRequested;
    public event Action ClearRequested;

    public string MaterialInSlot1 => _slot1Label.Text != "空" ? _slot1Label.Text : null;
    public string MaterialInSlot2 => _slot2Label.Text != "空" ? _slot2Label.Text : null;

    public string ResultKey { get; set; }

    public override void _Ready()
    {
        _slot1 = GetNode<ColorRect>("Slot1");
        _slot2 = GetNode<ColorRect>("Slot2");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _fireZone = GetNode<ColorRect>("FireZone");
        _shakerZone = GetNode<ColorRect>("ShakerZone");
        _stirZone = GetNode<ColorRect>("StirZone");
        _slot1Label = GetNode<Label>("Slot1/Label");
        _slot2Label = GetNode<Label>("Slot2/Label");
        _resultLabel = GetNode<Label>("ResultSlot/Label");

        _slot1Label.Text = "空";
        _slot2Label.Text = "空";
        _resultLabel.Text = "";

        // 创建拖拽面板
        _dragPanel = new Panel { Visible = false, ZIndex = 100 };
        AddChild(_dragPanel);

        // 从 GameManager 获取快捷栏引用
        var bar = GetNode<Control>("../ShortcutBar");
        for (int i = 0; i < 10; i++)
        {
            _shortcutSlots[i] = bar.GetNode<ColorRect>($"Slot{i}");
            _shortcutLabels[i] = bar.GetNode<Label>($"Slot{i}/Label");
        }
    }

    public override void _Input(InputEvent e)
    {
        if (e is InputEventMouseButton mb)
        {
            if (mb.ButtonIndex == MouseButton.Left)
            {
                if (mb.Pressed && !_dragging) TryPickUp(mb.Position);
                else if (!mb.Pressed && _dragging) TryDrop(mb.Position);
            }
        }
        if (_dragging && e is InputEventMouseMotion mm)
            UpdateDragPosition(mm.Position);

        // 摇晃检测（拖拽期间检测鼠标快速移动）
        if (_shaking && e is InputEventMouseMotion sm)
        {
            var delta = sm.Position - _lastShakePos;
            if (Math.Abs(delta.X) > 30 || Math.Abs(delta.Y) > 30)
            {
                _shakeCount++;
                if (_shakeCount >= ShakeThreshold)
                {
                    _shaking = false;
                    OnShakeComplete();
                }
            }
            _lastShakePos = sm.Position;
        }
    }

    public override void _Process(double dt)
    {
        // 加热进度
        if (_heating)
        {
            _heatProgress += dt;
            _fireZone.Color = new Color(1f, (float)(1f - _heatProgress / HeatTime), 0f);
            if (_heatProgress >= HeatTime)
            {
                _heating = false;
                OnHeatComplete();
            }
        }
    }

    private void TryPickUp(Vector2 pos)
    {
        // 检查合成槽
        if (HitTest(_slot1, pos) && !string.IsNullOrEmpty(BarMaterials[0]) /*material in slot*/)
        {
            StartDrag(pos); return;
        }
        // 检查快捷栏
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos) && !string.IsNullOrEmpty(BarMaterials[i]) && BarCounts[i] > 0)
            {
                StartDrag(pos, i, BarMaterials[i], DragSource.Shortcut);
                BarCounts[i]--;
                if (BarCounts[i] <= 0) BarMaterials[i] = null;
                RefreshShortcut(i);
                return;
            }
        }
    }

    private void TryDrop(Vector2 pos)
    {
        // 放到合成槽
        if (HitTest(_slot1, pos)) { SetSlot(1, _dragMaterial); EndDrag(); return; }
        if (HitTest(_slot2, pos)) { SetSlot(2, _dragMaterial); EndDrag(); return; }
        // 放到快捷栏
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos) && string.IsNullOrEmpty(BarMaterials[i]))
            {
                BarMaterials[i] = _dragMaterial; BarCounts[i] = 1; EndDrag(); RefreshShortcut(i); return;
            }
        }
        // 放到加热区
        if (HitTest(_fireZone, pos)) { _heating = true; _heatProgress = 0; EndDrag(); return; }
        // 放到摇晃区
        if (HitTest(_shakerZone, pos)) { _shaking = true; _lastShakePos = pos; _shakeCount = 0; EndDrag(); return; }
        // 放到搅拌区
        if (HitTest(_stirZone, pos)) { _stirring = true; _stirPath.Clear(); EndDrag(); return; }
        // 否则退回
        ReturnDrag();
        EndDrag();
    }

    private void SetSlot(int num, string material)
    {
        if (num == 1) _slot1Label.Text = material;
        else _slot2Label.Text = material;
        UpdateSlotColors();
    }

    private void UpdateSlotColors()
    {
        // 用颜色反馈
    }

    private void StartDrag(Vector2 pos, int index = -1, string material = "", DragSource source = DragSource.None)
    {
        _dragging = true; _dragSourceIndex = index; _dragMaterial = material; _dragFrom = source;
        _dragPanel.Visible = true; _dragPanel.Size = new Vector2(48, 48);
        _dragPanel.Position = pos - new Vector2(24, 24);
    }

    private void EndDrag()
    {
        _dragging = false; _dragPanel.Visible = false;
        _dragSourceIndex = -1; _dragFrom = DragSource.None;
        _dragMaterial = null;
    }

    private void ReturnDrag()
    {
        // 退回到来源
        switch (_dragFrom)
        {
            case DragSource.Shortcut:
                if (_dragSourceIndex >= 0)
                {
                    BarMaterials[_dragSourceIndex] = _dragMaterial;
                    BarCounts[_dragSourceIndex]++;
                    RefreshShortcut(_dragSourceIndex);
                }
                break;
        }
    }

    private void UpdateDragPosition(Vector2 pos)
    {
        _dragPanel.Position = pos - new Vector2(24, 24);
    }

    private void OnShakeComplete()
    {
        // 通知 CraftSystem 摇晃手势完成
        GD.Print("[CraftStation] 摇晃完成！");
    }

    private void OnHeatComplete()
    {
        GD.Print("[CraftStation] 加热完成！");
        _fireZone.Color = new Color(0.8f, 0.2f, 0.1f);
    }

    private void RefreshShortcut(int i)
    {
        _shortcutSlots[i].Color = string.IsNullOrEmpty(BarMaterials[i])
            ? new Color(0.1f, 0.08f, 0.06f)
            : CraftSystem.MaterialColor(BarMaterials[i]);
        _shortcutLabels[i].Text = string.IsNullOrEmpty(BarMaterials[i])
            ? "" : $"x{BarCounts[i]}";
    }

    public void RefreshAll() { for (int i = 0; i < 10; i++) RefreshShortcut(i); }

    private static bool HitTest(Control c, Vector2 p)
    {
        var r = c.GetGlobalRect();
        return p.X >= r.Position.X && p.X <= r.End.X && p.Y >= r.Position.Y && p.Y <= r.End.Y;
    }
}
```

- [ ] **Step 2: 在 Tavern.tscn 的 CraftStation 节点上挂载此脚本**

确保 CraftStation Control 节点挂载 `res://scripts/ui/CraftStation.cs`。

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/CraftStation.cs
git commit -m "feat: 新增 CraftStation — 手势检测(拖拽/摇晃/加热/搅拌)"
```

---

### Task 15: 实现 NPC 剧情配置与对话

**Files:**
- Create: `data/npcs.json`
- Modify: `scripts/systems/NarrativeManager.cs`

定义 3-4 个重要 NPC 的剧情触发条件和对话文件映射。

- [ ] **Step 1: 创建 NPC 配置文件**

```json
{
  "npcs": [
    {
      "id": "ryan",
      "name": "莱恩",
      "title": "见习骑士",
      "description": "年轻热血的见习骑士，梦想加入白银阶冒险队伍",
      "affection_start": 0,
      "scenes": [
        { "day": 1, "dialogue": "ryan_day1", "order": "Bread", "trigger": "auto" },
        { "day": 2, "dialogue": "ryan_day2", "order": "Meat", "trigger": "auto",
          "variables": ["has_sleep_powder"] },
        { "day": 3, "dialogue": "ryan_day3", "order": "Herbal Ale", "trigger": "auto",
          "branch_on": "ryan_drugged" },
        { "day": 15, "dialogue": "ryan_day15", "order": "Meat Stew", "trigger": "affection >= 10" },
        { "day": 25, "dialogue": "ryan_day25", "order": "SpicedWine", "trigger": "affection >= 20" }
      ],
      "endings": {
        "hero": "莱恩加入了白银阶队伍，成为真正的骑士",
        "fallen": "莱恩在地牢深处失踪，只留下那面裂开的盾牌",
        "broken": "莱恩活了下来，但血斧小队的覆灭让他一蹶不振"
      }
    },
    {
      "id": "mira",
      "name": "米拉",
      "title": "旅行商人",
      "description": "精明干练的女商人，每周来酒馆一次兜售稀有材料",
      "affection_start": 5,
      "scenes": [
        { "day": 4, "dialogue": "mira_day4", "order": "Wine", "trigger": "auto" },
        { "day": 12, "dialogue": "mira_day12", "order": "SpicedWine", "trigger": "auto" },
        { "day": 20, "dialogue": "mira_day20", "order": "Herbal Ale", "trigger": "affection >= 15" },
        { "day": 28, "dialogue": "mira_day28", "order": "Meat Stew", "trigger": "affection >= 25" }
      ],
      "endings": {
        "partner": "米拉成为了酒馆的固定供应商，一起做生意",
        "farewell": "米拉离开了这个地牢，继续她的旅途",
        "betrayed": "米拉被竞争对手收买，不再出现在酒馆"
      }
    }
  ]
}
```

- [ ] **Step 2: 更新 NarrativeManager 加载 NPC 数据**

```csharp
using Godot;
using System.Collections.Generic;
using System.Text.Json;
using System.Linq;

public class NpcSceneData
{
    public int Day { get; set; }
    public string Dialogue { get; set; }
    public string Order { get; set; }
    public string Trigger { get; set; }
    public string[] Variables { get; set; }
    public string BranchOn { get; set; }
}

public class NpcData
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public int AffectionStart { get; set; }
    public NpcSceneData[] Scenes { get; set; }
    public Dictionary<string, string> Endings { get; set; }
}

public class NpcFile
{
    public NpcData[] Npcs { get; set; }
}

// 在 NarrativeManager 中添加：
public partial class NarrativeManager
{
    public List<NpcData> AllNpcs { get; private set; } = new();

    public void LoadNpcData()
    {
        using var file = FileAccess.Open("res://data/npcs.json", FileAccess.ModeFlags.Read);
        var data = JsonSerializer.Deserialize<NpcFile>(file.GetAsText());
        AllNpcs = new List<NpcData>(data.Npcs);
        foreach (var npc in AllNpcs)
        {
            SetAffection(npc.Id, npc.AffectionStart);
        }
        GD.Print($"[Narrative] 加载 {AllNpcs.Count} 个 NPC");
    }

    // 获取今日应该到访的重要 NPC（检查所有 NPC 的场景配置）
    public NpcData GetTodayScene(int day)
    {
        foreach (var npc in AllNpcs)
        {
            var scene = npc.Scenes.FirstOrDefault(s => s.Day == day);
            if (scene != null)
            {
                // 检查触发条件
                if (scene.Trigger == "auto") return npc;
                if (scene.Trigger.StartsWith("affection"))
                {
                    var parts = scene.Trigger.Split(">=");
                    if (parts.Length == 2 && int.TryParse(parts[1].Trim(), out var threshold))
                        if (GetAffection(npc.Id) >= threshold) return npc;
                }
            }
        }
        return null;
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add data/npcs.json scripts/systems/NarrativeManager.cs
git commit -m "feat: 新增 NPC 剧情配置数据与 NarrativeManager 加载逻辑"
```

---

### Task 16: 编写莱恩 .dialogue 对话文件

**Files:**
- Create: `dialogue/ryan_day1.dialogue`
- Create: `dialogue/ryan_day2.dialogue`  (基于现有 d2.dialogue)
- Create: `dialogue/ryan_day3.dialogue`  (基于现有 d3.dialogue)

基于现有 d1~d3.dialogue，改造为适合新 NarrativeManager 的格式。

- [ ] **Step 1: 创建 ryan_day1.dialogue**

```
~ start
莱恩: 老板！刚开张啊？给我来一份黑面包！
莱恩: 今天我可是在地牢浅层单挑了三只史莱姆！
莱恩: 总有一天，我要加入那些白银阶的队伍！

- 递上黑面包
    莱恩: 呼——活过来了！你的手艺还是这么实在。
    莱恩: 走了老板，明天见！
    set aff_ryan = 5
    => END

- 没有递上
    莱恩: 唉，看来今天运气不太好……
    => END
```

- [ ] **Step 2: 创建 ryan_day2.dialogue（含迷睡花粉分支）**

```
~ start

if has_sleep_powder
    莱恩: 老板，今天有什么特别的吗？
    # 玩家可以让莱恩昏睡

    - 将迷睡花粉混入酒中
        莱恩: 这酒……怎么有点……头晕……
        set ryan_drugged = true
        => END

    - 不掺入花粉
        莱恩: 今天来份烤肉，明天有场硬仗要打！
        set aff_ryan = 10
        => END

else
    莱恩: 老板，来份烤肉！明天我要跟血斧小队去地牢深处！
    莱恩: 这是我加入白银阶的第一步！
    set aff_ryan = 10
    => END
```

- [ ] **Step 3: 创建 ryan_day3.dialogue（结局分支）**

```
~ start

if ryan_drugged
    # 莱恩睡过头，血斧小队全灭
    佣兵甲: 老板……这是莱恩的盾牌。
    佣兵甲: 血斧小队在地牢二层全军覆没……
    佣兵甲: 莱恩他……精神崩溃了，说要回老家。
    set ryan_ending = "broken"
    => END

else
    # 莱恩未干预，死亡结局
    佣兵甲: 老板……莱恩今天在地牢里……
    佣兵甲: 他为了保护队友，挡住了怪物的攻击……
    佣兵甲: 这是他留下的盾牌。
    set ryan_ending = "fallen"
    => END
```

- [ ] **Step 4: 提交**

```bash
git add dialogue/ryan_day1.dialogue dialogue/ryan_day2.dialogue dialogue/ryan_day3.dialogue
git commit -m "feat: 新增莱恩 3 天叙事线（改造自 d1-d3）"
```

---

### Task 17: 创建米拉 .dialogue 对话文件

**Files:**
- Create: `dialogue/mira_day4.dialogue`
- Create: `dialogue/mira_day12.dialogue`

- [ ] **Step 1: 创建 mira_day4.dialogue（米拉首次登场）**

```
~ start
米拉: 你就是新来的老板？
米拉: 我是米拉，跑商的。每周经过这里一次。
米拉: 需要什么稀有材料可以跟我预订。
米拉: 来杯葡萄酒吧，一路渴死了。

- 递上葡萄酒
    米拉: 不错。你这店比上一任老板在的时候强多了。
    米拉: 下周见。
    set aff_mira = 10
    => END
```

- [ ] **Step 2: 创建 mira_day12.dialogue**

```
~ start
米拉: 又见面了。
米拉: 对了，最近听到一些消息……
米拉: 你的骑士朋友莱恩，最近好像在准备什么大事？
米拉: 来杯香料红酒吧。

- 递上香料红酒
    米拉: 很好。这消息算我送你的。
    set aff_mira = 15
    => END
```

- [ ] **Step 3: 提交**

```bash
git add dialogue/mira_day4.dialogue dialogue/mira_day12.dialogue
git commit -m "feat: 新增米拉 NPC 对话文件"
```

---

### Task 18: 连接 GameManager 与所有子系统

**Files:**
- Modify: `scripts/GameManager.cs`

完善 GameManager 中场景切换、系统间通信的胶水代码。

- [ ] **Step 1: 在 GameManager._Ready() 补充 NPC 数据加载**

```csharp
// 在 _Ready() 末尾添加:
Narrative.LoadNpcData();
_initialized = true;
```

- [ ] **Step 2: 完善场景切换逻辑 —— 添加场景就绪信号监听**

```csharp
    public override void _Ready()
    {
        // ... 现有初始化代码 ...

        // 场景切换后自动注册视图
        GetTree().NodeAdded += OnNodeAdded;
    }

    private void OnNodeAdded(Node node)
    {
        // 延迟到下一帧注册，确保节点 _Ready 完成
        CallDeferred(nameof(RegisterViewDeferred), node);
    }

    private void RegisterViewDeferred(Node node)
    {
        if (node is TavernView tv) RegisterView(tv);
        else if (node is DayMapView dmv) RegisterView(dmv);
        else if (node is EndingScreen es) RegisterView(es);
    }

    public void RegisterView(Node view)
    {
        if (view is TavernView tv)
        {
            _tavernView = tv;
            RefreshTavernUI();
            // 检查今日是否有重要 NPC
            var npcToday = Narrative.GetTodayScene(Economy.CurrentDay);
            if (npcToday != null)
            {
                var scene = System.Array.Find(npcToday.Scenes, s => s.Day == Economy.CurrentDay);
                Guests.SpawnImportant(npcToday.Id, scene?.Order ?? "Bread");
            }
        }
        else if (view is DayMapView dmv)
        {
            _dayMapView = dmv;
            _dayMapView.ShowDay(Economy.CurrentDay, EconomySystem.MaxDays);
            _dayMapView.GatheringConfirmed += OnGatheringConfirmed;
        }
        else if (view is EndingScreen es)
        {
            _endingScreen = es;
            _endingScreen.ShowEndings(Economy.Gold, Economy.Reputation, Narrative.Endings);
        }
    }
```

- [ ] **Step 3: 完善夜晚结束时推进天数**

```csharp
    // 当所有客人服务完毕 → 结束夜晚，推进下一天
    public void EndNight()
    {
        DayCycle.NextPhase(); // Night → Day
        // DayCycle 内部会触发 PhaseChanged 事件 → 切换场景
    }

    // 在 GuestLeft 事件中检查是否需要结束夜晚
    private void OnGuestLeft()
    {
        if (_tavernView != null)
            _tavernView.HideCustomer();

        // 夜晚：如果没客人且重要 NPC 也已完成对话，可手动推进
        // 简化处理：每次客人离开后 3 秒无新客人则推进
    }
```

- [ ] **Step 4: 提交**

```bash
git add scripts/GameManager.cs
git commit -m "feat: 完善 GameManager 子系统协调与场景切换逻辑"
```

---

### Task 19: 实现背包与配方 UI 面板

**Files:**
- Modify: `scripts/ui/TavernView.cs`

在酒馆场景中实现 E 键菜单的配方表和背包显示。

- [ ] **Step 1: 完善 TavernView 菜单面板逻辑**

```csharp
// 在 TavernView 中添加方法：

private ScrollContainer _recipePanel;
private VBoxContainer _recipeList;
private ScrollContainer _backpackPanel;
private VBoxContainer _backpackList;
private Panel _menuPanel;

public void ToggleMenu()
{
    _menuPanel.Visible = !_menuPanel.Visible;
}

public void BuildRecipeList(System.Collections.Generic.Dictionary<string, RecipeData> recipes,
    System.Collections.Generic.Dictionary<string, string> matNames)
{
    foreach (var child in _recipeList.GetChildren())
        child.QueueFree();

    foreach (var (key, recipe) in recipes)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 8);
        row.CustomMinimumSize = new Vector2(0, 36);

        // 材料1 色块
        var mat1Box = new ColorRect {
            Color = CraftSystem.MaterialColor(recipe.Materials[0]),
            CustomMinimumSize = new Vector2(40, 24)
        };
        row.AddChild(mat1Box);
        row.AddChild(new Label { Text = matNames.GetValueOrDefault(recipe.Materials[0], recipe.Materials[0]) });

        if (recipe.Materials.Length > 1)
        {
            row.AddChild(new Label { Text = "+" });
            var mat2Box = new ColorRect {
                Color = CraftSystem.MaterialColor(recipe.Materials[1]),
                CustomMinimumSize = new Vector2(40, 24)
            };
            row.AddChild(mat2Box);
            row.AddChild(new Label { Text = matNames.GetValueOrDefault(recipe.Materials[1], recipe.Materials[1]) });
        }

        row.AddChild(new Label { Text = $"= {recipe.Name}  {recipe.Price}金" });
        row.AddChild(new Label { Text = $"[{string.Join(",", recipe.Gestures)}]" });

        _recipeList.AddChild(row);
    }
}

public void BuildBackpackList(Dictionary<string, int> inventory, Dictionary<string, string> matNames)
{
    foreach (var child in _backpackList.GetChildren())
        child.QueueFree();

    foreach (var (mat, count) in inventory)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 6);
        row.CustomMinimumSize = new Vector2(0, 36);
        var box = new ColorRect {
            Color = CraftSystem.MaterialColor(mat),
            CustomMinimumSize = new Vector2(40, 24)
        };
        row.AddChild(box);
        var label = new Label { Text = $"{matNames.GetValueOrDefault(mat, mat)}  ×{count}" };
        label.AddThemeColorOverride("font_color", Colors.White);
        row.AddChild(label);
        _backpackList.AddChild(row);
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/ui/TavernView.cs
git commit -m "feat: 实现 TavernView 菜单面板 — 配方表与背包显示"
```

---

### Task 20: 创建背包数据 JSON 并实现库存初始化

**Files:**
- Create: `data/inventory_default.json`

将库存初始数据从代码移到 JSON。

- [ ] **Step 1: 创建 inventory_default.json**

```json
{
  "Ale": 50,
  "Wine": 50,
  "Bread": 50,
  "Meat": 50,
  "Herb": 50
}
```

- [ ] **Step 2: 在 GameManager 中加载初始库存**

```csharp
// 替换 _inv 的硬编码初始化
private Dictionary<string, int> LoadInitialInventory()
{
    using var file = FileAccess.Open("res://data/inventory_default.json", FileAccess.ModeFlags.Read);
    if (file == null)
    {
        // fallback
        return new() { ["Ale"]=50,["Wine"]=50,["Bread"]=50,["Meat"]=50,["Herb"]=50 };
    }
    var json = file.GetAsText();
    return JsonSerializer.Deserialize<Dictionary<string, int>>(json);
}
```

- [ ] **Step 3: 提交**

```bash
git add data/inventory_default.json scripts/GameManager.cs
git commit -m "feat: 库存数据迁移至 JSON 文件"
```

---

### Task 21: 实现昼夜循环 Scene 切换 & Ending 流程

**Files:**
- Modify: `scripts/GameManager.cs`
- Modify: `scripts/systems/DayCycleSystem.cs`

确保白天→夜晚→结算→夜晚→...→结局的完整流程运行正常。

- [ ] **Step 1: 检查 DayCycleSystem 确保循环正确**

```csharp
// DayCycleSystem.NextPhase() 应处理:
// Day → Night: 切换到 Tavern.tscn
// Night → Day: 天数+1，检查是否最后一天，切换 DayMap 或 Ending

// 在 DayCycleSystem 中添加天数递增回调:
public event System.Action<int> DayAdvanced;

public void NextPhase()
{
    if (Phase == DayPhase.Day)
    {
        Phase = DayPhase.Night;
        PhaseChanged?.Invoke(Phase);
    }
    else // Night → Day
    {
        Phase = DayPhase.Day;
        // 天数递增由 GameManager 处理
        PhaseChanged?.Invoke(Phase);
    }
}
```

- [ ] **Step 2: 在 GameManager 中处理天数推进和结局触发**

```csharp
private void OnPhaseChanged(DayPhase phase)
{
    if (phase == DayPhase.Night)
    {
        GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/Tavern.tscn");
    }
    else // 进入新一天
    {
        Economy.CurrentDay++;
        if (Economy.CurrentDay > EconomySystem.MaxDays)
        {
            // 30 天结束，进入结局
            GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/EndingScreen.tscn");
        }
        else
        {
            GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/DayMap.tscn");
        }
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add scripts/GameManager.cs scripts/systems/DayCycleSystem.cs
git commit -m "feat: 实现完整昼夜循环与结局流程"
```

---

### Task 22: 添加夜晚手动结束按钮

**Files:**
- Modify: `scripts/ui/TavernView.cs`
- Modify: `scenes/ui/Tavern.tscn`

在酒馆场景添加"打烊"按钮，玩家可以手动结束夜晚。

- [ ] **Step 1: 在 TavernView 中添加打烊按钮逻辑**

```csharp
private Button _endNightBtn;

// 在 _Ready() 中:
_endNightBtn = GetNode<Button>("TopPanel/EndNightBtn");
_endNightBtn.Pressed += () => {
    var gm = GetNode<GameManager>("/root/GameManager");
    gm.EndNight();
};
```

- [ ] **Step 2: 在 GameManager 中实现 EndNight**

```csharp
public void EndNight()
{
    if (DayCycle.Phase != DayPhase.Night) return;
    if (Guests.HasGuest)
    {
        _tavernView?.ShowMessage("还有客人在等呢！", Colors.Orange);
        return;
    }
    DayCycle.NextPhase(); // Night → Day（触发 PhaseChanged）
}
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/TavernView.cs scripts/GameManager.cs
git commit -m "feat: 添加夜晚手动打烊按钮"
```

---

### Task 23: 配方与合成槽绑定 CraftStation ↔ GameManager

**Files:**
- Modify: `scripts/ui/CraftStation.cs`
- Modify: `scripts/GameManager.cs`

让 CraftStation 的拖拽合成与 GameManager 的配方匹配联动。

- [ ] **Step 1: 在 CraftStation 中暴露合成/服务事件**

CraftStation 已经定义了 `CraftRequested`、`ServeRequested`、`ClearRequested` 事件和 `MaterialInSlot1/2` 属性。

- [ ] **Step 2: 在 GameManager.RegisterView 中绑定 CraftStation 事件**

```csharp
public void RegisterView(Node view)
{
    // ... 现有代码 ...

    if (view is TavernView tv)
    {
        // ... 现有代码 ...
        var craft = tv.GetNode<CraftStation>("CraftStation");
        craft.CraftRequested += () => {
            Craft.Slot1 = craft.MaterialInSlot1;
            Craft.Slot2 = craft.MaterialInSlot2;
            TryCraft();
            if (!string.IsNullOrEmpty(Craft.CraftedKey))
            {
                craft.ResultKey = Craft.CraftedKey;
            }
        };
        craft.ServeRequested += ServeToGuest;
        craft.ClearRequested += () => {
            Craft.ClearCraftSlots();
            craft.ResultKey = null;
        };
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/CraftStation.cs scripts/GameManager.cs
git commit -m "feat: 绑定 CraftStation 手势合成与 GameManager 配方匹配"
```

---

### Task 24: 集成测试与 Bug 修复

**Files:** (无新增，修复现有文件)

- [ ] **Step 1: 启动 Godot 编辑器，运行完整流程**

```bash
dotnet build
```

使用 Godot 编辑器运行项目，测试以下路径：
1. 标题 → 点"开始营业" → 进入白天采集
2. 白天采集 → 分配体力 → 进入夜晚酒馆
3. 夜晚酒馆 → 普通客人出现 → 拖拽合成 → 上菜
4. 夜晚酒馆 → 重要 NPC 出现 → 对话
5. 手动打烊 → 进入下一天
6. 重复 30 天 → 进入结局

- [ ] **Step 2: 记下遇到的 bug 并逐一修复**

常见预期问题：
- 场景切换后节点引用为空（用 CallDeferred 解决）
- 库存数据 JSON 反序列化键名不匹配
- CraftStation 拖拽面板层级错误
- Dialogue Manager 变量同步失败
- 客人永不结束导致天数不推进

- [ ] **Step 3: 提交修复**

```bash
git add -A
git commit -m "fix: 集成测试修复 — 场景切换/节点引用/变量同步问题"
```

---

### Task 25: 数值平衡与体验打磨

**Files:**
- Modify: `data/recipes.json`
- Modify: `data/locations.json`
- Modify: `data/inventory_default.json`

根据实际游戏手感调整数值。

- [ ] **Step 1: 调整关键数值**

| 参数 | 当前值 | 建议调整方向 |
|------|--------|-------------|
| 初始库存 | 50 每种 | 减少到 20-30，制造稀缺感 |
| 体力上限 | 5 | 先测 5 够不够，不够改 6-8 |
| 客人耐心 | 60s | 测新手是否来得及操作，可能需要 90s |
| 生成间隔 | 2-5s | 改为 3-8s，让节奏更从容 |
| 声望升级阈值 | 50/150 | 30 天内是否合理，按需调整 |
| 配方价格 | 3-12 金 | 检查是否能覆盖材料购买成本 |

- [ ] **Step 2: 添加经营引导提示**

在 GameManager 中添加第一天教学提示：

```csharp
if (Economy.CurrentDay == 1 && DayCycle.Phase == DayPhase.Night)
{
    _tavernView?.ShowMessage("欢迎来到酒馆！拖拽材料到合成区，匹配配方后服务客人。", Colors.White);
}
```

- [ ] **Step 3: 提交**

```bash
git add data/ scripts/GameManager.cs
git commit -m "balance: 数值调整与教学引导优化"
```

---

## 进度总览

| 阶段 | 任务 | 预估时间 | 状态 |
|------|------|----------|------|
| **数据层** | 1-2 | 2天 | 待开始 |
| **系统层** | 3-7 | 5天 | 待开始 |
| **场景层** | 8-11 | 4天 | 待开始 |
| **核心循环** | 12-14 | 4天 | 待开始 |
| **叙事内容** | 15-17 | 4天 | 待开始 |
| **集成胶水** | 18-20 | 3天 | 待开始 |
| **流程打通** | 21-23 | 3天 | 待开始 |
| **测试打磨** | 24-25 | 3天 | 待开始 |

总计约 28 天（4 周）。

---

## 美术资源占位清单

所有美术资源在初期用纯色 ColorRect 占位，代码完整运行后再替换为真实资源：

| 占位 | 颜色 | 后续替换 |
|------|------|----------|
| 吧台背景 | 深棕 #2a1a0e | 手绘吧台场景 PNG |
| 客人形象 | 根据类型变色 | NPC 立绘 + 表情差分 |
| 材料/成品图标 | 通过 CraftSystem.MaterialColor 着色 | 像素图标 PNG |
| 采集地图 | 深灰背景 + 文字按钮 | 手绘地牢区域地图 |
