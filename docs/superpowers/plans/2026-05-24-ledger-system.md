# 账本系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 每天打烊时弹出全屏账本面板，展示当日营收 + NPC 宿命记录，玩家手动关闭后进入下一天。

**Architecture:** 在 EconomySystem/GuestSystem 中新增每日增量追踪；NarrativeManager 新增宿命查询方法；GameManager.EndNight() 收集数据后切到独立的 LedgerScreen 场景渲染；玩家点"继续"触发 DayCycle.NextPhase 进入新一天。

**Tech Stack:** Godot 4.6 .NET/C#, Node2D 场景, Label/HBoxContainer/VBoxContainer UI

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新增 | `scripts/ui/LedgerScreen.cs` | 账本 UI 逻辑，从 GameManager 读取 LedgerData 渲染 |
| 新增 | `scenes/ui/LedgerScreen.tscn` | 账本场景节点布局 |
| 修改 | `scripts/systems/EconomySystem.cs` | GoldToday / RepToday + ResetDaily |
| 修改 | `scripts/systems/GuestSystem.cs` | GuestsServedToday / OrdersSuccess / OrdersFailed + ResetDaily |
| 修改 | `scripts/systems/NarrativeManager.cs` | GetTodayNpcFates(int day) |
| 修改 | `scripts/GameManager.cs` | LedgerData 类 + EndNight 改造 + ServeRequested 订单记录 + RegisterView 连接 |

---

### Task 1: EconomySystem 每日追踪

**Files:**
- Modify: `scripts/systems/EconomySystem.cs`

- [ ] **Step 1: 添加 GoldToday / RepToday 属性 + ResetDaily 方法**

在 `AddReputation` 方法之后，`CheckLevelUp` 之前，插入以下代码：

```csharp
    // ── 每日追踪 ──
    public int GoldToday { get; private set; }
    public int RepToday { get; private set; }

    public void ResetDaily()
    {
        GoldToday = 0;
        RepToday = 0;
    }
```

- [ ] **Step 2: 修改 AddGold 累加 GoldToday**

将：
```csharp
    public void AddGold(int amount)
    {
        Gold += amount;
        EmitChanged();
    }
```

改为：
```csharp
    public void AddGold(int amount)
    {
        Gold += amount;
        GoldToday += amount;
        EmitChanged();
    }
```

- [ ] **Step 3: 修改 AddReputation 累加 RepToday**

将：
```csharp
    public void AddReputation(int amount)
    {
        Reputation += amount;
        CheckLevelUp();
        EmitChanged();
    }
```

改为：
```csharp
    public void AddReputation(int amount)
    {
        Reputation += amount;
        RepToday += amount;
        CheckLevelUp();
        EmitChanged();
    }
```

- [ ] **Step 4: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/EconomySystem.cs
git commit -m "feat: add GoldToday/RepToday daily tracking to EconomySystem"
```

---

### Task 2: GuestSystem 每日追踪

**Files:**
- Modify: `scripts/systems/GuestSystem.cs`

- [ ] **Step 1: 添加每日统计属性和方法**

在 `GuestSystem` 类的 `ClearGuest` 方法之后，类闭合 `}` 之前，插入以下代码：

```csharp
    // ── 每日追踪 ──
    public int GuestsServedToday { get; private set; }
    public int OrdersSuccess { get; private set; }
    public int OrdersFailed { get; private set; }

    public void RecordGuestServed()
    {
        GuestsServedToday++;
    }

    public void RecordOrderSuccess()
    {
        OrdersSuccess++;
    }

    public void RecordOrderFailed()
    {
        OrdersFailed++;
    }

    public void ResetDaily()
    {
        GuestsServedToday = 0;
        OrdersSuccess = 0;
        OrdersFailed = 0;
    }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/GuestSystem.cs
