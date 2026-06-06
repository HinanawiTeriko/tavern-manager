# 开场动画美术资产管线设计

- 日期：2026-06-06
- 分支：`feat/blacksouls-intro`
- 状态：重构设计已确认，待用户生成 reference
- 依赖：`docs/art_pipeline.md`
- 配套叙事设计：`docs/superpowers/specs/2026-06-05-souls-style-intro-design.md`

## 目标

为当前电影式开场重做五幅正式美术，并继续使用可重复、可测试的 native-pixel 生产管线。
首要目标是与标题画面完全同源：暗 teal 地牢、克制 amber 光源、低密度 chunky pixel
clusters、明确的大轮廓和硬边阴影。庄严悲壮感只能通过尺度、构图、留白和镜头节奏实现，
不能通过写实材质、电影摄影效果或增加细节密度实现。

本次保留完整五拍，不修改现有单静帧、穿黑过渡和 Ken Burns 运行时架构。

优先级固定为：

1. 与标题画面美术风格统一。
2. 单拍叙事焦点清晰。
3. 在前两项范围内呈现庄严悲壮感。

## 已确认的视觉约束

- 主角始终匿名，不露脸；只出现远处小剪影和握钥匙的手。
- 第 2、3、5 拍必须是同一间酒馆，并保持建筑结构连续。
- 酒馆就是标题画面左侧的酒馆，沿用石砌拱门、厚木门、壁灯、桶箱和地下巷道语言。
- 第 2、3 拍使用几乎相同的机位，以暖盛和冷寂形成兴衰对照。
- 第 2 拍只出现 3–5 名顾客，全部处理为无面部、无服饰细节的大块剪影。
- 第 5 拍从门槛看向室内，壁炉位置必须与连续性母版一致。
- 画面不包含文字、UI、按钮、logo、水印或旁白。
- 主要叙事焦点避开屏幕下方旁白区域，四边保留轻微运镜余量。
- 每张图最多一个主焦点和一个次焦点，约 70% 画面保持为青黑暗部。
- amber 只允许出现在叙事焦点附近，禁止成为覆盖全画面的橙色调色。
- reference 必须在生成阶段就采用低细节、块面优先、像素簇导向的视觉语言。
- 禁止把写实概念图、油画或电影剧照式画面交给后续脚本“像素化补救”。

## 分镜资产

| 拍 | Reference / Native / Runtime 名称 | 画面职责 |
|---|---|---|
| 1 | `intro_descent` | 巨大环形竖井占据画面，石阶沿井壁向下消失；人物只是一枚小剪影，零星 amber 灯火逐级熄灭 |
| 2 | `intro_hearth_memory` | 酒馆拱门如圣堂入口，炉火是唯一强光；3–5 名顾客以大块剪影围绕桌杯，形成安静的仪式感 |
| 3 | `intro_tavern_dark` | 与第 2 拍几乎同机位；人物和暖光全部消失，只剩封闭木门、歪斜招牌与熄灭壁灯 |
| 4 | `intro_rusted_key` | 粗布袖口的手掌托起轮廓清晰的巨大锈钥匙；背景只保留酒馆门的暗色拱形 |
| 5 | `intro_threshold` | 从人物身后看向开启的厚木门；冷暗酒馆占大部分画面，远处壁炉只留一颗极小余烬 |

额外保留 `assets/source/intro/reference/tavern_continuity_master.png`。它只用于锁定酒馆结构，
不会导出为运行时纹理。

## Reference 生成流程

Reference 由用户在生图界面生成，Codex 提供结构化 prompt、负面约束并负责后续审图。

1. 每次上传标题合成参考 `assets/source/title/reference/title_pixel_composite_reference.png`
   作为风格锚点。
2. 先生成新的 `tavern_continuity_master.png`，明确拱门、木门、招牌、壁灯、壁炉和主要家具位置。
3. 第 2、3、5 拍必须使用母版作为编辑输入派生，禁止重新随机设计酒馆。
4. 第 1、4 拍使用标题合成参考作为风格输入独立生成。
5. 候选图使用 `-v2`、`-v3` 后缀保存，未批准前不得覆盖无后缀正式 reference。
6. 每张图进入仓库后先进行肉眼审查；构图、结构或风格不合格时不进入生产管线。

