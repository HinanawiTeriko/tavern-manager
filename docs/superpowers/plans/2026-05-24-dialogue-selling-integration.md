# 对话-售卖联动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重要 NPC 到访 → pre 对话（点单）→ 合成上菜 → post 对话（反应+宿命），对话期间合成区变暗不可操作。

**Architecture:** GameManager 新增 `_dialoguePhase` 追踪 pre/post 阶段；TavernView 新增 `SetDialogueMode(bool)` 控制合成区暗化遮罩；ServeRequested 写 `serve_result` 变量后触发 post 对话；DialogueEnded 根据阶段决定恢复 UI 或清除客人。

**Tech Stack:** Godot 4.6 .NET/C#, Dialogue Manager addon, 现有 ThemeColors 设计系统

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `scripts/ui/TavernView.cs` | 新增 `SetDialogueMode(bool)` + 暗化遮罩节点 |
| 修改 | `scripts/GameManager.cs` | `_dialoguePhase`、`OnGuestArrived` 改 pre、`ServeRequested` 写变量+播 post、`DialogueEnded` 分阶段处理 |
| 修改 | `scenes/ui/Tavern.tscn` | 新增 `DialogueOverlay` ColorRect 遮罩节点 |
| 新增 | `dialogue/ryan_day1.pre.dialogue` | 莱恩 D1 寒暄+点单 |
| 新增 | `dialogue/ryan_day1.post.dialogue` | 莱恩 D1 上菜结果反馈 |
| 新增 | `dialogue/ryan_day2.pre.dialogue` | 莱恩 D2 迷睡花粉分支/点单 |
| 新增 | `dialogue/ryan_day2.post.dialogue` | 莱恩 D2 上菜结果反馈 |
| 新增 | `dialogue/ryan_day3.pre.dialogue` | 莱恩 D3 宿命揭示 |
| 新增 | `dialogue/ryan_day3.post.dialogue` | 莱恩 D3 上菜后收尾 |
| 新增 | `dialogue/mira_day4.pre.dialogue` | 米拉 D4 寒暄+点单 |
| 新增 | `dialogue/mira_day4.post.dialogue` | 米拉 D4 上菜结果反馈 |
| 新增 | `dialogue/mira_day12.pre.dialogue` | 米拉 D12 寒暄+点单 |
| 新增 | `dialogue/mira_day12.post.dialogue` | 米拉 D12 上菜结果反馈 |

---

### Task 1: TavernView.SetDialogueMode + 暗化遮罩

**Files:**
- Modify: `scripts/ui/TavernView.cs`
- Modify: `scenes/ui/Tavern.tscn`

- [ ] **Step 1: 在 Tavern.tscn 中添加 DialogueOverlay 遮罩节点**

在 `Tavern.tscn` 的 root node 下，`OverlayMenu` 之前添加一个全屏半透明遮罩：

```gdscene
[node name="DialogueOverlay" type="ColorRect" parent="."]
visible = false
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0, 0, 0, 0.55)
mouse_filter = 1
```

`mouse_filter = 1` (MOUSE_FILTER_STOP) 拦截所有点击，防止穿透到合成区。

插在 `BottomBar` 之后、`OverlayMenu` 之前：

在 `Tavern.tscn` 中找到：
```gdscene
[node name="OverlayMenu" type="Panel" parent="."]
```

在其**前一行**插入上面的 `DialogueOverlay` 节点块。

- [ ] **Step 2: 在 TavernView.cs 中获取 DialogueOverlay 引用并实现 SetDialogueMode**

在 `TavernView.cs` 的字段声明区（`_endNightBtn` 之后）添加：

```csharp
    private ColorRect _dialogueOverlay;
```

在 `_Ready()` 中获取引用（`_endNightBtn = ...` 之后）：

```csharp
        _dialogueOverlay = GetNode<ColorRect>("DialogueOverlay");
```

在 `ShowMessage` 方法之后添加 `SetDialogueMode` 方法：

```csharp
    public void SetDialogueMode(bool active)
    {
        _dialogueOverlay.Visible = active;
        CraftStation.GetNode<Control>(".").MouseFilter = active
            ? Control.MouseFilterEnum.Ignore
            : Control.MouseFilterEnum.Stop;
        ShortcutBar.MouseFilter = active
            ? Control.MouseFilterEnum.Ignore
            : Control.MouseFilterEnum.Stop;
    }
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/TavernView.cs scenes/ui/Tavern.tscn
git commit -m "feat: add SetDialogueMode with overlay dimming to TavernView"
```

---

### Task 2: GameManager 对话阶段追踪 + DialogueEnded 分阶段处理

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 添加 _dialoguePhase 字段**

在 `GameManager` 类的 `_isDialogueActive` 字段之后添加：