git commit -m "feat: add daily guest/order tracking to GuestSystem"
```

---

### Task 3: NarrativeManager.GetTodayNpcFates

**Files:**
- Modify: `scripts/systems/NarrativeManager.cs`

- [ ] **Step 1: 添加 NpcFateEntry 类和 GetTodayNpcFates 方法**

在 `NarrativeManager` 类末尾（类闭合 `}` 之前）添加：

```csharp
    /// Get fate entries for NPCs whose ending was sealed today.
    public List<(string NpcName, string NpcTitle, string FateText)> GetTodayNpcFates(int day)
    {
        var result = new List<(string NpcName, string NpcTitle, string FateText)>();

        foreach (var npc in AllNpcs)
        {
            // Only NPCs that have a scene scheduled for today
            var scene = npc.Scenes.FirstOrDefault(s => s.Day == day);
            if (scene == null) continue;

            // Check if ending variable was set (e.g. "ryan_ending")
            var endingVar = $"{npc.Id}_ending";
            if (DialogueVars.TryGetValue(endingVar, out var endingVal))
            {
                var endingKey = endingVal.AsString();
                if (!string.IsNullOrEmpty(endingKey) && npc.Endings != null
                    && npc.Endings.TryGetValue(endingKey, out var fateText))
                {
                    result.Add((npc.Name, npc.Title, fateText));
                }
            }
        }

        return result;
    }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/systems/NarrativeManager.cs
git commit -m "feat: add GetTodayNpcFates to NarrativeManager for ledger"
```

---

### Task 4: GameManager 集成每日追踪 + LedgerData

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 添加 LedgerData 类**

在 `GameManager` 类之前（`namespace` 或文件顶部 `using` 之后）添加：

```csharp
public class LedgerData
{
    public int Day;
    public int GoldToday;
    public int RepToday;
    public int GoldTotal;
    public int RepTotal;
    public int GuestsServed;
    public int OrdersSuccess;
    public int OrdersFailed;
    public List<(string NpcName, string NpcTitle, string FateText)> NpcFates;
}
```

- [ ] **Step 2: 添加 CurrentLedgerData 属性**

在 `GameManager` 类的 `_endingScreen` 字段之后添加：

```csharp
    public LedgerData CurrentLedgerData { get; private set; }
```

- [ ] **Step 3: 在 ServeRequested 中记录订单成败和客人服务**

找到 `craftStation.ServeRequested += () => { ... };` 中的订单处理逻辑。当前代码位于 `RegisterView` 方法内。

将 ServeRequested 的回调中的成功/失败分支修改为：

```csharp
                craftStation.ServeRequested += () => {
                    if (!Guests.HasGuest || string.IsNullOrEmpty(Craft.CraftedKey)) return;

                    if (!Craft.AllGesturesDone(Craft.CraftedKey))
                    {
                        tv.ShowMessage("请先完成所有手势！", Colors.Orange);
                        return;
                    }

                    if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
                    {
                        Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
                        Economy.AddReputation(2);
                        Guests.RecordOrderSuccess();
                        tv.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
                    }
                    else
                    {
                        Guests.RecordOrderFailed();
                        tv.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
                    }
                    Guests.RecordGuestServed();
                    Craft.ClearCraftSlots();
                    craftStation.ClearSlots();
                    Guests.ClearGuest();
                };
```

- [ ] **Step 4: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: add LedgerData class and daily order tracking to GameManager"
```

---

### Task 5: LedgerScreen 场景 + 脚本

**Files:**
- Create: `scripts/ui/LedgerScreen.cs`
- Create: `scenes/ui/LedgerScreen.tscn`

- [ ] **Step 1: 创建 LedgerScreen.cs**

