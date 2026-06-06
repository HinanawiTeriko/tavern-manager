# 开场动画美术资产管线设计

- 日期：2026-06-06
- 分支：`feat/blacksouls-intro`
- 状态：设计已确认，待实现计划
- 依赖：`docs/art_pipeline.md`
- 配套叙事设计：`docs/superpowers/specs/2026-06-05-souls-style-intro-design.md`

## 目标

为当前黑魂/法环式电影开场制作五幅正式美术，并建立可重复、可测试的 native-pixel
生产管线。画面追求项目自身的黑暗史诗感，不复制写实油画：使用巨大地下空间、强剪影、
微小人物、暗 teal 主色和克制的 amber 焦点，在 `320x180` 原生网格上保持清晰可读。

本次保留完整五拍，不修改现有单静帧、穿黑过渡和 Ken Burns 运行时架构。

## 已确认的视觉约束

- 主角始终匿名，不露脸；只出现远处小剪影和握钥匙的手。
- 第 2、3、5 拍必须是同一间酒馆，并保持建筑结构连续。
- 酒馆就是标题画面左侧的酒馆，沿用石砌拱门、厚木门、壁灯、桶箱和地下巷道语言。
- 第 2、3 拍使用相同或高度对应的机位，以暖盛和冷寂形成兴衰对照。
- 第 5 拍从门槛看向室内，壁炉位置必须与连续性母版一致。
- 画面不包含文字、UI、按钮、logo、水印或旁白。
- 主要叙事焦点避开屏幕下方旁白区域，四边保留轻微运镜余量。
- reference 使用高清电影插画，不要求生成模型直接输出 pixel art。

## 分镜资产

| 拍 | Reference / Native / Runtime 名称 | 画面职责 |
|---|---|---|
| 1 | `intro_descent` | 巨大地下竖井或长阶向黑暗深处延伸，匿名主角为微小剪影，灯火向下逐渐稀少 |
| 2 | `intro_hearth_memory` | 同一酒馆昔日满座，壁炉与壁灯温暖明亮，但仍保持地下世界的厚重与阴影 |
| 3 | `intro_tavern_dark` | 对应第 2 拍的同一酒馆，门窗熄灭、招牌歪斜、积灰，空间冷寂 |
| 4 | `intro_rusted_key` | 戴旧皮手套或粗布袖口的匿名手掌托住锈钥匙，背景只暗示酒馆门与契约 |
| 5 | `intro_threshold` | 从门槛向同一酒馆内部看去，冷掉的壁炉与积灰可见，门开启后冷光切入 |

额外保留 `assets/source/intro/reference/tavern_continuity_master.png`。它只用于锁定酒馆结构，
不会导出为运行时纹理。

## Reference 生成流程

Reference 由用户在 ChatGPT 网页端生成，Codex 提供结构化 prompt 并负责后续审图。

1. 每次上传现有标题背景 `assets/textures/title/title_pixel_bg_clean.png` 作为风格和地点锚点。
2. 先生成 `tavern_continuity_master.png`，明确拱门、木门、招牌、壁灯、壁炉和主要家具位置。
3. 第 2、3、5 拍使用母版作为主要编辑输入，以编辑方式派生，禁止重新随机设计酒馆。
4. 第 1、4 拍使用标题背景作为风格参考独立生成。
5. 每张 reference 到仓库后先进行肉眼审查；构图、结构或叙事不合格时不进入生产管线。

母版与五拍 reference 均保存在 `assets/source/intro/reference/`，使用描述性文件名，不覆盖被否决
的版本；迭代稿可使用 `-v2`、`-v3` 后缀。

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
- 使用受控缩小、局部对比和无抖动色彩量化，形成低密度 chunky pixel cluster。
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
- 不增加配音、音乐、粒子、胶片噪声或新的运行时 schema。
- 不在本阶段修改旁白文案和 DayMap handoff。

## 完成标准

五拍都具有批准过的 reference、`320x180` native 和 exact-nearest runtime 三层证据；管线测试
全部通过；contact sheet 中酒馆结构和色调连续；Godot 实际播放无裁切、遮挡或露边问题。只有同时
满足自动验证和视觉审查，才能宣称开场美术完成。
