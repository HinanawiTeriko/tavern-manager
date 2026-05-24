# 账本系统 (Ledger System) 设计文档

> 日期: 2026-05-24 | 状态: 已确认

---

## 目标

每天打烊时弹出全屏账本面板，展示当日营收摘要和重要 NPC 的宿命记录。玩家手动关闭后进入下一天。

## 架构

**新文件:**

| 文件 | 职责 |
|------|------|
| `scripts/ui/LedgerScreen.cs` | 账本 UI 逻辑，接收 LedgerData 并渲染 |
| `scenes/ui/LedgerScreen.tscn` | 账本场景，羊皮纸古卷风格 |

**修改文件:**

| 文件 | 改动 |
|------|------|
| `scripts/GameManager.cs` | EndNight() 改为先切 Ledger 场景；RegisterView 中连接 LedgerScreen；在 ServeRequested 中记录订单成败 |
| `scripts/systems/EconomySystem.cs` | 新增 GoldToday / RepToday 每日增量 + ResetDaily() |
| `scripts/systems/GuestSystem.cs` | 新增 GuestsServedToday / OrdersSuccess / OrdersFailed + ResetDaily() |
| `scripts/systems/NarrativeManager.cs` | 新增 GetTodayNpcFates(day) 方法，从 DialogueVars 中提取今日 NPC 宿命文本 |

## 数据模型

### LedgerData

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
    public List<NpcFateEntry> NpcFates;
}

public class NpcFateEntry
{
    public string NpcName;   // "莱恩"
    public string NpcTitle;  // "见习骑士"
    public string FateText;  // 从 npcs.json endings 匹配
}
```

### EconomySystem 新增

```csharp
public int GoldToday { get; private set; }
public int RepToday { get; private set; }

public void AddGold(int amount) { Gold += amount; GoldToday += amount; EmitChanged(); }
public void AddReputation(int amount) { Reputation += amount; RepToday += amount; CheckLevelUp(); EmitChanged(); }
public void ResetDaily() { GoldToday = 0; RepToday = 0; }
```

### GuestSystem 新增

```csharp
public int GuestsServedToday { get; private set; }
public int OrdersSuccess { get; private set; }
public int OrdersFailed { get; private set; }

public void RecordOrderSuccess() { OrdersSuccess++; }
public void RecordOrderFailed() { OrdersFailed++; }
public void RecordGuestServed() { GuestsServedToday++; }
public void ResetDaily() { GuestsServedToday = 0; OrdersSuccess = 0; OrdersFailed = 0; }
```

## NPC 宿命文本逻辑

`NarrativeManager.GetTodayNpcFates(int day)`:

1. 遍历 `AllNpcs`，找到今天有 scene 的 NPC（`scene.Day == day`）
2. 检查 `DialogueVars` 中该 NPC 的 ending 变量（如 `ryan_ending`）
3. 如果变量已设置 → 用 `NpcData.Endings[ending_key]` 作为 FateText
4. 如果未设置 → 不显示该 NPC（今天有到访但宿命尚未落定）
5. 今天没有 NPC 到访 → 返回空列表，UI 隐藏"今日宿命"区域

## UI 布局

```
┌─────────────────────── 1280×720 ───────────────────────┐
│                                                          │
│              ╔══════════════════╗                        │
│              ║  第 3 天 · 营业结算 ║    标题 30px 琥珀色     │
│              ╚══════════════════╝                        │
│                                                          │
│   ┌──────────────────────────────────────────────┐      │
│   │  金币收入    +42 金      累计: 156 金          │      │
│   │  声望变化    +3           累计: 18             │      │
│   │  服务客人    4 位                              │      │
│   │  成功订单    3 单                              │      │
│   │  失败订单    1 单                              │      │
│   └──────────────────────────────────────────────┘      │
│                                                          │
│              ═══════ 今日宿命 ═══════                     │
│                                                          │
│   ┌──────────────────────────────────────────────┐      │
│   │  莱恩 · 见习骑士                               │      │
│   │  他为了保护队友，挡住了怪物的攻击……             │      │
│   └──────────────────────────────────────────────┘      │
│                                                          │
│                    ┌──────────┐                          │
│                    │   继 续   │   宽按钮 琥珀色           │
│                    └──────────┘                          │
└──────────────────────────────────────────────────────────┘
```

- 标题: 30px, AmberPrimary
- 数据行: 左标签 TextSubtitle 16px, 右数值 TextLight 16px
- NPC 宿命: 名字+头衔 AmberPrimary 20px, 宿命文本 TextLight 15px
- "今日宿命"分隔仅在今日有 NPC 宿命落定时显示
- 按钮: StyleButton 宽按钮

## 场景流转

```
TitleScreen → DayMap → Tavern → [打烊] → Ledger → [继续] → DayMap (或 EndingScreen)
```

## 数据流

```
夜晚营业中:
  EconomySystem 累计 GoldToday / RepToday
  GuestSystem 累计 GuestsServedToday / OrdersSuccess / OrdersFailed
  GameManager.ServeRequested 中记录订单成败

玩家点"打烊":
  GameManager.EndNight()
    → 验证 Night 阶段 + 无客人
    → 从 EconomySystem / GuestSystem 提取今日数据
    → 调用 NarrativeManager.GetTodayNpcFates(CurrentDay)
    → 构建 LedgerData
    → 调用 EconomySystem.ResetDaily() + GuestSystem.ResetDaily()
    → ChangeScene("LedgerScreen")
    → LedgerScreen._Ready() 渲染

玩家点"继续":
  LedgerScreen 调用 GameManager.DayCycle.NextPhase()
    → DayCycle.NextPhase() 切换 Night→Day
    → PhaseChanged 触发 → GameManager.OnPhaseChanged → 场景切到 DayMap（或 EndingScreen）
```

## 常量

- 场景路径: `res://scenes/ui/LedgerScreen.tscn`
- 宿命区域标题: "今日宿命"
- 无宿命时: 不显示该区域
