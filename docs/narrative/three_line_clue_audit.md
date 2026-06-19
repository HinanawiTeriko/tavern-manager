# 三人物线线索审计表

日期：2026-06-18

## 目的

这份文档先整理现状，不直接要求改代码。目标是把 Ryan、Mira/Toby、Evelyn 三条人物线的线索来源、推断事实、经营代价和结算后果拆清楚，降低后续改剧情时的混乱度。

当前最大问题不是“剧情内容不够”，而是玩家很难判断同一类信息应该从哪里来：

- 普通顾客有时像传闻来源，有时像核心线索来源。
- 重要 NPC 有时讲动机，有时直接讲事实。
- 物理调查有时给硬证据，有时 DayMap 地点直接发文档。
- 推断题已经有清晰结论链，但线索来源标签不稳定。
- 经营系统会影响金币、声望和部分信任，但这些影响很少被明确翻译成剧情压力。

## 线索宪法

后续所有剧情内容先按这六类归位。

| 类别 | 作用 | 推荐来源 | 不应该做什么 |
|---|---|---|---|
| 风声 | 告诉玩家哪里有事、今晚谁可能开口、该准备什么菜单 | 普通顾客、传闻、DayMap 传闻、客群口碑 | 不直接证明核心真相 |
| 人心 | 呈现人物动机、恐惧、逃避、信任变化 | 重要 NPC 对话、上菜反应、递交剧情物品反馈 | 不替调查和推断讲完整案情 |
| 证据 | 可被账本/推断引用的硬物或记录 | 物理调查场景、文档、合同、账页、批次号 | 不靠普通顾客口头给出 |
| 事实 | 玩家已经把证据/风声拼成可用结论 | 推断题结论和 unlock flag | 不从单句对话直接跳出 |
| 代价 | 玩家为了让事实产生作用付出的经营/金钱/信任成本 | 上菜质量、上菜风格、菜单准备、香料/药粉、掮客花费 | 不只是变量开关，要能在经营反馈里看见 |
| 后果 | 命运、账本、次日地图、供应和客群变化 | Ledger、fate note、结局变量、DayMap 状态 | 不只藏在对话变量里 |

简写：

`普通顾客 = 风声`

`重要 NPC = 人心`

`物理调查 = 证据`

`推断题 = 事实`

`酒馆经营 = 代价`

`Ledger/次日 = 后果`

## 现有系统可保留的骨架

这些不是问题，应当保留并围绕它们整理。

| 骨架 | 当前位置 | 价值 |
|---|---|---|
| 推断题结论链 | `data/inference_puzzles.json` | Toby -> Mira -> Grey Ledger 的事实链已经比较完整。 |
| 物理调查授予文档入口 | `GameManager.grant_investigation_document()` | View 不直接改系统，适合继续作为证据入口。 |
| 剧情物品递交中介 | `GameManager.request_narrative_delivery()` | Ryan 与 Mira 的剧情递交已经通过统一入口处理。 |
| 重要 NPC 信任阈门 | `NarrativeManager.resolve_serve_style()`、`get_mira_route()` | 上菜风格和信任已经能影响人物线。 |
| Evelyn 读取活证人压力 | `NarrativeManager.get_evelyn_pressure()` | Ryan/Mira/Toby 结局已经能影响 Evelyn 结局重量。 |
| Ledger fate track | `DocumentSystem` 经 `GameManager._add_fate_note()` | 后果记录已有承载界面，不需要新建一套日志。 |

## 全局混乱点

