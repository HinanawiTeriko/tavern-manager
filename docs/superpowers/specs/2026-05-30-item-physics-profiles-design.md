# 物品物理手感 Profile 接口 — 设计文档

> 日期: 2026-05-30  
> 分支: `docs/item-physics-profiles`  
> 范围: 为材料/成品预留可调物理手感、碰撞体、反馈接口；不实现复杂碰撞体积，不接管并行推进中的入桶反馈链。

---

## 1. 背景

当前项目最有辨识度的体验是吧台重力物理：玩家拖拽、投掷、轻放、粗放材料和成品，物理动作会进入合成与上菜表达。酒桶物理/入桶反馈相关工作可能正在并行推进，本设计不重复那条链路。

本设计只解决一个边界问题：后续团队希望自己逐步接入具体碰撞体积、调手感、加反馈时，不需要重写 `DeskItem` 或把每个物品写死在代码里。

目标是先留出稳定接口，让第一版可以只读简单参数，后续再按物品逐步扩展。

---

## 2. 设计目标

- 每个物品可以通过数据指定物理手感，而不是硬编码在 `desk_item.gd`。
- 第一版可以在所有物品共用默认碰撞体的情况下生效。
- 后续可以只改数据/少量 profile 应用逻辑，逐个接入圆形、长条、扁块等碰撞体。
- 手感方向偏“物理戏剧”：失控可笑，结局可控。
- 不让物理戏剧第一版影响配方成功率、材料消耗、价格或主线剧情。

---

## 3. 非目标

- 不做复杂入桶反馈链：吞入、冒泡、产出弧线等由酒桶整合工作负责。
- 不做完整品质系统。
- 不做材料损坏、永久丢失、碎瓶、洒汤等强惩罚。
- 不做多容器统一抽象。
- 不要求第一版具备真实碰撞体积。
- 不把“葡萄是圆的”“肉是重的”这类逻辑写死在 `DeskItem`。

---

## 4. 核心方案

给物品数据增加三个可选 profile 引用：

```json
{
  "grape": {
    "name": "葡萄",
    "color": [0.6, 0.1, 0.2],
    "price": 0,
    "type": "material",
    "physics_profile": "round_light",
    "collision_profile": "default_box",
    "feedback_profile": "bouncy"
  }
}
```

第一版只要求 `physics_profile` 生效。`collision_profile` 和 `feedback_profile` 可以先走默认值，但接口要保留。

建议新增数据文件：

- `data/item_physics_profiles.json`
- 可选拆分：如果文件变大，再拆 `item_collision_profiles.json` / `item_feedback_profiles.json`

第一版更推荐一个文件，降低加载和维护成本。

---

## 5. Profile 数据结构

### 5.1 物理 Profile

```json
{
  "default": {
    "mass": 1.0,
    "friction": 0.6,
    "bounce": 0.25,
    "linear_damp": 0.2,
    "angular_damp": 0.2,
    "gravity_scale": 1.0
  },
  "round_light": {
    "mass": 0.6,
    "friction": 0.25,
    "bounce": 0.45,
    "linear_damp": 0.1,
    "angular_damp": 0.05,
    "gravity_scale": 1.0
  },
  "heavy_dull": {
    "mass": 2.2,
    "friction": 0.8,
    "bounce": 0.05,
    "linear_damp": 0.6,
    "angular_damp": 0.7,
    "gravity_scale": 1.0
  },
  "soft_stable": {
    "mass": 0.8,
    "friction": 0.9,
    "bounce": 0.02,
    "linear_damp": 0.7,
    "angular_damp": 0.8,
    "gravity_scale": 1.0
  }
}
```

字段含义：

| 字段 | 用途 |
|------|------|
| `mass` | RigidBody2D 质量，决定拖拽和碰撞分量 |
| `friction` | 物理材质摩擦，决定滑动/停下速度 |
| `bounce` | 物理材质弹性，决定落桌和碰撞弹跳 |
| `linear_damp` | 线性阻尼，控制移动衰减 |
| `angular_damp` | 角阻尼，控制旋转衰减 |
| `gravity_scale` | 重力倍率，预留给轻飘或重坠物品 |

### 5.2 碰撞 Profile

```json
{
  "default_box": {
    "shape": "rect",
    "size": [40, 40],
    "offset": [0, 0]
  },
  "circle_small": {
    "shape": "circle",
    "radius": 14,
    "offset": [0, 0]
  },
  "bottle_tall": {
    "shape": "capsule",
    "radius": 10,
    "height": 54,
    "offset": [0, 0]
  },
  "block_flat": {
    "shape": "rect",
    "size": [48, 28],
    "offset": [0, 0]
  }
}
```

第一版可以所有物品都指向 `default_box`。后续优先只给葡萄试 `circle_small`，因为圆形最容易让玩家感到“它真的会滚”。

### 5.3 反馈 Profile

```json
{
  "default": {
    "impact_sound": "normal",
    "impact_particle": "",
    "shake_scale": 0.0
  },
  "bouncy": {
    "impact_sound": "tap",
    "impact_particle": "",
    "shake_scale": 0.0
  },
  "thud": {
    "impact_sound": "thud",
    "impact_particle": "",
    "shake_scale": 0.15
  },
  "powder": {
    "impact_sound": "soft",
    "impact_particle": "flour_puff",
    "shake_scale": 0.0
  }
}
```