母版与五拍 reference 均保存在 `assets/source/intro/reference/`，使用描述性文件名，不覆盖被否决
的版本；迭代稿可使用 `-v2`、`-v3` 后缀。

### 通用 Prompt 骨架

每张图的场景描述后追加以下统一约束：

```text
Match the attached title-screen artwork as the primary and strict visual reference.
Hand-authored dark fantasy pixel illustration, designed around a 320x180 native pixel grid.
Low-density chunky pixel clusters, large readable silhouettes, stepped pixel edges,
hard-edged shadow shapes, restrained hand-placed highlights, limited dark teal,
coal black, muted blue-green and small amber palette. Flat grouped lighting,
clear foreground/midground/background separation. Solemn, ancient and tragic mood
created through scale, symmetry, negative space and composition, not realism.
No text, logo, UI, border or watermark.
```

统一负面约束：

```text
No photorealism, realistic concept art, oil painting, cinematic photography,
smooth gradients, soft bloom, volumetric fog, depth-of-field blur, glossy materials,
fine stone texture, detailed wood grain, tiny scratches, dense debris, random noise,
dithering, anti-aliased edges, painterly brush texture, orange color wash,
high-frequency detail or evenly distributed highlights.
```

生图模型输出的“像素画”仍只作为 reference，不能直接作为 runtime texture。

### 分拍 Prompt 差异

`intro_descent`：

```text
A monumental circular underground shaft fills the frame. A broad stone stair spirals
down the inner wall and disappears into a vast black depth. One anonymous traveler is
a tiny dark silhouette on the stair. A sparse chain of small amber lamps descends with
them and gradually goes dark. The shaft and darkness dominate the image; the figure
must remain very small. Strong concentric composition and large simple stone masses.
```

`tavern_continuity_master`：

```text
Design the same underground tavern seen in the attached title artwork as a reusable
continuity master. A heavy stone arch and thick wooden entrance door, hanging sign,
one wall lantern, a central back-wall hearth, simple tables and stools, barrels and
crates. Keep every major architectural element large, sparse and easy to reproduce.
Show both the entrance framing and the interior hearth relationship clearly.
```

`intro_hearth_memory`，以母版为编辑输入：

```text
Preserve the exact tavern architecture and camera position from the continuity master.
The stone arch reads like a humble sanctuary entrance. The hearth is the only strong
amber light. Add only three to five patrons as broad anonymous silhouettes around one
or two tables, with simple mug shapes and no faces, clothing detail or individual
portrait features. The gathering feels quiet and ritual-like, not busy or festive.
```

`intro_tavern_dark`，以 `intro_hearth_memory` 为编辑输入：

```text
Preserve the exact camera, architecture and large shapes from the warm memory image.
Remove every patron and almost all amber light. Close the heavy wooden door, extinguish
the wall lantern and hearth, tilt the hanging sign slightly, and add only a few large
patches of dust and neglect. The composition must feel empty because the former light
and silhouettes are absent, not because extra decay detail was added.
```

`intro_rusted_key`：

```text
A rough cloth sleeve and a simplified anonymous hand hold a single oversized rusted
iron key across the upper center of the frame. The key silhouette is bold and readable,
with only two or three flat rust highlight clusters. Behind it, the tavern's stone arch
and closed door appear as very dark simplified shapes. No realistic skin, fingernails,
metal reflections, contract paper or scattered props.
```

`intro_threshold`，以母版为编辑输入：

```text
Preserve the tavern architecture from the continuity master. View from behind the
anonymous traveler at the threshold as the heavy wooden door opens inward. The cold,
dark interior occupies most of the frame. The central back-wall hearth remains in its
established position and contains one extremely small amber ember, suggesting it can
be rekindled. The traveler is only a broad shoulder-and-head silhouette. No bright
sunbeam, volumetric light or triumphant glow.
```

## 生产目录