| 问题 | 现状 | 改法 |
|---|---|---|
| 普通顾客线索太像事实 | `GameManager._try_grant_mira_old_ledger_gossip()` 在普通客人成功服务后直接给 `mira_traveling_mentor`、`child_learned_saying`。 | 保留为“风声”，但 UI/文案要明确“听说/有人说”。它只能开启推断，不直接等于事实。 |
| 重要 NPC 说太多案情 | Toby、Mira、Evelyn 的 pre 对话有时直接把风险和结构说出来。 | 重要 NPC 的话保留情绪、逃避和选择压力；事实判断交给推断题。 |
| 证据来源不一致 | Ryan/Toby 有物理调查场景；Evelyn 部分证据来自 DayMap 地点直接授予，部分来自清算台物理调查。 | 长期目标是证据都来自“调查动作”。短期先在文档中标清哪些是硬证据，哪些只是地点访问文档。 |
| 经营结果没有稳定回剧情 | 普通上菜主要给金币/声望/口味反应，剧情线只接了少数特例。 | 不急着做大系统，先让每条人物线有一个经营代价：Ryan 信任、Mira 供应/信任、Evelyn 证人/公开压力。 |
| 旧对话和新中介并存 | 部分 `.dialogue` 里仍有直接 `set` 变量的旧逻辑，如 Ryan 旧主对话里直接设置 `aff_ryan`/`ryan_drugged`。 | 后续应确认运行时到底使用 pre/post 还是旧主文件。旧主文件若不再是业务真源，应标注或迁移，避免误读。 |

## Ryan 线审计

### 当前主题

Ryan 线的核心不是“解谜”，而是“信任与选择成本”。它适合做早期教学线：玩家先听见一个人的愿望，再找到委托证据，最后决定是告知、替代、下药，还是放任。

### 当前线索表

| 内容 | 当前来源 | 应归类为 | 现状判断 | 建议 |
|---|---|---|---|---|
| Ryan 想加入白银阶、赚钱供妹妹 | `ryan_day1.pre.dialogue`、`ryan_day1.dialogue` | 人心 | 保留。动机清楚。 | 不要把它变成推断题；这是玩家理解选择代价的情感基础。 |
| 血斧小队北矿道委托 | `ryan_day1.post.dialogue` 设置 `ryan_warhammer_lead`，DayMap 告示板读取该 lead | 人心 -> 风声/入口 | 基本合理。Ryan 提到意向，告示板确认委托入口。 | 文案上区分：Ryan 说“我要去”，告示板说“确有这份委托”。 |
| 矿口今晚需要顶饿热食 | `rumors.json` 的 `mercenary_board_mine_shift` | 风声 | 保留。它服务菜单/客群，不是核心证据。 | 不要让这条传闻承载“委托有诈”。 |
| 染血委托书 | `abandoned_mine` 物理调查 `MineInvestigation` 授予 `bloodied_contract` | 证据 | 保留。来源清楚。 | 这是 Ryan 线硬证据真源。 |
| 替代委托书 | `guild_counter` 在读过 `bloodied_contract` 后给 `alternative_contract` | 证据/代价工具 | 保留。它是选择工具，不是单纯线索。 | 建议在剧情说明中强调“替代委托 = 给 Ryan 一条代价更低但前程更慢的路”。 |
| 沉睡花粉 | `market_shop` gossip + `mushroom_forest` day reward + SeasoningShaker | 代价工具 | 保留，但现在像特例。 | 后续应让使用药粉产生经营侧后果，例如部分顾客/账本记录对酒馆信任下降。 |
| 递交染血委托 | `request_narrative_delivery()` -> `NarrativeManager._resolve_ryan_story_item_action()` | 事实作用于人心 | 保留。 | 递交不是找线索，而是把证据带给当事人。 |
| 递交替代委托后等待信任结算 | `ryan_alternative_pending` + 上菜风格/信任 | 代价 | 很好，是经营接剧情的关键点。 | UI/账本应更明确“Ryan 会看你今晚怎么待他”。 |
| Ryan 结局 | `get_ryan_route()`、Day3 fate reveal、Ledger fate track | 后果 | 保留。 | 建议让后续 Evelyn 线更早提示“活着的 Ryan 会增加公开账重量”。 |

### Ryan 线整理结论

Ryan 线不需要强行补推断题。它可以作为“证据递交 + 经营信任 + 道德代价”的教学线。

需要改的是：

