# 美术资产管线

本文档规定本项目后续新增美术资产的默认流程。目标是复用主界面成功的做法：先得到可审查的参考图，再通过确定性 native-pixel 管线生成运行时资产，而不是把 AI 图或程序占位图直接塞进游戏。

## 核心原则

- 生图只作为 reference，不直接作为 runtime texture。
- 全屏背景的生产源通常是 `320x180` native；运行时通常是 `1280x720`，只能从 native 做 `4x` 最近邻导出。
- 小图标、状态层、hover/selected/reveal 效果都要有独立 native 源图，再做整数倍最近邻导出。
- 可交互、可新增、会变化的内容不能烙死在背景里。
- 先视觉审查 reference，再写或运行管线；先验证管线，再接运行时。
- 不用程序几何块冒充最终美术。程序绘制只适合可控的抽象状态层，例如刷痕环、底座、遮罩。

## 标准目录

每个 feature 应使用同样的分层：

```text
assets/source/<feature>/reference/   # 生图、人工绘制、清理后的参考图
assets/source/<feature>/             # native 生产源
assets/textures/<feature>/           # runtime 纹理
scripts/tools/prepare_<feature>_sources.py
scripts/tools/export_<feature>_assets.py
scripts/test/test_<feature>_asset_pipeline.py
```

reference 文件必须保留在仓库里。以后重做、切层、排查问题时，不能只看 runtime PNG。

## 开始前必须做

做任何新美术前，先检查现有成功案例：

- `scripts/tools/prepare_title_screen_sources.py`
- `scripts/tools/export_title_screen_assets.py`
- `scripts/test/test_title_screen_asset_pipeline.py`
- `assets/source/title/reference/`
- 当前 feature 的旧管线和测试

如果需求涉及动态点位、按钮、角色、道具、状态效果，先明确哪些是背景，哪些是独立动态层。背景只负责承载，不负责表达可交互状态。

## Reference 生成规则

生成背景 reference 时：

- 优先要高清手绘/插画参考图，不要直接要求 AI 生成 pixel art。
- 明确视角、构图、留白、动态元素禁区。
- 不要出现文字、标签、UI、按钮、logo、水印。
- 不要出现会和动态元素冲突的成品图标、圆点、pin、quest marker。
- 生成后先肉眼审查，通过后再进管线。

生成 icon reference 时：

- 可以用一张 sheet，但每个 icon 必须分格、留足 padding、背景可去除。
- icon 本体不要带圆形底座、pin、光圈、阴影状态。
- 状态效果由项目统一生成或统一绘制，不能混在每个 icon 里。

## Native Pixel 处理规则

背景：

- reference 到 native 的规则必须写在 `prepare_*_sources.py` 中。
- 如果 reference 已经是批准过的像素风图，通常用 `Image.Resampling.NEAREST` 规整到 native，避免糊。
- 如果 reference 是高清手绘图，可以用受控 downsample/pixelize，但必须测试和视觉检查，不能只套模糊滤镜。
- native 背景通常为 `320x180`，运行时只允许 `4x` 最近邻到 `1280x720`。

图标：

- 高清 icon reference 先去背景、裁切、居中、统一 padding。
- native icon 通常为 `24x24`。
- 可读性优先于保留细节。缩小后看不清时，提亮、提对比、减少颜色或重切图。
- runtime icon 通常为 `96x96`，只允许 `4x` 最近邻。

状态层：

- hover、selected、reveal、disabled 等状态应独立成 native 纹理。
- 优先使用统一的暗 teal 底座、amber 刷痕环、低透明度墨迹，而不是现代 UI 发光圆环。
- 状态纹理可以用 Pillow 程序生成，但必须有 native 源和 exact nearest 导出测试。

## 动态元素规则

背景不能烙死未来可能动态生成的内容：

- DayMap 背景可以画道路、河流、地貌、空地和低对比暗示。
- 地点 marker、任务状态、新发现、锁定、选中、hover 必须是独立层。
- 新增地点必须复用同一套 marker 规格和状态纹理。
- 如果新增类型没有 icon，先生成/切出同规格 icon，再接入数据；不要临时贴一张风格不同的图。

## 测试要求

每条资产管线至少测试：

- native 文件存在且尺寸正确；
- runtime 文件尺寸正确；
- runtime 是 native 的 exact nearest-neighbor export；
- transparent layer 有 alpha，且不是空图；
- 背景不是低复杂度程序占位；
- reference 到 native 的关键规则可被测试验证；
- 运行时场景确实引用 pipeline runtime 纹理，而不是渐变、占位图或旧路径。

对动态 marker 这类资产，还要测试：

- icon runtime 由 native exact nearest 导出；
- marker 状态纹理存在并 exact nearest 导出；
- 运行时节点暴露可测试的 texture 状态；
- 坐标系和背景 runtime 尺寸一致。

## 视觉检查

测试通过不等于美术通过。接运行时前至少看：

- reference；
- native source；
- runtime texture；
- 动态元素叠加预览；
- Godot 场景中的实际显示。

视觉检查重点：

- 是否符合主界面的暗 teal 地牢酒馆基调；
- amber 是否只是点缀，不抢画面；
- 是否有糊、油、过高饱和、手游贴纸感；
- 动态元素是否能读清；
- hover/selected 是否像手绘地图语言，而不是现代程序 UI；
- 文本、按钮、marker 是否互相遮挡。

## 禁止事项

- 禁止把 AI 生成的 pixel art 当最终 runtime asset。
- 禁止用 LANCZOS 或其他平滑缩放直接替代 native-pixel 管线。
- 禁止用程序几何块冒充完整背景美术。
- 禁止把可交互点、状态、未来新增内容烙死进背景。
- 禁止只凭测试通过就宣称美术完成。
- 禁止在没有 reference、native、runtime 三层证据的情况下接 Godot 场景。

## 当前参考案例

- TitleScreen：`scripts/tools/prepare_title_screen_sources.py`
- TitleScreen export：`scripts/tools/export_title_screen_assets.py`
- TitleScreen test：`scripts/test/test_title_screen_asset_pipeline.py`
- DayMap：`scripts/tools/prepare_daymap_sources.py`
- DayMap export：`scripts/tools/export_daymap_assets.py`
- DayMap test：`scripts/test/test_daymap_asset_pipeline.py`

后续新增美术应先对照这些案例，再开始实现。