第一版不必接真实音频资源，可以先把 profile 作为占位字段。后续在碰撞强度超过阈值时触发对应反馈。

---

## 6. 推荐初始映射

| 物品 | `physics_profile` | `collision_profile` 第一版 | 后续碰撞方向 | `feedback_profile` | 手感目标 |
|------|-------------------|----------------------------|--------------|--------------------|----------|
| `ale` 麦芽 | `default` | `default_box` | 小方块/颗粒 | `default` | 基准物 |
| `grape` 葡萄 | `round_light` | `default_box` | `circle_small` | `bouncy` | 轻、滑、弹、会滚 |
| `meat_raw` 生肉 | `heavy_dull` | `default_box` | `block_flat` | `thud` | 重、钝、砸桌有分量 |
| `flour` 面粉 | `soft_stable` | `default_box` | 软袋矩形 | `powder` | 轻软、停得快、粉尘戏剧 |
| `herb` 草药 | `default` | `default_box` | 小散块 | `default` | 第一版走基准物，后续再做轻飘感 |

后续若要强化草药，可以新增 `light_loose` / `leafy` profile，但不放进第一版验收。

成品方向：

| 成品类型 | 后续手感 |
|----------|----------|
| 酒瓶类 | 细长、易倒，轻放优雅，粗放会转圈/摇晃 |
| 面包/烤肉 | 稳、重心低，上菜容易 |
| 汤/茶类 | 容器感强，拖快时有晃动反馈 |

---

## 7. 代码边界

`DeskItem` 只负责应用 profile，不负责决定某个 item 应该是什么手感。

建议接口：

```gdscript
func setup_item(item_key: String, item_data: Dictionary, profiles: Dictionary = {}) -> void

func apply_physics_profile(profile: Dictionary) -> void

func apply_collision_profile(profile: Dictionary) -> void

func apply_feedback_profile(profile: Dictionary) -> void
```

加载边界：

- `GameManager` 或物理工作面控制器负责加载 `data/item_physics_profiles.json`。
- 创建 `DeskItem` 时，把 item 数据和 profile 字典传入。
- 如果缺字段或 profile 不存在，使用 `default`，不报错中断游戏。

错误处理：

- 未知 `physics_profile`：回退 `default`，可 `push_warning`。
- 未知 `collision_profile`：回退 `default_box`，可 `push_warning`。
- 未知 `feedback_profile`：回退 `default`，可 `push_warning`。
- 非法数值：夹到安全范围，避免物品飞出或无法拾取。

建议安全范围：

| 字段 | 范围 |
|------|------|
| `mass` | 0.2 - 5.0 |
| `friction` | 0.0 - 1.0 |
| `bounce` | 0.0 - 0.8 |
| `linear_damp` | 0.0 - 2.0 |
| `angular_damp` | 0.0 - 2.0 |
| `gravity_scale` | 0.2 - 2.0 |

---

## 8. 分阶段实施建议

### P1: Profile 接口

- 新增 `data/item_physics_profiles.json`。
- 给 `items.json` 中基础材料加 profile 引用。
- `DeskItem` 应用 mass/friction/bounce/damp/gravity_scale。
- 所有碰撞体仍用默认形状。

验收：葡萄、生肉、面粉、麦芽拖拽和落桌手感明显不同；不影响配方和上菜逻辑。

### P2: 反馈占位

- 记录 `feedback_profile`。
- 碰撞强度超过阈值时触发占位方法或 debug log。
- 暂不要求真实音效和粒子。

验收：不同物品可以走不同反馈分支，但没有资源也不报错。

### P3: 单物品碰撞试点

- 只给葡萄接 `circle_small`。
- 验证可拾取、可拖拽、可入桶、可落桌、不会频繁穿透或难以点击。

验收：葡萄比默认方块更容易滚动；未破坏其它物品。

### P4: 扩展碰撞体和反馈

- 肉块接 `block_flat`。
- 酒瓶类接 `bottle_tall`。
- 面粉接粉尘反馈。

验收：每个物品差异更强，但仍不造成材料永久损失或主线阻塞。

---

## 9. 手感原则

- 物理戏剧优先表现为反馈，不优先表现为惩罚。
- 失误可以好笑，但玩家要能快速恢复。
- 每个物品只需要一个强记忆点，不要堆多个特殊规则。
- 先调参数，再加形状，最后加规则。
- 每次只引入一个新碰撞体试点，避免不知道是哪项参数导致手感变坏。

---

## 10. 手动验证路径

当前项目无自动测试 runner。验证以 Godot 标准编辑器为准：

1. 运行物理沙盘或正式 Tavern 工作面。
2. 从快捷栏生成 `ale`、`grape`、`meat_raw`、`flour`。
3. 分别测试轻拖、快速甩、松手落桌、撞击其它物品。
4. 确认所有物品仍可拾取、拖拽、入桶、上菜。
5. 确认缺失 profile 时回退默认，不阻塞游戏。
6. 若后续接碰撞体，重点验证点击命中区域和桌面稳定性。

---

## 11. 与现有工作的关系

- 与 `CraftStyleSystem` 互补：物理 profile 影响动作手感，`CraftStyleSystem` 仍负责把动作数据分类为粗鲁/平静/温柔等风格。
- 与酒桶整合互补：本设计不决定入桶成功、不决定产出动画，只让材料进入那条链路前后具备不同物理个性。
- 与剧情互补：第一版不新增剧情分支；后续可让 NPC 读动作风格，但不读具体 profile。