1. 明确 `bloodied_contract` 是唯一硬证据。
2. `sleep_powder` 不只是剧情捷径，要带经营/声誉代价。
3. 旧 `.dialogue` 中直接 `set ryan_drugged`、`set aff_ryan = 10` 的逻辑需要确认是否仍参与运行；如果不参与，应标注为 legacy，避免后续写剧情时误读。

## Mira/Toby 线审计

### 当前主题

Mira/Toby 线的核心是“供应链与责任”。它应该把酒馆经营、香料/商路、旧路客、Toby 的危险委托、Mira 的逃避连接起来。

### 当前线索表

| 内容 | 当前来源 | 应归类为 | 现状判断 | 建议 |
|---|---|---|---|---|
| Mira 年轻时带人走北方山路 | `mira_day4.pre.dialogue` | 人心 | 保留，但信息量偏大。 | 可以保留为她的价值观，不要让玩家在这里就完成“托比关联”的证明。 |
| “一个人走才轻快” | Mira Day4、Toby Day6、推断线索 `one_person_walk`/`child_learned_saying` | 人心 -> 风声 -> 事实 | 这是当前最核心但也最容易混乱的线索。 | 规定：NPC 说这句话是人心；普通客人说“孩子学她说”是风声；推断题才确认它是伤口来源。 |
| Toby 姓名和黑齿委托 | 告示板 posting `toby_commission`，推断线索 `toby_name`、`blacktooth_escort`、`high_pay_trap` | 风声/入口 | 保留。告示板适合作入口。 | 告示板不应直接给 `toby_contract`；当前已搬到物理调查，这是对的。 |
| 后巷少年身份 | Toby Day6 pre 对话，`_collect_toby_day6_night_clues()` 给 `back_alley_boy`、`one_person_walk` | 人心 | 保留，但来源标签应改。 | `inference_puzzles.json` 里 source 写“夜晚客人”，建议改成“托比对话”或“瘦小少年”。 |
| 米拉旧日带孩子跑货 | 普通客人成功服务后 `_try_grant_mira_old_ledger_gossip()` 给 `mira_traveling_mentor` | 风声 | 可以保留，但应更透明。 | 应优先由旧路客/账房客/商路客触发，而不是任何普通客人都可能说。 |
| 孩子学她说话 | 同上，给 `child_learned_saying` | 风声 | 可以保留。 | 这条不能等于事实；推断题 `mira_phrase_origin` 才确认。 |
| Mira 避开旧路 | `mira_stall` 根据已有线索给 `mira_avoids_old_road` | 人心 | 保留。这个来源合理。 | 它是 Mira 的回避反应，不是合同证据。 |
| Toby 合同 | `TobyLodgingInvestigation` 拼合后授予 `toby_contract` | 证据 | 保留。来源清楚。 | 这是 Mira/Toby 线硬证据真源。 |
| Toby 身份/委托风险/旧关系/责任 | `inference_puzzles.json` 四道题 | 事实 | 保留。链条清楚。 | 每道题的 unlock flag 是事实真源，不应由对话直接替代。 |
| 递交 Toby 合同给 Mira | `request_narrative_delivery()` -> `_resolve_mira_story_item_action()` | 事实作用于人心 | 保留。 | 递交后根据信任分 trusted/guarded 很好。 |
| 访问 Mira 货摊加好感 | `locations.json` 的 `mira_stall.affection` + `MIRA_RESPONSIBILITY_STALL_BONUS` | 代价 | 保留，但玩家可能看不懂。 | 需要 Ledger 或 UI 提醒“你和 Mira 的关系足以/不足以让她回头”。 |
| 掮客兜底 | `fixer_den` 花 40 金设置 `toby_secured_by_fixer` | 代价 | 保留。它是经营资源换命运。 | 应明确这是“不经 Mira 的解决”，对应 Mira 结局 `closed_the_door`。 |
| Day12 Mira/Toby 命运 | `finalize_mira_ending()` | 后果 | 保留。 | 应在 Ledger 里明确：Mira 担责、掮客兜底、未干预是三种不同经营/剧情路径。 |

### Mira/Toby 线整理结论

