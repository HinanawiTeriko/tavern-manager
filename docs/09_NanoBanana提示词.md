# 地下城酒馆 — Nano Banana 生图提示词

> 基于 `docs/07_美术需求文档.md` v2.0 | 2026-05-24
>
> 提示词已适配 Nano Banana 风格。先跑 P0 第一批看效果，确认风格后再批量。

---

## 通用说明

- 每个提示词给出**中英双语**，Nano Banana 建议用中文，英文可做备选
- 如果 Nano Banana 支持 reference image，角色表情变体优先用"参考上一张+改表情描述"方式出
- 所有像素放大（如 200×250 → 400×500）用 nearest-neighbor，不要用双线性或 Lanczos
- 跑完一批后统一拖进 LibreSprite 校色（对照文档色板）

---

## 一、背景

---

### B1 · 酒馆吧台背景 ⭐⭐⭐ 最重要

**中文**：
```
像素风游戏背景图，1280×720分辨率。

地下城奇幻酒馆的吧台后视角，玩家站在吧台后面看到的画面。

画面从上到下分为四层：
- 上层：粗糙石砖墙壁，深灰偏紫色调。左侧挂着两盏铁艺壁灯，发出暖黄色烛光。中右位置有一扇半开的拱形木门，门缝透出微弱的暖光。天花板有深色老木横梁，能看到木纹。
- 中层：吧台后方的木制酒架，4到5层隔板，摆放着琥珀色、深红色、绿色的酒瓶剪影。右侧墙上挂着一面破损的旧盾牌。
- 中下层：横贯整个画面的宽厚深色木吧台台面，深木色带木纹。
- 下层：吧台正面的竖木板，比上层更暗。最底部有一条深色凹槽区域。

光照：主光源来自左上壁灯和吧台上方吊灯（画面外），暖琥珀色。吧台下方带冷紫色阴影，形成冷暖对比。酒架区域偏暗，酒瓶处有微弱反光。

不要有人物。不要有文字。整体低饱和度，光影区域高对比度。
```

**English (backup)**：
```
Pixel art game background, 1280x720. Dark fantasy tavern, view from behind the bar counter.
Upper: stone brick wall, two iron sconces with warm amber flame, arched wooden door half-open with faint light inside, dark wood ceiling beams.
Middle: 4-5 shelf wooden wine rack with amber/red/green bottles. Worn shield on right wall.
Mid-lower: wide dark wood bartop counter stretching across full width.
Bottom: vertical wood plank front, darker tone. Recessed groove at very bottom edge.
Lighting: warm amber from upper-left sconces and overhead lamp. Cool purple shadows in lower area. Dim wine rack, subtle bottle highlights.
No people, no text. Low saturation, high contrast light/shadow. Pixel art game background style.
```

---

### T1 · 标题画面背景（已有，可选重制）

**中文**：
```
像素风游戏标题背景，1280×720。

地下城石砌酒馆外观。画面中下部是厚重的橡木双开门。暖黄色灯光从门缝中透出，很有诱惑力。门上挂着一块铁艺招牌。四周是深紫黑色的虚空，强烈的暗角效果把视线引向发光的门口。远处有细小的星点漂浮。

石墙上有些许苔藓。Darkest Dungeon 哥特建筑风格。不要有人物，招牌上不要有文字。
```

---

### D1 · 地牢区域地图

**中文**：
```
像素风羊皮纸地图，1280×720。

一张摊开的做旧羊皮纸，描绘地牢地下剖面图。羊皮纸底色是暖褐色，边缘有烧焦和破损痕迹。

地图上有五个地点，用虚线路径连接：
- 左上：菌菇林地——发光小蘑菇、潮湿洞穴入口
- 中上：废弃矿道——矿车轨道、暗色隧道口
- 右侧：暗河沿岸——地下河流、岸边发光苔藓
- 左下：葡萄藤架——人工种植区、攀爬藤蔓
- 右下：农庄磨坊——小风车建筑、地下农田

中世纪手绘地图风格。角落有指南针装饰。羊皮纸褐+深棕墨水线条，低饱和度暖调。不要有UI叠加，不要有文字标签。
```

---

## 二、角色 — 莱恩 (Ryan)

