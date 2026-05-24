# 对话-售卖联动重设计

## 目标

将重要 NPC 的对话与合成上菜流程打通：NPC 到访 → pre 对话（点单） → 合成上菜 → post 对话（反应+宿命）。

## 当前问题

- 对话和售卖完全脱节：NPC 到访立即播对话，对话内容已包含"上菜反馈"，但实际播放时玩家还没开始合成
- 上菜结果不触发任何后续对话
- 对话变量（如 `ryan_ending`）依赖对话内的选项，而非实际的上菜成功/失败

## 新流程

```
重要NPC到访
  │
  ▼
┌──────────────────────┐
│ Pre 对话（专属 UI）     │  TavernView.SetDialogueMode(true)
│ 合成区隐藏/变暗         │  → 合成区变暗不可操作
│ 显示 NPC + 对话框      │  → NPC 区域高亮
│ NPC 寒暄 + 点单         │
└──────────────────────┘
  │ 对话结束 (DialogueEnded)
  ▼
┌──────────────────────┐
│ 合成上菜（正常 UI）     │  TavernView.SetDialogueMode(false)
│ 玩家制作 + 提交         │  → 合成区恢复
└──────────────────────┘
  │ 上菜完成 (ServeRequested)
  ▼
┌──────────────────────┐
│ Post 对话（专属 UI）    │  TavernView.SetDialogueMode(true)
│ 根据 serve_result 分支 │  → 合成区再次变暗
│ NPC 反应 + 变量写入     │
└──────────────────────┘
  │ 对话结束 (DialogueEnded)
  ▼
客人离开，恢复正常营业
```

## 对话文件结构

每个 NPC 每天拆成两个文件：

| 文件 | 用途 | 示例 |
|------|------|------|
| `{npc}_day{N}.pre.dialogue` | NPC 寒暄 + 点单说明 | 莱恩: "老板，来份黑面包！" |
| `{npc}_day{N}.post.dialogue` | 根据上菜结果分支 | `if serve_result == "success"` → 满意离开; `else` → 失望 |

**变量约定：**
- `serve_result`：GameManager 在上菜后写入 `"success"` 或 `"fail"` 到 `Narrative.DialogueVars`
- 所有现有变量（`aff_*`, `*_ending`, `*_drugged`）保持不变

## 代码改动

### GameManager

| 改动 | 说明 |
|------|------|
| `OnGuestArrived` | 改为加载 `{npc}_day{N}.pre.dialogue`，不再加载原文件 |
| `DialogueEnded` 回调 | 判断当前阶段（pre/post），pre 结束后恢复合成 UI；post 结束后 `Guests.ClearGuest()` |
| `ServeRequested` | 上菜后写 `serve_result` 变量，加载并播放 `{npc}_day{N}.post.dialogue` |
| 新增 `_dialoguePhase` 字段 | 追踪当前是 pre 还是 post（`string` 或 `enum`） |

### TavernView

| 改动 | 说明 |
|------|------|
| 新增 `SetDialogueMode(bool active)` | active=true：合成区变暗/不可交互，NPC 区域保持可见；active=false：恢复正常 |

### GuestSystem

| 改动 | 说明 |
|------|------|
| 重要 NPC 耐心倒计时 | Pre 对话期间暂停（已有 `_isDialogueActive` 机制），Post 对话结束后 `ClearGuest()` 统一清理 |

### 对话文件迁移

| 旧文件 | 新文件 |
|------|------|
| `ryan_day1.dialogue` | `ryan_day1.pre.dialogue` + `ryan_day1.post.dialogue` |
| `ryan_day2.dialogue` | `ryan_day2.pre.dialogue` + `ryan_day2.post.dialogue` |
| `ryan_day3.dialogue` | `ryan_day3.pre.dialogue` + `ryan_day3.post.dialogue` |
| `mira_day4.dialogue` | `mira_day4.pre.dialogue` + `mira_day4.post.dialogue` |
| `mira_day12.dialogue` | `mira_day12.pre.dialogue` + `mira_day12.post.dialogue` |

旧文件保留不删，pre/post 为新建文件。

## 边界情况

- **无 post 文件的 NPC**：如果 post 文件加载失败，跳过 post 对话阶段，直接清除客人
- **连续快速上菜**：ServeRequested 期间如果已有对话进行中，不重复触发
- **非重要 NPC**：普通客人不受影响，按原流程（无对话，只有合成上菜）
- **Pre 对话期间暂停**：耐心倒计时暂停（现有 `_isDialogueActive` 机制覆盖）