这条线素材最多，也最需要来源秩序。建议先定死四个真源：

1. `toby_contract` 是硬证据。
2. `mira_phrase_origin` 推断题是“责任事实”的真源。
3. Mira 好感/信任是经营代价的真源。
4. `toby_secured_by_fixer` 是金钱代价兜底的真源。

普通顾客和传闻只负责把玩家引向这些真源，不直接宣布真相。

## Evelyn/Grey Ledger 线审计

### 当前主题

Evelyn 线的核心是“账本、公开事实和活证人”。这条线天然适合收束前两条线：Ryan 和 Toby/Mira 的命运不仅是个人结局，也是 Grey Ledger 是否能被公开的重量。

### 当前线索表

| 内容 | 当前来源 | 应归类为 | 现状判断 | 建议 |
|---|---|---|---|---|
| 赔付比讣告更早 | `evelyn_day5.pre.dialogue` | 人心/风声 | 保留。它是主题预告。 | 不要让它直接给证据。 |
| 黑齿批次格式像旧账 | `evelyn_day8.pre.dialogue` | 人心/风声 | 保留但接近事实。 | 建议作为 Evelyn 的职业嗅觉，不作为硬结论。 |
| 去赔付登记处查顺序 | `evelyn_day13.pre.dialogue` | 入口指引 | 保留。很清楚。 | 这是重要 NPC 给调查入口的好例子。 |
| 莱恩案卷编号、旧赔付登记、缺页名单 | `payout_office` 直接授予文档 | 证据 | 保留，但来源形式偏轻。 | 长期可改成小调查；短期在叙事上承认这是“抄录证据”。 |
| 黑齿批次号、灰契封账办法 | `blacktooth_ledger` 直接授予文档 | 证据 | 保留。 | 同上，短期可接受，长期可调查化。 |
| 赔付即结案、被改名的护送委托、供应协议灰印 | `ClearingTableInvestigation` 物理调查授予 | 证据 | 很好，应保留。 | 这是 Evelyn 线最强的“物理调查 -> 证据”范例。 |
| 同批灰账、赔付顺序、米拉供应灰印、公开账本 | `inference_puzzles.json` 后四题 | 事实 | 保留。链条清楚。 | 这些 unlock flags 是 Grey Ledger 事实真源。 |
| Day20 证据缺口提示 | `EVELYN_PUBLIC_ACCOUNT_GAPS` + `evelyn_day20.post.dialogue` | 后果/引导 | 保留。 | 这是很好的“系统告诉玩家缺哪块”的结构。 |
| Ryan/Mira/Toby 活证人压力 | `get_evelyn_pressure()` 读取前两条线结局 | 后果 | 保留，甚至应强化。 | 这是三线真正融合的关键，不要删。 |
| sealed/amended/public 三结局 | `get_evelyn_route()` | 后果 | 保留。 | 需要确保玩家知道 amended 与 public 的差异来自“证据完整度”。 |

### Evelyn 线整理结论

Evelyn 线其实是三条线里最接近“融合”的：它已经读取 Ryan 和 Toby/Mira 的结果，并用活证人改变结局语气。问题是前置线索来源太杂，导致玩家到 Day20 时可能不知道自己缺的为什么是这些。

后续应做两件事：

1. 把前置缺口提示提前分散到 Ledger/DayMap，而不是只在 Day20 才集中说。
2. 让每个 Grey evidence 都明确对应一个调查动作或抄录动作，避免“地点点一下就给核心证据”的轻飘感。

## 普通顾客和传闻的边界

普通顾客不是不能给线索，但只能给“风声”。

允许：

- “账房的人今晚在核对旧赔付顺序。”
- “旧路人听过一个女商人带孩子跑货。”
- “香料行最近对北方货路压价。”
- “黑齿矿脉那张委托报酬高得不像正经活。”

不允许：

- “Mira 就是害 Toby 接委托的人。”
- “Grey Ledger 会先赔付再结案。”
- “Ryan 和 Toby 是同批灰账。”
- “供应协议背面有同一枚灰契印。”