```csharp
    // ── 对话阶段：pre（上菜前）/ post（上菜后）/ null（非重要NPC对话）──
    private string _dialoguePhase;
```

- [ ] **Step 2: 修改 DialogueEnded 回调实现分阶段处理**

将当前的：
```csharp
        DialogueManager.DialogueEnded += (_) => _isDialogueActive = false;
```

改为：
```csharp
        DialogueManager.DialogueEnded += (_) => OnDialogueEnded();
```

在 `OnGuestLeft` 方法之后添加 `OnDialogueEnded` 方法：

```csharp
    private void OnDialogueEnded()
    {
        _isDialogueActive = false;

        if (_dialoguePhase == "pre")
        {
            // Pre 对话结束 → 恢复合成区，等待玩家上菜
            _dialoguePhase = null;
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);
        }
        else if (_dialoguePhase == "post")
        {
            // Post 对话结束 → 清理客人，恢复正常
            _dialoguePhase = null;
            Guests.ClearGuest();
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);
        }
    }
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: add dialogue phase tracking and staged DialogueEnded handling"
```

---

### Task 3: GameManager OnGuestArrived → pre 对话 + ServeRequested → post 对话

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 修改 OnGuestArrived 加载 pre 对话**

将 `OnGuestArrived` 中的对话路径从：
```csharp
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.dialogue";
```

改为：
```csharp
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.pre.dialogue";
```

并在 `CallDeferred` 之前添加进入 pre 阶段的逻辑。将：
```csharp
        if (guest.HasDialogue)
        {
            Narrative.TodayImportantNpc = guest.NpcId;
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.dialogue";
            CallDeferred(nameof(StartDialogueDeferred), dialoguePath);
        }
```

改为：
```csharp
        if (guest.HasDialogue)
        {
            Narrative.TodayImportantNpc = guest.NpcId;
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.pre.dialogue";
            _dialoguePhase = "pre";
            _tavernView.SetDialogueMode(true);
            CallDeferred(nameof(StartDialogueDeferred), dialoguePath);
        }
```

- [ ] **Step 2: 修改 ServeRequested 写 serve_result 并触发 post 对话**

将 ServeRequested 回调中成功/失败分支改为写入变量并触发 post 对话。

将当前的成功/失败 + ClearGuest 部分：
```csharp
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
```

改为：
```csharp
                    var isImportant = Guests.CurrentGuest.HasDialogue;
                    var npcId = Guests.CurrentGuest.NpcId;

                    if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
                    {
                        Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
                        Economy.AddReputation(2);
                        Guests.RecordOrderSuccess();
                        tv.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
                        if (isImportant) Narrative.SetVar("serve_result", "success");
                    }
                    else
                    {
                        Guests.RecordOrderFailed();
                        tv.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
                        if (isImportant) Narrative.SetVar("serve_result", "fail");
                    }
                    Guests.RecordGuestServed();
                    Craft.ClearCraftSlots();
                    craftStation.ClearSlots();

                    if (isImportant && !string.IsNullOrEmpty(npcId))
                    {
                        var postPath = $"res://dialogue/{npcId}_day{Economy.CurrentDay}.post.dialogue";
                        if (ResourceLoader.Exists(postPath))
                        {
                            _dialoguePhase = "post";
                            tv.SetDialogueMode(true);
                            CallDeferred(nameof(StartDialogueDeferred), postPath);
                        }
                        else
                        {
                            GD.Print($"[GameManager] post 对话不存在: {postPath}，直接清除客人");
                            Guests.ClearGuest();
                        }
                    }
                    else
                    {
                        Guests.ClearGuest();
                    }
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "feat: wire pre/post dialogue flow with serve_result in ServeRequested"
```

---

### Task 4: 创建 ryan 三条叙事线的 pre/post 对话文件

**Files:**
- Create: `dialogue/ryan_day1.pre.dialogue`
- Create: `dialogue/ryan_day1.post.dialogue`
- Create: `dialogue/ryan_day2.pre.dialogue`
- Create: `dialogue/ryan_day2.post.dialogue`
- Create: `dialogue/ryan_day3.pre.dialogue`
- Create: `dialogue/ryan_day3.post.dialogue`

- [ ] **Step 1: 创建 ryan_day1.pre.dialogue**

```dialogue
~ start
莱恩: 老板！刚开张啊？给我来一份黑面包！
莱恩: 今天我可是在地牢浅层单挑了三只史莱姆！
莱恩: 总有一天，我要加入那些白银阶的队伍！
=> END
```

- [ ] **Step 2: 创建 ryan_day1.post.dialogue**

```dialogue
~ start

if serve_result == "success"
    莱恩: 呼——活过来了！你的手艺还是这么实在。
    莱恩: 走了老板，明天见！
    set aff_ryan = 5
    => END

else
    莱恩: 唉，看来今天运气不太好……
    => END
```

