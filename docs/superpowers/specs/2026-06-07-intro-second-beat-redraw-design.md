# 开场第二拍构图保留式重绘设计

- 日期：2026-06-07
- 分支：`feat/blacksouls-intro`
- 状态：设计已确认，待制定实施计划
- 目标资产：`intro_hearth_memory`
- 构图底稿：`assets/source/intro/reference/intro_hearth_memory.png`
- 风格基准：`assets/source/title/reference/title_pixel_composite_reference.png`

## 目标

保留当前第二拍已经成立的史诗感、电影感和空间纵深，只重做与标题及主界面不统一的视觉
语言。当前参考图不是可直接降采样的生产源，而是严格构图底稿。

最终画面必须像标题画面由同一位美术创作，同时仍能一眼认出当前第二拍的镜头：从酒馆
入口向内窥视，中央炉火位于纵深终点，石地通道把视线引向炉火，两侧满座人群形成暗色
夹景。

## 构图锁定

除入口门区域外，以下关系必须按当前参考图保留：

- 镜头高度、视野宽度和门槛窥视位置。
- 中央壁炉的大小、位置和主焦点地位。
- 石地通道通向壁炉的单点纵深。
- 左右桌椅及人群的大体分布、前中后景层级和满座规模。
- 右侧酒架和吧台区域的大轮廓。
- 顶部横梁及吊灯提供的空间高度。

允许为适配 `16:9`、旁白安全区和 Ken Burns 运镜做少量边缘调整，但不得改变炉火、通道
和两侧人群组成的核心透视。

## 入口修正

当前左侧巨大门扇空间逻辑不清，并抢夺壁炉权重。重绘时删除完整门扇，改为门框窥视：

- 左侧只保留厚重石门框和极窄的暗色门边。
- 不表现完整门板、拉手、铰链或悬空的大面积木墙。
- 门框作为最暗的前景夹景，不获得琥珀高光中心。
- 修正入口后，中央炉火必须比左侧入口更先吸引视线。

## 人群

保留当前参考图的满座规模，使用约 `10–14` 名顾客。人物不是独立肖像，而是组成空间节奏
的块面剪影：

- 保留左右两侧的群体分布和前后遮挡关系。
- 使用坐姿、站姿、侧身和背身形成不同轮廓。
- 不绘制脸、五官、发丝、服饰纹样、武器细节或手指。
- 相邻人物可合并为连续暗块，只保留必要的头肩和手臂分界。
- 禁止把人群减少为四人空旷场景，也禁止排成面对炉火的仪式性半圆。

## 灯光

炉火是唯一强烈的 amber 焦点。其他光源仅用于说明空间，不得与炉火竞争：

- 保留吊灯轮廓，但整体压暗，仅允许少量微弱 amber 像素。
- 壁灯和桌面烛光缩减为零星低亮像素簇。
- 炉火可照亮中央地面的一条窄路径，但不能形成全画面橙色覆盖。
- 约 `70%` 画面保持暗 teal、蓝绿黑或煤黑。
- 禁止柔光、体积光、景深、写实反射和连续渐变。

## 细节密度

保留能说明“古老地下酒馆”的大轮廓，删除写实信息：

- 右侧酒架保留宽隔板和成组瓶罐色块，不逐瓶刻画。
- 桌椅保留可读剪影，桌面只留少数酒杯或烛光像素簇。
- 石墙、木梁和地砖使用成组明暗面，不画连续石缝、木纹、划痕和颗粒噪点。
- 删除零碎摆件、密集瓶海和均匀分布的高光。
- 在 `320x180` 查看时，门框、炉火、通道、人群和右侧酒架必须仍能区分。

## 风格与生产方式

采用构图描摹式重绘，不采用自动像素化补救：

1. 当前 `intro_hearth_memory.png` 作为严格构图输入。
2. 标题合成图作为严格风格输入。
3. 生成或绘制新的高分辨率参考稿，保留构图并重建色板、轮廓和光照。
4. 将批准的参考稿整理到 `320x180` 原生像素网格。
5. 仅通过整数最近邻 `4x` 导出 `1280x720` 运行时纹理。

高分辨率参考稿不得直接进入 `assets/textures/intro/`。缩图、限色或像素滤镜不能代替原生
网格上的轮廓清理。

## 生成提示词约束

```text
Use the attached current tavern interior image as a strict composition template.
Preserve its camera height, central hearth, floor perspective, crowded seating layout,
right-side shelving, ceiling structure, and foreground-midground-background rhythm.
Do not redesign or relocate these elements.

Replace the oversized wooden door on the left with only a thick dark stone doorway
frame and a very narrow shadowed door edge. The viewer looks into the tavern from the
threshold. Keep approximately 10 to 14 patrons in the existing crowded distribution,
but render them as broad anonymous silhouette groups without faces, costume detail or
individual portrait features.

Redraw the scene in the exact visual language of the attached title-screen artwork:
dark teal and coal-black masses, restrained amber accents, low-density chunky pixel
clusters, stepped edges, hard shadow shapes and large readable silhouettes designed
for a 320x180 native pixel grid. The central hearth is the only strong amber focal
point. The chandelier, wall lamps and table candles are dim secondary marks.
```

负面约束：

```text
Do not change the camera, central hearth position, floor vanishing path, crowd scale,
table distribution or right-side shelving. No large visible door slab, four-person
empty tavern, sparse seating, photorealism, cinematic photography, oil painting,
smooth gradients, soft bloom, volumetric light, depth of field, detailed faces,
detailed clothing, individual bottles, fine stone texture, detailed wood grain,
orange color wash, dithering or high-frequency noise.
```

## 验收标准

- 与当前参考图叠加比较时，炉火、通道、人群和主要家具位置基本一致。
- 左侧不再出现巨大门扇，只以厚石门框形成暗色前景。
- 第一眼先看到中央炉火，随后沿地面纵深读取满座酒馆。
- 约 `10–14` 人的规模感保留，但人物均为低细节块面剪影。
- 吊灯和壁灯可辨但不形成第二个强光中心。
- 右侧酒架和桌椅仍能说明酒馆功能，但没有密集瓶罐和写实材质。
- 在 `320x180` 原生尺寸下仍有清晰层次，不依赖平滑缩放或高分辨率纹理。
- 运行时 PNG 是原生图的精确 `4x` 最近邻导出。

## 暂不处理

- 本设计不修改旁白、节奏、Ken Burns 参数或运行时代码。
- 本设计不决定第三拍的最终构图；第二拍验收后，再以批准图为依据设计冷寂版本。
- 本设计不重做营业界面背景。