```text
assets/source/intro/reference/
  tavern_continuity_master.png
  intro_descent.png
  intro_hearth_memory.png
  intro_tavern_dark.png
  intro_rusted_key.png
  intro_threshold.png

assets/source/intro/
  intro_descent_native.png
  intro_hearth_memory_native.png
  intro_tavern_dark_native.png
  intro_rusted_key_native.png
  intro_threshold_native.png
  intro_vignette_native.png
  intro_contact_sheet.png

assets/textures/intro/
  intro_descent.png
  intro_hearth_memory.png
  intro_tavern_dark.png
  intro_rusted_key.png
  intro_threshold.png
  intro_vignette.png

scripts/tools/prepare_intro_sources.py
scripts/tools/export_intro_assets.py
scripts/test/test_intro_asset_pipeline.py
```

## Native Pixel 处理

`prepare_intro_sources.py` 负责全部 reference 到生产源的确定性处理：

- 按构图中心做 16:9 cover crop，并归一化到 `320x180`。
- reference 本身必须已具备大块轮廓和低细节密度；脚本不承担从写实图重画像素形状的职责。
- 使用受控缩小、局部对比和无抖动色彩量化，统一 native 网格与色盘。
- 以标题背景的暗 teal、煤黑和 amber 为调色锚点。
- 保护少量 amber 叙事焦点，不允许暖色扩散成全画面橙色滤镜。
- 限制细碎噪点和过多独立颜色，保证缩小后仍以大形状阅读。
- 生成确定性的 `intro_vignette_native.png`，暗角不得遮住旁白或吞没主体。
- 生成五拍 contact sheet，供连续性和整体色调审查。
- 所有结果先在内存中验证；任一输入失败时，不覆盖现有合格生产源。

`export_intro_assets.py` 只读取已验证的 native 源，并使用 `Image.Resampling.NEAREST` 做精确
`4x` 导出。五幅静帧和暗角从原生尺寸导出到 `1280x720`，不做二次滤镜或平滑缩放。

## 构图与运镜接口

现有 `data/intro.json` 的五个 `kenburns` 配置保持不变。Reference 构图须满足：

- 四边至少保留约 6% 的非关键区域，避免 `OVERSCAN` 和位移裁掉主体。
- 人脸、钥匙、门缝、壁炉等焦点不得落在最外侧 10%。
- 下方约 24% 视为旁白安全区，允许低对比环境但不放关键叙事信息。
- 第 1 拍纵向深度居中；第 2、3 拍主要建筑轮廓对应；第 4 拍手和钥匙位于中上区域；
  第 5 拍门缝和壁炉形成明确视觉连线。

## 测试

新的 `test_intro_asset_pipeline.py` 替换旧三场景视差契约，至少验证：

- 五幅 reference、native 和 runtime 文件齐全。
- 五幅 native 均为 `320x180`，runtime 均为 `1280x720`。
- 每幅 runtime 与对应 native 的 `4x` 最近邻结果逐字节一致。
- `intro_vignette` 有 alpha、非空、中心区域不过度变暗。
- native 图具备足够的暗部、teal 区域和受控 amber 焦点。
- native 调色板和局部复杂度不超过设定上限，拒绝高频绘画噪点。
- 自动测试不尝试判断酒馆结构连续性；第 2、3、5 拍与母版的建筑对应关系是强制人工视觉门禁。
- `data/intro.json` 按顺序引用五个 runtime 路径。
- 旧 `arrival_*` 前后景资产和旧管线契约不再被运行时或测试引用。
- prepare 或 export 在后期验证失败时不覆盖已有输出。

自动测试通过后还必须检查 reference、native、runtime、contact sheet，并在 Godot 中完整播放：
确认旁白可读、信箱黑边正常、慢运镜不露边、五拍过渡和 DayMap match-cut 连贯。

## 不做

- 不制作多层视差或重新引入旧 `arrival_*` 三场景方案。
- 不把网页端生成图直接放入 `assets/textures/intro/`。
- 不要求生成模型直接产出最终像素画。
- 不使用写实 reference 再依靠降采样制造像素感。
- 不增加配音、音乐、粒子、胶片噪声或新的运行时 schema。
- 不在本阶段修改旁白文案和 DayMap handoff。

## 完成标准

五拍都具有批准过的 reference、`320x180` native 和 exact-nearest runtime 三层证据；每张图
单独看都像标题画面的同源作品；第 2、3、5 拍建筑结构连续；管线测试全部通过；Godot 实际播放
无裁切、遮挡或露边问题。只有同时满足自动验证和视觉审查，才能宣称开场美术完成。