- [ ] **Step 3: 创建 ryan_day2.pre.dialogue**

```dialogue
~ start

if has_sleep_powder
    莱恩: 老板，今天有什么特别的吗？

    - 将迷睡花粉混入酒中
        莱恩: 这酒……怎么有点……头晕……
        set ryan_drugged = true
        => END

    - 不掺入花粉
        莱恩: 今天来份烤肉，明天有场硬仗要打！
        莱恩: 这是我加入白银阶的第一步！
        => END

else
    莱恩: 老板，来份烤肉！明天我要跟血斧小队去地牢深处！
    莱恩: 这是我加入白银阶的第一步！
    => END
```

- [ ] **Step 4: 创建 ryan_day2.post.dialogue**

注：如果玩家选择了"将迷睡花粉混入酒中"（`ryan_drugged = true`），pre 对话以 `=> END` 结束但 NPC 已晕倒，不会触发上菜流程。代码中 `ServeRequested` 检测到 `HasDialogue` 会尝试加载 post 文件，但 `ryan_drugged` 场景下玩家实际无法上菜（客人已消失/晕倒）。

需要在 GameManager 中处理：如果 pre 对话中客人被 drugged 了，跳过上菜阶段直接清除客人。但目前先创建 post 文件作为 fallback：

```dialogue
~ start

if ryan_drugged
    => END

if serve_result == "success"
    莱恩: 好肉！明天就靠这块肉打赢地牢了！
    莱恩: 谢了老板！
    set aff_ryan = 10
    => END

else
    莱恩: 不是这个……算了，我随便吃点就行。
    => END
```

- [ ] **Step 5: 创建 ryan_day3.pre.dialogue**

```dialogue
~ start

if ryan_drugged
    佣兵甲: 老板……这是莱恩的盾牌。
    佣兵甲: 血斧小队在地牢二层全军覆没……
    佣兵甲: 莱恩他……精神崩溃了，说要回老家。
    set ryan_ending = "broken"
    => END

else
    佣兵甲: 老板……莱恩今天在地牢里……
    佣兵甲: 他为了保护队友，挡住了怪物的攻击……
    佣兵甲: 这是他留下的盾牌。
    set ryan_ending = "fallen"
    => END
```

- [ ] **Step 6: 创建 ryan_day3.post.dialogue**

Day 3 没有实际的 NPC 互动上菜（来的是佣兵甲），post 对话为简单收尾：

```dialogue
~ start
佣兵甲: ……节哀。
=> END
```

- [ ] **Step 7: Commit**

```bash
git add dialogue/ryan_day1.pre.dialogue dialogue/ryan_day1.post.dialogue dialogue/ryan_day2.pre.dialogue dialogue/ryan_day2.post.dialogue dialogue/ryan_day3.pre.dialogue dialogue/ryan_day3.post.dialogue
git commit -m "feat: split ryan 3-day narrative into pre/post dialogue files"
```

---

### Task 5: 创建 mira 的 pre/post 对话文件

**Files:**
- Create: `dialogue/mira_day4.pre.dialogue`
- Create: `dialogue/mira_day4.post.dialogue`
- Create: `dialogue/mira_day12.pre.dialogue`
- Create: `dialogue/mira_day12.post.dialogue`

- [ ] **Step 1: 创建 mira_day4.pre.dialogue**

米拉 day4 原对话：
```dialogue
米拉: 老板好久不见！今天来一杯葡萄酒！
米拉: 我在北方收了一批不错的香料，有兴趣吗？
=> END
```

- [ ] **Step 2: 创建 mira_day4.post.dialogue**

```dialogue
~ start

if serve_result == "success"
    米拉: 好酒！我就知道你这儿的水准一直在线。
    米拉: 对了，关于香料的事——下回详谈。
    set aff_mira = 10
    => END

else
    米拉: 这可不是我想要的……算了，生意的事改天再说。
    => END
```

- [ ] **Step 3: 创建 mira_day12.pre.dialogue**

```dialogue
~ start
米拉: 老板，香料红酒，你懂的。
米拉: 今天是来谈正事的——我想和你签个长期供应协议。
=> END
```

- [ ] **Step 4: 创建 mira_day12.post.dialogue**

```dialogue
~ start

if serve_result == "success"
    米拉: 完美！看来我没找错人。
    米拉: 今天就签协议吧。
    set aff_mira = 15
    set mira_ending = "partner"
    => END

else
    米拉: 看来你今天状态不太好……协议的事我再考虑考虑。
    set mira_ending = "farewell"
    => END
```

- [ ] **Step 5: Commit**

```bash
git add dialogue/mira_day4.pre.dialogue dialogue/mira_day4.post.dialogue dialogue/mira_day12.pre.dialogue dialogue/mira_day12.post.dialogue
git commit -m "feat: split mira dialogues into pre/post files"
```