> **角色一致性策略**：先跑 C1 主立绘，确认效果后，后续 C2-C4 用"同一角色，改变表情/姿势"的方式描述。如果 Nano Banana 支持参考图功能，把 C1 作为参考图效果最佳。

---

### C1 · 莱恩 主立绘

**中文**：
```
像素风游戏角色立绘，200×250像素画布（后续2倍放大到400×500），全身站立，正面略偏3/4角度。

年轻男性见习骑士，18-20岁，偏瘦体型。一头凌乱的棕色短发，额头有几缕碎发。明亮的蓝灰色大眼睛，眼神清澈，嘴角微微上扬，自信从容。

穿着银色轻甲——是皮革底+金属肩甲和胸甲片的轻便装备，不是全身重甲。甲胄下面是深蓝色布衣。一柄未出鞘的长剑随意地扛在右肩上。

浅肤色，年轻感。站姿挺拔放松，肩膀后展。顶光暖色调照明，头顶和肩膀上方有高光。外轮廓用2像素深色描边。透明背景。

像素风，暗黑地牢角色风格。不要3D渲染，不要动漫风，不要模糊抗锯齿。
```

**English (backup)**：
```
Pixel art character sprite, 200x250 canvas, full body standing pose, slight 3/4 front view.
Young male knight, 18-20, lean build. Short messy brown hair, bright blue-grey eyes, slight confident smile.
Silver light armor on leather base. Dark blue cloth underneath. Long sword resting on right shoulder, not drawn.
Light skin tone, youthful. Upright relaxed posture. Top-down warm lighting. 2px dark outer outline. Transparent background.
Darkest Dungeon character style. No 3D, no anime, no blur, no anti-aliasing.
```

---

### C2 · 莱恩 坚定

> **生成方式**：以下面提示词生成；如支持参考图，用 C1 做参考图效果更一致。

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C1同一角色（年轻男见习骑士、棕色碎发、银色轻甲、深蓝布衣、剑扛右肩）。

表情变化：笑容比C1更大更自信，眉头微蹙表示坚定。右手握住了剑柄（剑仍在鞘中）。眼神更加明亮有力，下颚微收紧。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

### C3 · 莱恩 忧虑

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C1同一角色（年轻男见习骑士、棕色碎发、银色轻甲、深蓝布衣、剑扛右肩）。

表情变化：眉头紧锁忧虑，嘴唇紧抿成一条线。眼神下移避开对视。肩膀微微内收。眼神高光变暗，整体姿态失去自信。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

### C4 · 莱恩 崩坏/悲伤

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C1同一角色（年轻男见习骑士、棕色碎发、银色轻甲、深蓝布衣、剑扛右肩）。

表情变化：眼神空洞失焦，眼睑半垂。嘴角下垂。头微微低下。比C1色调整体偏暗，眼下有淡淡阴影。给人"心灰意冷"的感觉。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

## 三、角色 — 米拉 (Mira)

> **同样策略**：先跑 C5 主立绘定调，再出 C6-C8。

---

### C5 · 米拉 主立绘

**中文**：
```
像素风游戏角色立绘，200×250像素画布（后续2倍放大到400×500），全身站立，正面略偏3/4角度。

女性旅行商人，25-28岁，体型中等干练。深棕色长发扎成利落的高马尾，耳边有几缕碎发。琥珀色的锐利眼睛，眼型偏细长，直视玩家。嘴角微扬但不露齿，是那种"职业微笑"——礼貌但有所保留。

一手叉腰。身穿深棕色皮质背心，内搭米色亚麻衬衫。腰间斜挎多口袋棕色腰带，挂着各种小袋子和卷轴。右肩挎着一个大型皮质旅行包。

浅麦色肤色。顶光暖色调照明，马尾顶部和肩膀有高光。外轮廓2像素深色描边。透明背景。

像素风，暗黑地牢角色风格。不要3D，不要动漫风，不要模糊，不要性感化或夸张身材。
```

**English (backup)**：
```
Pixel art character sprite, 200x250 canvas, full body standing pose.
Female traveling merchant, 25-28, capable lean build. Dark brown hair in high ponytail. Sharp amber eyes, narrow gaze. Professional slight smile — polite but reserved.
One hand on hip. Dark brown leather vest over cream linen shirt. Multi-pocket diagonal belt with pouches and scrolls. Large leather shoulder bag on right side.
Light wheat skin tone. Top-down warm lighting. 2px dark outline. Transparent background.
Darkest Dungeon style. No 3D, no anime, no blur, no exaggerated proportions.
```

