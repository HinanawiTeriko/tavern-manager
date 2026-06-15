# 米拉旧账：普通客人流言与推断链设计

Date: 2026-06-16
Status: design draft approved in chat, awaiting implementation plan
Scope: Mira/Toby middle-route completion between Day6 and Day12

## Goal

米拉线现在的问题不是结局逻辑缺失，而是中段体验太空。系统已经能判断她是否回头、托比是否活下来，但玩家没有足够过程去理解米拉为什么逃避、托比为什么会学着一个人硬走。

本设计补的是 Day6 到 Day12 之间的 playable bridge：

- 普通客人在经营过程中自然露出流言。
- 流言关键词自动摘录成推断线索，不出现夜晚额外按钮。
- 玩家通过推断发现：托比不是单纯逞强，他在模仿米拉当年教给他的生存方式。
- 这个发现反过来强化米拉货摊、委托书递交、Day12 结局文本的情绪支撑。

第一版目标是让米拉线“不空”，不是重写整条结局判定。

## Current Fit

已有系统已经提供了足够骨架：

- `InferenceSystem` 和 `CleanTableInferenceScreen` 可以承载填空推断。
- Day6 告示板提供托比名字、黑齿矿脉护送、高额报酬等线索。
- Day6 夜晚托比上菜后提供后巷少年、一个人走才轻快等线索。
- `toby_identity_known` 解锁托比住处。
- `toby_commission_lead` 解锁掮客路线。
- `toby_contract` 是能递给米拉的关键物证。
- `mira_stall` 已经能通过反复拜访提高米拉信任。
- Day12 的 `finalize_mira_ending()` 已经根据真相、信任和掮客兜底给出路线。

新设计只扩展中段线索来源和推断链。除非后续实现计划明确说明，不改现有结局变量的含义。

## Player Experience

玩家不需要专门“打听”按钮，也不需要晚上多出一个突兀交互。

玩家正常经营酒馆。普通客人正确上菜后，如果当前剧情条件满足，客人的成功反应后面会夹一句闲聊。闲聊里的关键词用和推断系统一致的特殊颜色标记。系统自动把对应词语摘录进推断面板的左侧词语区。

例子：

```text
客人：以前有个女商人，总带着个小孩跑货。
客人：那孩子学她说话，老念叨一个人走才轻快。
客人：米拉最近像是要签长期供应协议，以后不接零散路活了。
```

表现规则：

- 流言只附着在普通客人成功上菜反馈里。
- 不给普通客人加对话选择。
- 不给晚上加按钮。
- 不要求玩家点击高亮词，线索自动摘录。
- 如果玩家错过某晚，后续普通客人仍可补一条关键流言，避免一次失误永久断线。
- 每晚最多露出一条米拉旧账流言，避免经营反馈被剧情刷屏。

## Story Arc

### Day6: 托比危险成立

告示板和托比夜晚上菜构成现有第一层推断。玩家知道：

- 告示上有托比这个陌生名字。
- 夜晚来的少年也提到黑齿矿脉。
- 他相信“一个人走才轻快”。

此时只能推出托比是谁、委托危险。还不能直接推出米拉责任。

### Day7-Day8: 普通客人露出旧关系

普通客人闲聊开始提供不完整流言：

- 以前有个女商人带着孩子跑货。
- 那孩子不是亲人，像学徒，也像被临时收留的人。
- 孩子总学女商人的口气，说路上别拖累别人。

这些流言让玩家开始怀疑托比和某个商人有旧关系，但不直接点破米拉。

### Day8-Day10: 米拉货摊产生回响

玩家去 `mira_stall` 时，根据已收集线索改变文本：

- 没线索：米拉只是普通收摊、提高信任。
- 有“带孩子跑货”流言：米拉听到“孩子”或“旧路”时停顿。
- 有“一个人走才轻快”线索：米拉明显回避这句话。
- 已完成旧关系推断：货摊文本承认她认识这个句子的来处，但仍不愿谈。

这部分不直接解救托比。它让米拉从“普通可刷好感 NPC”变成正在躲避某件事的人。

### Day10-Day11: 推断把责任钉住

玩家在打烊后的推断桌上可以完成米拉旧账推断。

核心结论：

```text
托比相信一个人走才轻快，是因为他曾经从米拉那里学会了这句话。
```

推断成功后：

- 设置 `mira_toby_link_known`。
- 设置 `mira_responsibility_lead`。
- 账本增加一条简短命运笔记。
- `mira_stall` 后续文本升级为更强的对峙。

第一版不把这个 flag 作为托比生死硬门槛。它服务于叙事表达和 Day12 文本分支。等试玩确认后，再决定是否把最佳米拉结局要求收紧到“真相 + 信任 + 旧账推断”。

### Day12: 结局获得因果重量

Day12 保持现有四类结果，但文本更有支撑：

