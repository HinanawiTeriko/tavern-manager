# 开场酒馆内景空间设计

- 日期：2026-06-06
- 修订：2026-06-07
- 分支：`feat/blacksouls-intro`
- 状态：已被第二拍重绘设计取代，不再作为第二拍实施依据
- 关联：`docs/superpowers/specs/2026-06-06-intro-art-pipeline-design.md`

> 2026-06-07：第二拍已改为严格保留当前 `intro_hearth_memory.png` 构图并重绘风格。
> 第二拍的人群规模、入口、壁炉位置和家具布局以
> `docs/superpowers/specs/2026-06-07-intro-second-beat-redraw-design.md` 为准。
> 本文仅保留为此前空间母版方案的历史记录。

## 目标

建立只服务开场第二、三拍的酒馆内景母版。该母版不再兼顾未来正式营业界面，也不需要为
营业视角预留 L 形工作台。未来营业背景应另立任务、重新构图。

第二、三拍必须使用同一镜头和家具布局。空间通过左侧入口门、左后稀疏酒架、中央桌椅与
通道、右后石拱壁炉和顶部木梁保持连续性。

## 核心视觉标志

石拱壁炉与炉火是第一视觉标志，也是“熄灭与重燃”叙事的核心。其他家具必须服从壁炉，
不能形成第二个高亮中心。

空间辨识元素按优先级排列：

1. 右后方石拱壁炉。
2. 左侧入口木门与左后低密度酒架。
3. 中央桌椅、通道和人物舞台。
4. 顶部 2–3 根粗木梁。
5. 右下角被画框裁切的局部直吧台。

## 固定空间布局

```text
后墙：
左侧入口门 -> 左后低密度酒架 -> 中央低对比人物区 -> 右后石拱壁炉

顶部：
2–3 根粗木梁；只在左上或画面边缘悬挂最多两束干草药

中景：
简单桌椅沿两侧分布；中央保留清晰通道和四名顾客的活动空间

前景：
仅在右下角露出一小段被右边框裁切的矩形直吧台
```

入口木门必须延续入口母版：

- 门位于空间左侧。
- 使用竖向木板、上下两根横向木加固条。
- 中部靠自由边有一个横向黑铁拉手。
- 不出现招牌、墙牌、旗帜或文字。

## 局部吧台几何

现有 `tavern_interior_spatial_master-v4.png` 作为编辑基底。保留它的门、酒架、桌椅、
木梁、壁炉和镜头关系，完整删除原有大型 L/U 形吧台及其蜡烛、账本和凳子，再重建局部
直吧台。

新吧台必须满足：

- 位于右下角，并被画面右边框裁切。
- 是水平矩形直吧台，不折弯、不回折、不斜向伸向壁炉。
- 约占画面宽度 20%、高度 18%。
- 只显示左端、窄台面和正面木板。
- 台面从左至右保持一致宽度，透视边互相平行。
- 台面只放一个粗陶单柄酒杯。
- 不出现转角、第二段台面、吧台凳、蜡烛、账本或其他物品。
- 不遮挡壁炉、中央通道、桌椅或人物区域。

## 家具与装饰预算

内景不能空，但装饰必须低密度并可在 `320x180` 阅读：

- 酒架只有 2–3 层宽隔板，每层只放少量大瓶罐剪影。
- 干草药最多两束，只放在顶部边缘。
- 桌椅采用大轮廓，不画密集木纹。
- 除局部吧台上的单个酒杯外，不新增高对比前景道具。
- 室内禁止酒桶、板条箱、瓶堆、锅具墙、武器架和散落杂物。
- 中央人物区禁止高对比装饰和强光。

## 开场机位与顾客调度

镜头位于门槛内侧、略偏左，斜向观察室内。入口门只在最左边保留窄幅轮廓。右下局部吧台
只是前景空间锚点，不负责把视线引向壁炉。

第二拍使用恰好四名匿名顾客：

- 两人在一张桌旁以侧面或 3/4 剪影交谈。
- 一人侧坐，注意力落在酒杯或桌面。
- 一人靠近入口，呈现即将下井或刚刚归来的状态。

人物朝向必须不同。禁止所有人面向壁炉、对称围火、跪拜、祈祷或组成半圆。人物不画脸、
服饰细节、武器细节或个体肖像。

第三拍严格复用同一机位和家具布局，只删除人物并熄灭主要暖光。

## 光照层级

- 壁炉是唯一强烈 amber 焦点，位于右后方而非画面正中央。
- 吧台酒杯不自发光，也不获得强烈轮廓光。
- 入口附近可以保留微弱冷暗轮廓。
- 至少约 70% 画面保持暗 teal 或煤黑。
- 禁止全画面橙色覆盖、柔光、体积光、景深和写实反射。

## 美术语言

- 以标题画面为严格风格参考。
- 使用低密度 chunky pixel clusters、大轮廓、阶梯边缘和硬阴影。
- 史诗感来自拱形壁炉、木梁尺度、留白和空间层级，不来自写实纹理。
- 石材、木材和瓶罐只保留少量成组高光，禁止均匀噪点和细碎材质。
- 候选图缩到 `320x180` 后，壁炉、门、酒架、桌椅和局部吧台仍须分别可辨。

## 生成约束

必须以 `assets/source/intro/reference/tavern_interior_spatial_master-v4.png` 为编辑输入，
不能从纯文字重新生成。

正向约束：

```text
Preserve the existing camera, left entrance door, sparse shelves, central tables,
ceiling beams and right-rear stone fireplace. Remove the entire large foreground
L-shaped or U-shaped counter. Rebuild only one small straight rectangular counter
segment in the bottom-right corner, cropped by the right frame edge. Show only its
left end, narrow top surface and front wooden face. It occupies about 20 percent of
the image width and 18 percent of the image height. Keep one rough single-handled
ceramic mug on the counter and no other counter objects. Keep the central floor,
tables and passage unobstructed.
```

负向约束：

```text
No L-shaped bar, U-shaped bar, corner bar, wraparound counter, bent counter, diagonal
counter, second counter segment, bar stools, candle, ledger, barrel, crate, bottle
wall, cookware wall or foreground clutter. Do not enlarge the counter. Do not make
the counter a focal point. Do not move the fireplace, door, shelves or tables.
```

## 生产顺序

1. 以 `tavern_interior_spatial_master-v4.png` 为编辑输入重生成候选图。
2. 先审核吧台几何和遮挡，再审核整体风格与 `320x180` 可读性。
3. 批准后保存为 `tavern_interior_spatial_master.png`。
4. 从批准的室内母版编辑生成 `intro_hearth_memory`。
5. 从批准的暖景编辑生成完全同机位的 `intro_tavern_dark`。

## 完成标准

- 右下吧台像被画框裁切的固定柜台，不像独立桌子。
- 台面是单一矩形平面，宽度一致，透视边互相平行。
- 看不到转角、第二段台面或向壁炉延伸的结构。
- 吧台不超过画面宽度 20%、高度 18%。
- 台面只有一个粗陶单柄酒杯。
- 中央地面和桌椅区域无遮挡，可容纳四名顾客。
- 壁炉仍是第一视觉焦点，吧台不形成第二个高亮中心。
- 缩小到 `320x180` 后，门、酒架、桌椅、壁炉和局部吧台仍能分别辨认。
- 若模型再次生成错误吧台，直接否决，不通过后期裁切掩盖结构问题。