```csharp
using Godot;
using System.Collections.Generic;

public partial class LedgerScreen : Node2D
{
    private Label _titleLabel;
    private VBoxContainer _statsList;
    private Label _fateTitle;
    private VBoxContainer _fateList;
    private Button _continueBtn;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("UI/TitleLabel");
        _statsList = GetNode<VBoxContainer>("UI/StatsList");
        _fateTitle = GetNode<Label>("UI/FateTitle");
        _fateList = GetNode<VBoxContainer>("UI/FateList");
        _continueBtn = GetNode<Button>("UI/ContinueBtn");

        _continueBtn.Pressed += OnContinue;

        var gm = GetNode<GameManager>("/root/GameManager");
        var data = gm.CurrentLedgerData;
        if (data != null)
            Render(data);
    }

    private void Render(LedgerData data)
    {
        // Title
        _titleLabel.Text = $"第 {data.Day} 天 · 营业结算";
        ThemeColors.StyleHeader(_titleLabel, 30);
        _titleLabel.AddThemeConstantOverride("outline_size", 2);

        // Stats
        AddStatRow($"金币收入    +{data.GoldToday} 金      累计: {data.GoldTotal} 金");
        AddStatRow($"声望变化    +{data.RepToday}           累计: {data.RepTotal}");
        AddStatRow($"服务客人    {data.GuestsServed} 位");
        AddStatRow($"成功订单    {data.OrdersSuccess} 单");
        AddStatRow($"失败订单    {data.OrdersFailed} 单");

        // Fate section
        if (data.NpcFates != null && data.NpcFates.Count > 0)
        {
            _fateTitle.Text = "今日宿命";
            ThemeColors.StyleHeader(_fateTitle, 22);
            _fateTitle.AddThemeConstantOverride("outline_size", 1);

            foreach (var (name, title, fateText) in data.NpcFates)
            {
                var card = new VBoxContainer();
                card.AddThemeConstantOverride("separation", 4);
                card.CustomMinimumSize = new Vector2(0, 60);

                var nameLabel = new Label { Text = $"{name} · {title}" };
                nameLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
                nameLabel.AddThemeFontSizeOverride("font_size", 20);
                card.AddChild(nameLabel);

                var fateLabel = new Label { Text = fateText };
                fateLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
                fateLabel.AddThemeFontSizeOverride("font_size", 15);
                card.AddChild(fateLabel);

                _fateList.AddChild(card);
            }
        }
        else
        {
            _fateTitle.Visible = false;
        }

        // Continue button
        ThemeColors.StyleButton(_continueBtn, 20);
    }

    private void AddStatRow(string text)
    {
        var label = new Label { Text = text };
        label.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        label.AddThemeFontSizeOverride("font_size", 16);
        _statsList.AddChild(label);
    }

    private void OnContinue()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        gm.DayCycle.NextPhase();
    }
}
```

- [ ] **Step 2: 创建 LedgerScreen.tscn**

```gdscene
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/LedgerScreen.cs" id="1"]

[node name="LedgerScreen" type="Node2D"]
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.086, 0.075, 0.067, 1)

[node name="UI" type="Control" parent="."]
layout_mode = 0
offset_left = 200.0
offset_top = 60.0
offset_right = 1080.0
offset_bottom = 680.0

[node name="TitleLabel" type="Label" parent="UI"]
layout_mode = 0
offset_left = 0.0
offset_top = 0.0
offset_right = 880.0
offset_bottom = 50.0
text = "第 X 天 · 营业结算"
horizontal_alignment = 1

[node name="StatsList" type="VBoxContainer" parent="UI"]
layout_mode = 0
offset_left = 0.0
offset_top = 80.0
offset_right = 880.0
offset_bottom = 280.0

[node name="FateTitle" type="Label" parent="UI"]
layout_mode = 0
offset_left = 0.0
offset_top = 320.0
offset_right = 880.0
offset_bottom = 360.0
text = "今日宿命"
horizontal_alignment = 1

[node name="FateList" type="VBoxContainer" parent="UI"]
layout_mode = 0
offset_left = 0.0
offset_top = 370.0
offset_right = 880.0
offset_bottom = 510.0

[node name="ContinueBtn" type="Button" parent="UI"]
layout_mode = 0
offset_left = 340.0
offset_top = 560.0
offset_right = 540.0
offset_bottom = 620.0
text = "继续"
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/LedgerScreen.cs scenes/ui/LedgerScreen.tscn
git commit -m "feat: add LedgerScreen scene and script"
```