---

### Task 6: Handle drugged scenario — pre 对话中直接结束的情况

**Files:**
- Modify: `scripts/GameManager.cs`

- [ ] **Step 1: 在 OnDialogueEnded 中处理 pre 阶段无需上菜的情况**

当 pre 对话直接走到 END 且没有触发上菜（如 day2 的 drugged 分支），NPC 已在对话中晕倒，不应该等待上菜。

修改 `OnDialogueEnded` 中 pre 分支，检查客人是否仍然存在：

将 Task 2 中写的：
```csharp
        if (_dialoguePhase == "pre")
        {
            _dialoguePhase = null;
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);
        }
```

改为：
```csharp
        if (_dialoguePhase == "pre")
        {
            _dialoguePhase = null;
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);

            // 如果 pre 对话中客人已被移除（如 drugged 场景），直接清理
            if (!Guests.HasGuest)
            {
                _tavernView?.HideCustomer();
            }
        }
```

同时在 ryan_day2.pre.dialogue 的 drugged 分支中，需要在实际 drugged 后清除客人。但 `.dialogue` 文件本身无法调用 C# 方法。因此改为：GameManager 检测到 `ryan_drugged` 从 false 变为 true 时主动清除客人。

更简单的方案：在 `OnDialogueEnded` 的 pre 分支中，检查 `ryan_drugged` 是否为 true，如果是则清除客人。但这太特定化了。

最佳方案：在 pre 对话后，如果当前客人是重要 NPC 且 `ryan_drugged == true`，直接清除客人不上菜。把这个逻辑放在 `OnDialogueEnded` 的 pre 分支中：

```csharp
        if (_dialoguePhase == "pre")
        {
            _dialoguePhase = null;
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);

            // 检查是否 pre 对话中 NPC 已"退出"（如被下药）
            // 如果对话设置了 ryan_drugged = true，清除客人
            var drugged = Narrative.DialogueVars.TryGetValue("ryan_drugged", out var dv) && dv.AsBool();
            if (drugged && Guests.HasGuest && Guests.CurrentGuest.NpcId == "ryan")
            {
                Guests.ClearGuest();
                _tavernView?.HideCustomer();
            }
        }
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/GameManager.cs
git commit -m "fix: handle drugged skip in pre dialogue with automatic guest cleanup"
```

---

### Task 7: 全量编译 + Godot 验证

- [ ] **Step 1: 最终编译**

Run: `dotnet build`
Expected: Build succeeded with 0 Error(s).

- [ ] **Step 2: Godot 运行验证核心路径**

Run: 通过 Godot MCP `run_project` 启动游戏，验证核心路径：

1. TitleScreen → DayMap → 出发 → Tavern
2. Day 1：莱恩到访 → pre 对话弹出（合成区变暗）→ 对话结束 → 合成区恢复 → 制作 Bread 上菜 → post 对话弹出 → 对话结束客人离开
3. Day 2：莱恩到访（无 sleep powder）→ pre 对话点烤肉 → 制作 Meat 上菜 → post 反馈
4. Day 3：莱恩宿命揭示 → pre 对话 → 上 Herbal Ale → post 收尾
5. 确认 `serve_result` 变量正确写入，`aff_ryan`、`ryan_ending` 正确设置
6. 确认普通客人流程不受影响（无对话，直接上菜离开）

- [ ] **Step 3: 验证边缘情况**

- Day 2 drugged 分支：手动设置 `has_sleep_powder = true` → pre 对话选择下药 → 确认客人自动清除不进入合成阶段
- 上错菜：莱恩 day1 上 Wine 而非 Bread → post 对话走 fail 分支
- Post 文件不存在：暂时移除 post 文件 → 确认代码优雅降级（`StartDialogueDeferred` 打印错误后正常恢复）

---

## Self-Review

**1. Spec coverage:**
- [x] Pre 对话 + 合成区变暗 → Task 1, 2, 3
- [x] 合成上菜 → Task 3 (serve_result 变量 + post 触发)
- [x] Post 对话 + 合成区再次变暗 → Task 3
- [x] 对话文件拆 pre/post → Task 4, 5
- [x] `serve_result` 变量写入 → Task 3
- [x] 重要 NPC 耐心暂停 → 现有 `_isDialogueActive` 机制覆盖
- [x] 普通客人不受影响 → Task 3 (isImportant 判断跳过 post 流程)

**2. Placeholder scan:** No TBD/TODO/incomplete sections.

**3. Type consistency:**
- `_dialoguePhase` is `string` (`"pre"` / `"post"` / `null`) — consistent across all tasks ✓
- `ServeResult` variable name `"serve_result"` — consistent across Task 3/4/5 ✓
- `SetDialogueMode(bool)` — consistent across Task 1/2/3 ✓