- 没查旧账：米拉更像蒙在鼓里或选择不问。
- 查出旧账但信任不足：她知道这句话来自自己，却仍签下协议，残酷感更强。
- 查出旧账、给她看委托书、信任够：她停下不只是因为托比危险，而是承认自己不能第二次把同一个孩子丢在路上。
- 掮客兜底：托比活，但米拉不会知道玩家替她合上了哪扇门。

## New Clues

新增线索应放进 `data/inference_puzzles.json` 的 `clues` 区域。来源文案使用“酒馆流言”或“米拉货摊”，不要把普通客人名字写死成唯一来源。

| Clue id | Label | Source | Purpose |
| --- | --- | --- | --- |
| `mira_traveling_mentor` | 米拉带过一个孩子跑货 | 酒馆流言 | 暗示米拉曾带过托比 |
| `child_learned_saying` | 学她说一个人走才轻快 | 酒馆流言 | 把托比口头禅和旧商人联系起来 |
| `mira_avoids_old_road` | 米拉避开那条旧路 | 米拉货摊 | 明确米拉对旧路有反应 |
| `supply_agreement_escape` | 长期供应协议 | 米拉货摊 | 支撑她想彻底摆脱路上牵挂 |
| `mira_name_on_contract` | 委托书边上的米拉 | 托比委托书 | 把物证和米拉连接 |

可复用现有线索：

- `toby_name`
- `back_alley_boy`
- `one_person_walk`
- `blacktooth_escort`
- `high_pay_trap`

## New Inference Questions

### `mira_toby_old_relation`

Purpose: 先让玩家把“旧商人和孩子”对上托比。

Requirement:

- `mira_traveling_mentor`
- `toby_name`
- solved `toby_identity`

Sentence:

```text
______，也许就是告示上的 ______。
```

Blanks:

- `past`: `mira_traveling_mentor`
- `name`: `toby_name`

Conclusion:

```text
夜里的少年不是第一次学着大人赶路。有人曾经带他跑货，又把“一个人走”的道理留给了他。
```

Unlock:

- `mira_toby_link_known`

### `mira_phrase_origin`

Purpose: 把托比的危险选择归因到米拉的旧影响。

Requirement:

- `one_person_walk`
- `child_learned_saying`
- `mira_traveling_mentor`
- solved `mira_toby_old_relation`

Sentence:

```text
托比相信 ______，是因为他曾经跟着 ______ 学会了这句话。
```

Blanks:

- `saying`: `one_person_walk`
- `source`: `mira_traveling_mentor`

Conclusion:

```text
托比接下黑齿矿脉，不只是为了钱。他是在按米拉当年留下的办法证明自己能一个人走。
```

Unlock:

- `mira_responsibility_lead`

### `mira_escape_contract`

Purpose: 把 Day12 的长期供应协议和她的逃避动机接起来。

Requirement:

- `supply_agreement_escape`
- `mira_name_on_contract`
- solved `mira_phrase_origin`

Sentence:

```text
米拉想签下 ______，也许是为了不再回头看 ______。
```

Blanks:

- `deal`: `supply_agreement_escape`
- `past`: `mira_name_on_contract`

Conclusion:

```text
这份协议不是单纯的好生意。它也是米拉给自己找的一条不用再回头的路。
```

Unlock:

- `mira_escape_understood`

First implementation can skip this third question if scope is too large. The first two are the core.

## Tavern Gossip Source

第一版可以做成小而硬的规则，不需要立即建立通用任务系统。

Trigger conditions:

- 当前是 Day7-Day11。
- 当前客人是普通客人，不是重要 NPC。
- 玩家正确上菜。
- 当前剧情已至少知道托比危险，或已经遇见过 Day6 夜晚托比。
- 当晚还没有露出米拉旧账流言。
- 该流言对应 clue 尚未被收集。

Selection order:

1. 如果没有 `mira_traveling_mentor`，优先露出米拉曾带孩子跑货。
2. 如果已有 `one_person_walk` 但没有 `child_learned_saying`，露出孩子学那句话。
3. 如果玩家拜访过米拉货摊但没有 `supply_agreement_escape`，露出长期供应协议。
4. 如果已找到 `toby_contract` 但没有 `mira_name_on_contract`，从委托书或递交前观察里补。

Output:

- 追加一条普通客人成功反馈文本。
- 高亮关键词。
- 调用推断系统加入 clue。
- 账本写短句，例如“今晚有人提起带孩子跑货的女商人。”
- 播放现有 `new_document` 或更轻的摘录反馈音效。

这套规则后续可以抽成 `data/gossip_clues.json`，但第一版不强求。先把米拉线跑顺比提前做通用框架更重要。

## UI Rules

普通客人流言必须保持低摩擦：

- 不新增夜晚按钮。
- 不新增普通客人对话树。
- 不中断上菜流程。
- 不把线索做成需要点击的 UI 小物件。
- 流言关键词使用统一高亮色，和推断词语一致。
- 摘录反馈要明显但短：可以是词语飞入、账本轻响、或屏幕角落一行“已摘录线索”。
- 如果当前 UI 无法安全支持富文本高亮，第一版允许整句普通颜色显示，但必须在推断词语区有明确新增反馈。