普通顾客的最好用法：

| 顾客类型 | 应给什么 | 应影响什么 |
|---|---|---|
| 旧路客 | 旧路、Mira、Toby 过去的风声 | 开启 Mira/Toby 推断题线索 |
| 账房客 | 赔付顺序、账本异常、审核风向 | 引导 Evelyn 调查地点 |
| 商路客/香料掮客 | 供应、香料价格、北方货路 | 引导 Mira 线经营压力 |
| 矿口客 | 北矿道、黑齿矿、危险委托 | 引导 Ryan/Toby 风险感 |

## 物理调查和推断题的分工

不要把物理调查和推断题合并。

| 系统 | 职责 | 示例 |
|---|---|---|
| DayMap | 选今天要追哪条风险 | 去告示板、矿道、赔付登记处、米拉货摊 |
| 物理调查 | 让玩家亲手拿到证据 | 挖出染血委托、拼 Toby 合同、压出灰契印 |
| 推断题 | 把证据/风声变成事实 | Toby 是后巷少年、同批灰账、公开账本 |
| 酒馆经营 | 让事实产生代价 | 服务建立信任、花钱找掮客、下药救人但伤信任 |
| Ledger | 告诉玩家事实造成了什么后果 | 命运轨、缺口提示、结局重量 |

## 低风险改造顺序

不要先重写剧情。按这个顺序改，风险最低。

### 第 1 步：只改文案标签和文档，不改逻辑

- 把 `inference_puzzles.json` 的 source 标签整理成风声/人心/证据，而不是“夜晚客人/酒馆流言”混用。
- 给文档加一页“线索宪法”或在设计文档里引用本审计。
- 标注旧 `.dialogue` 文件中不再作为业务真源的变量写入。

### 第 2 步：修普通顾客线索发放

- `_try_grant_mira_old_ledger_gossip()` 不应像全局随机补线索。
- 改成只在旧路客/账房客/商路客满意时触发相应风声。
- 仍然只给风声线索，不直接给事实。

### 第 3 步：每条线补一个经营代价反馈

- Ryan：使用沉睡花粉后，Ledger 或顾客反应记录“酒馆被怀疑操控客人”。
- Mira/Toby：Mira 信任不足时，Ledger 明确提示“证据到了，但她不信任你到愿意回头”。
- Evelyn：Day20 前 Ledger 提前显示“公开账本缺口”，不要只等最终对话。

### 第 4 步：再决定是否把 Grey 证据调查化

- `payout_office`、`blacktooth_ledger` 当前直接授予文档，短期可保留。
- 如果要增强物理感，再做小调查场景；不要和前 3 步混在一起。

### 第 5 步：最后才扩内容

只有当上面的来源秩序稳定后，再加新香料、新传闻、新顾客、新调查题。否则新增内容会继续加重割裂感。

## 推荐第一张实施切片

如果只选一个切片落地，推荐改 **Mira/Toby 线普通顾客风声**。

原因：

- 它正好暴露当前最大混乱点：普通顾客线索来源不清。
- 它不需要改结局系统。
- 它能让经营系统第一次明确服务剧情：服务旧路客/账房客 -> 得风声 -> 开推断 -> 影响 Mira/Toby。
- 它不会破坏 Ryan 的早期教学线，也不会动 Evelyn 的大结局。

最小目标：

1. 普通顾客满意时，只由相关客群给相应风声。
2. 风声只开启推断题，不直接证明事实。
3. Ledger 记录“今晚听到某类风声”，而不是直接写成命运事实。

## 最后判断

现有剧情不是完全不能救，反而已经有很多正确零件：

- Ryan 有清晰选择代价。
- Mira/Toby 有完整推断链。
- Evelyn 能收束前两条线。
- 物理调查已经能产出证据。
- Ledger 已经能记录后果。

需要改的是“信息秩序”，不是推倒重来。

后续所有剧情改动先问一句：

这条内容是在给风声、人心、证据、事实、代价，还是后果？

如果回答不出来，就先不要写进游戏。