---

### Task 6: GameManager.EndNight 改造

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 修改 EndNight 方法**

将当前的 `EndNight()`：

```csharp
    // ── 打烊 ──
    public void EndNight()
    {
        if (DayCycle.Phase != DayPhase.Night) return;
        if (Guests.HasGuest)
        {
            _tavernView?.ShowMessage("还有客人在等呢！", Colors.Orange);
            return;
        }
        DayCycle.NextPhase();
    }
```

替换为：

```csharp
    // ── 打烊 ──
    public void EndNight()
    {
        if (DayCycle.Phase != DayPhase.Night) return;
        if (Guests.HasGuest)
        {
            _tavernView?.ShowMessage("还有客人在等呢！", Colors.Orange);
            return;
        }

        // Build ledger data
        var fates = Narrative.GetTodayNpcFates(Economy.CurrentDay);

        CurrentLedgerData = new LedgerData
        {
            Day = Economy.CurrentDay,
            GoldToday = Economy.GoldToday,
            RepToday = Economy.RepToday,
            GoldTotal = Economy.Gold,
            RepTotal = Economy.Reputation,
            GuestsServed = Guests.GuestsServedToday,
            OrdersSuccess = Guests.OrdersSuccess,
            OrdersFailed = Guests.OrdersFailed,
            NpcFates = fates,
        };

        // Reset for next day
        Economy.ResetDaily();
        Guests.ResetDaily();

        GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/LedgerScreen.tscn");
    }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: wire EndNight to build ledger data and show LedgerScreen"
```

---

### Task 7: 全量编译 + Godot 验证

- [ ] **Step 1: 最终编译**

Run: `dotnet build`
Expected: Build succeeded with 0 Error(s).

- [ ] **Step 2: Godot 运行验证**

Run: 通过 Godot MCP `run_project` 启动游戏，验证核心路径：

1. TitleScreen → 开始营业 → DayMap → 出发 → Tavern
2. 招待客人，完成订单
3. 点击"打烊"
4. 确认 Ledger 场景弹出，显示今日数据
5. 点击"继续" → 进入 DayMap（下一天）
6. 确认 NPC 宿命在第 3 天（莱恩结局日）正确显示

- [ ] **Step 3: 验证边缘情况**

- 无 NPC 到访的日子：确认"今日宿命"区域不显示
- 有客人时点打烊：确认提示"还有客人在等呢！"

---

## Self-Review

**1. Spec coverage:**
- [x] EconomySystem 每日追踪 → Task 1
- [x] GuestSystem 每日追踪 → Task 2
- [x] NarrativeManager.GetTodayNpcFates → Task 3
- [x] LedgerData 类 → Task 4
- [x] GameManager 订单记录 → Task 4
- [x] LedgerScreen 场景+脚本 → Task 5
- [x] EndNight 改造 → Task 6
- [x] NPC 宿命仅在 ending 变量设置时显示 → Task 3
- [x] 无宿命时隐藏区域 → Task 5
- [x] ResetDaily() 在收集数据后立即调用 → Task 6

**2. Placeholder scan:** No TBD/TODO/incomplete sections.

**3. Type consistency:**
- `LedgerData.NpcFates` is `List<(string NpcName, string NpcTitle, string FateText)>` — matches `GetTodayNpcFates` return type ✓
- `GameManager.CurrentLedgerData` typed as `LedgerData` — matches `LedgerScreen` reads ✓
- Tuples used consistently: `(name, title, fateText)` in both Task 3 and Task 5 ✓