## Mira Stall Changes

`mira_stall` 仍然是地图地点，不改 id。

新增状态化文本：

- No clue: 原有陪聊和信任提升。
- Has `mira_traveling_mentor`: 米拉对“带孩子跑货”的说法转移话题。
- Has `one_person_walk`: 米拉对这句话有明显停顿。
- Has `mira_toby_link_known`: 米拉承认她以前带过一个孩子，但不承认自己欠他。
- Has `mira_responsibility_lead`: 米拉货摊文本进入对峙，给 Day12 真相递交铺垫。

反复拜访仍然可以提高 `aff_mira`，但每一天只加一次信任，沿用现有防重复逻辑。

## Route Impact

第一版路线判定保持稳定：

- 托比存活仍由“米拉担责”或“掮客兜底”决定。
- 米拉担责仍主要由 `told_mira_truth`、`toby_contract_found`、`aff_mira >= MIRA_TRUST_THRESHOLD` 决定。
- 新 flag 先影响文本、账本和玩家理解，不强行改变生死判定。

可选二阶段：

- 若试玩发现玩家仍然觉得米拉突然回头，可以把最佳路线收紧为：`told_mira_truth && toby_contract_found && aff_mira >= threshold && mira_responsibility_lead`。
- 收紧前必须更新 route matrix 测试和玩家提示，避免旧存档或旧流程突然断掉。

## Files Expected To Change Later

Implementation should stay bounded to these areas unless tests expose a tighter need:

- `data/inference_puzzles.json`: add Mira clues and questions.
- `scripts/systems/inference_system.gd`: only if existing question format cannot express the needed clue requirements.
- `scripts/game_manager.gd`: collect tavern gossip clues after ordinary successful service; apply new inference flags; update Mira stall messages.
- `scripts/systems/narrative_manager.gd`: initialize new flags if they become narrative vars.
- `data/guest_reactions.json`: optional, if gossip text should live in data rather than code.
- `scripts/test/test_inference_system.gd`: cover new clue/question logic.
- `scripts/test/test_mira_toby_route_matrix.gd`: ensure old route outcomes remain stable.
- `scripts/test/test_tavern_patience_ui.gd` or a focused service test: verify ordinary guest success can emit a gossip clue without adding UI buttons.
- `scripts/test/test_clean_table_inference.gd`: only if new clue/question count or visual feedback changes the screen contract.

Do not edit scene files for the first logic pass unless a UI test proves they are needed.

## Testing

Required tests:

1. Inference data loads with new Mira clues.
2. `mira_toby_old_relation` is unavailable until the required Toby and gossip clues exist.
3. Solving `mira_toby_old_relation` unlocks `mira_toby_link_known`.
4. `mira_phrase_origin` requires the old-relation solve and relevant phrase clues.
5. Solving `mira_phrase_origin` unlocks `mira_responsibility_lead`.
6. Ordinary customer success can grant one eligible gossip clue.
7. Failed, wrong, weird, or abandoned service does not grant gossip.
8. A night grants at most one Mira old-ledger gossip clue.
9. No new night button is introduced.
10. Existing Toby identity and commission-risk inference still works.
11. Existing route matrix outcomes still pass when the new Mira flags are absent.
12. Existing truth-plus-trust route still saves Toby unless the second-phase gate is explicitly approved.

Manual playtest:

- Day6 board + night Toby creates the first Toby deductions.
- Day7-Day9 normal service produces at least two old-ledger clues without special UI.
- Clean-table screen makes the new deductions understandable.
- Mira stall text visibly changes after the player knows the old relation.
- Day12 text feels like it pays off the middle clues.

## Non-Goals

- Do not add a new physical investigation scene for米拉 in this pass.
- Do not redesign `CleanTableInferenceScreen`.
- Do not rebuild the ledger UI.
- Do not create a universal quest/journal system.
- Do not change ordinary guests into dialogue NPCs.
- Do not add visible “打听” buttons at night.
- Do not require all new clues to come from托比 himself.
- Do not rewrite Day12 ending art or settlement presentation in this pass.

## Open Decisions Before Implementation

1. Whether `mira_escape_contract` ships in the first pass or waits until the first two推断题 are playable.
2. Whether gossip text lives in `data/guest_reactions.json`, a new `data/gossip_clues.json`, or a small GameManager table for the first implementation.
3. Whether new flags remain text-only or become part of the best-ending requirement after playtest.

Recommended first pass:

- Ship `mira_traveling_mentor`, `child_learned_saying`, `mira_avoids_old_road`.
- Ship two questions: `mira_toby_old_relation`, `mira_phrase_origin`.
- Keep route outcomes unchanged.
- Use ordinary service success as the only tavern gossip trigger.