---

### C6 · 米拉 真诚微笑

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C5同一角色（女商人、深棕高马尾、琥珀眼、皮背心、米色衬衫、工具腰带、旅行包）。

表情变化：真诚的温暖微笑——眼角微微皱起（与C5职业假笑的核心区别），嘴角自然上扬，整体感觉更开放温暖。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

### C7 · 米拉 惊讶

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C5同一角色（女商人、深棕高马尾、琥珀眼、皮背心、米色衬衫、工具腰带、旅行包）。

表情变化：眉毛抬高兴起，眼睛微微睁大，嘴巴微张，惊讶的表情。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

### C8 · 米拉 严肃

**中文**：
```
像素风游戏角色立绘，200×250像素画布。与C5同一角色（女商人、深棕高马尾、琥珀眼、皮背心、米色衬衫、工具腰带、旅行包）。

表情变化：收起所有笑容，眉头微蹙，直视玩家，嘴紧闭成一条线。严肃、公事公办的表情（用于关键剧情时刻）。

其余不变：顶光暖光、2像素深色描边、透明背景、暗黑地牢像素风格。
```

---

## 四、图标（32×32 像素画布）

> 图标建议**手绘**（LibreSprite），Nano Banana 仅出**参考图**——32×32 尺度任何 AI 都画不准细节。

### 材料图标（5种）— 参考图提示词

每个用相同句式，替换关键词：

**麦芽**：
```
Pixel art RPG item icon, 64x64. A small bundle of golden wheat stalks tied together, ripe grain heads drooping. Warm amber-gold color. Dark outline. Top lighting. Transparent background.
```

**葡萄**：
```
Pixel art RPG item icon, 64x64. A small cluster of deep purple grapes with one green leaf and short vine tendril. Dark purple-red color. Dark outline. Top lighting. Transparent background.
```

**面粉**：
```
Pixel art RPG item icon, 64x64. A small burlap sack tied at top with rope, white powder leaking from opening. Warm brown sack color. Dark outline. Top lighting. Transparent background.
```

**生肉**：
```
Pixel art RPG item icon, 64x64. A T-bone cut of raw meat, pink-red flesh with white bone cross-section, meat marbling visible. Dark outline. Top lighting. Transparent background.
```

**草药**：
```
Pixel art RPG item icon, 64x64. A small bundle of fresh green leaves tied together, visible leaf veins. Bright green. Dark outline. Top lighting. Transparent background.
```

---

## 五、出图顺序 & 测试流程

### 第一轮测试（验证 Nano Banana 效果）

只跑 **2 张**：

1. **B1 酒馆背景** — 这是最复杂、最重要的背景，先看 Nano Banana 对大场景+像素风的处理
2. **C1 莱恩主立绘** — 看角色一致性

跑完两张后暂停，检查：
- [ ] 像素感够不够？边缘锐利吗？
- [ ] 色板接近 #161311/#ffbd7f 吗？
- [ ] 角色有没有奇怪的解剖/手部问题？
- [ ] 整体风格和 Darkest Dungeon 味道对不对？

### 第二轮（确认风格后批量）

如果第一轮效果 OK：
- **C2-C4** 莱恩表情变体（4 张一起跑）
- **C5** 米拉主立绘

### 第三轮

- **C6-C8** 米拉表情变体
- **T1 / D1** 地图背景（可稍后，P1）

### 图标和 UI

不跑 AI，直接用 LibreSprite 手绘——参考 Nano Banana 出的各张图，从中取色保持一致。

---

## 六、后处理清单

Nano Banana 出图后，每张图过一遍这个流程：

1. **尺寸校验**：用 ImageMagick `identify` 确认宽高符合文档规格
2. **色板校色**：在 LibreSprite 中打开，用吸管工具取 3-5 个关键点，对照文档色板
3. **描边清理**：角色/图标的外轮廓确保是纯色 1-2px，不毛躁
4. **透明背景**：需要透明的图确认 Alpha 通道干净
5. **Nearest-neighbor 导出**：小画布 2x 放大时用最近邻插值，不能用双线性
6. **按文档命名**：全小写+下划线，放进对应 `assets/textures/` 子目录
