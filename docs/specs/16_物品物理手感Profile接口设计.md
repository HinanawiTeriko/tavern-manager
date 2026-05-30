# 物品物理手感 Profile 接口设计

> 日期：2026-05-30  
> 状态：设计稿  
> 分支：`docs/item-physics-profiles`  
> 目的：给材料和成品预留可调物理手感、碰撞体和反馈接口，方便后续团队自己接具体碰撞体积与手感参数。  
> 相关文档：`docs/specs/13_合成系统物理重设计需求文档.md`

---

## 1. 设计背景

当前吧台系统最有潜力的体验是重力物理：玩家拖拽、投掷、轻放、粗放材料和成品，操作本身会表达态度，并进入合成与上菜反馈。

本设计不替代酒桶入桶、冒泡、产出等正在推进的链路，只解决一个基础问题：

> 不同物品应该能有不同手感，但这些差异不能写死在代码里。

因此需要一套数据驱动的 profile 接口。第一版只调质量、摩擦、弹性等简单参数；后续再由团队逐个接入圆形、长条、扁块等碰撞体，并继续调手感。

---

## 2. 核心目标

- 物品手感通过数据配置，不在 `DeskItem` 中硬编码。
- 第一版不依赖真实碰撞体积，所有物品可以先共用默认碰撞体。
- 后续可以逐个物品接入具体碰撞体，例如葡萄圆形、酒瓶长条、生肉扁块。
- 手感方向偏“物理戏剧”：失控可笑，结局可控。
- 物理戏剧第一版不影响配方成功率、材料消耗、价格和主线剧情。

---

## 3. 不做范围

- 不做复杂入桶反馈链，例如吞入、冒泡、产出弧线。
- 不做完整品质系统。
- 不做材料永久损坏、碎瓶、洒汤等强惩罚。
- 不做多容器统一抽象。
- 不要求第一版实现真实碰撞体积。
- 不把“葡萄是圆的”“肉是重的”这类物品差异写死在代码里。

---

## 4. 数据结构

在 `data/items.json` 中给物品增加三个可选字段：

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

字段说明：

| 字段 | 作用 | 第一版要求 |
|------|------|------------|
| `physics_profile` | 控制质量、摩擦、弹性、阻尼、重力倍率 | 必做 |
| `collision_profile` | 控制碰撞体形状和尺寸 | 只保留接口，默认盒子即可 |
| `feedback_profile` | 控制落地音、碰撞反馈、粒子、震动 | 只保留接口，可先不接资源 |

建议新增数据文件：

```text
data/item_physics_profiles.json
```

第一版把 physics / collision / feedback 三类 profile 放在同一个文件里即可。如果后续数据变大，再拆成多个文件。

---

## 5. 物理 Profile

示例：

```json
{
  "physics": {
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
}
```

字段含义：

| 字段 | 用途 |
|------|------|
| `mass` | RigidBody2D 质量，影响拖拽和碰撞分量 |
| `friction` | 摩擦，影响滑动和停下速度 |
| `bounce` | 弹性，影响落桌和碰撞弹跳 |
| `linear_damp` | 线性阻尼，控制移动衰减 |
| `angular_damp` | 角阻尼，控制旋转衰减 |
| `gravity_scale` | 重力倍率，预留给轻飘或重坠物品 |

建议安全范围：

| 字段 | 范围 |
|------|------|
| `mass` | 0.2 - 5.0 |
| `friction` | 0.0 - 1.0 |
| `bounce` | 0.0 - 0.8 |
| `linear_damp` | 0.0 - 2.0 |
| `angular_damp` | 0.0 - 2.0 |
| `gravity_scale` | 0.2 - 2.0 |

非法值应夹到安全范围，避免物品飞出、穿透或无法拾取。

---

## 6. 碰撞 Profile 预留

示例：

```json
{
  "collision": {
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
}
```

第一版可以所有物品都使用 `default_box`。

后续试点顺序建议：

1. `grape` 葡萄接 `circle_small`，验证滚动感（圆形最容易让玩家感到"它真的会滚"）。
2. 酒瓶类成品接 `bottle_tall`，验证易倒和轻放手感。
3. `meat_raw` 生肉接 `block_flat`，验证重、钝、砸桌的分量。

每次只引入一个新碰撞体试点，方便判断手感问题来自形状还是参数。

---

## 7. 反馈 Profile 预留

示例：

```json
{
  "feedback": {
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
}
```

第一版不要求接真实音效和粒子资源。可以先只存 profile，并在碰撞强度超过阈值时进入对应分支或输出 debug log。

---

## 8. 推荐初始映射

| 物品 | `physics_profile` | `collision_profile` 第一版 | 后续碰撞方向 | `feedback_profile` | 手感目标 |
|------|-------------------|----------------------------|--------------|--------------------|----------|
| `ale` 麦芽 | `default` | `default_box` | 小方块/颗粒 | `default` | 基准物 |
| `grape` 葡萄 | `round_light` | `default_box` | `circle_small` | `bouncy` | 轻、滑、弹、会滚 |
| `meat_raw` 生肉 | `heavy_dull` | `default_box` | `block_flat` | `thud` | 重、钝、砸桌有分量 |
| `flour` 面粉 | `soft_stable` | `default_box` | 软袋矩形 | `powder` | 轻软、停得快、粉尘戏剧 |
| `herb` 草药 | `default` | `default_box` | 小散块 | `default` | 第一版走基准物，后续再做轻飘感 |

后续若要强化草药，可以新增 `light_loose` / `leafy` profile，但不放进第一版验收。

成品后续方向：

| 成品类型 | 手感方向 |
|----------|----------|
| 酒瓶类 | 细长、易倒，轻放优雅，粗放会转圈或摇晃 |
| 面包/烤肉 | 稳、重心低，上菜容易 |
| 汤/茶类 | 容器感强，拖快时有晃动反馈 |

---

## 9. 代码边界

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
- profile 缺失时回退默认，不中断游戏。

错误处理：

- 未知 `physics_profile`：回退 `default`，可 `push_warning`。
- 未知 `collision_profile`：回退 `default_box`，可 `push_warning`。
- 未知 `feedback_profile`：回退 `default`，可 `push_warning`。
- 非法数值：夹到安全范围。

---

## 10. 分阶段落地

### P1：Profile 接口

- 新增 `data/item_physics_profiles.json`。
- 给 `items.json` 中基础材料加 profile 引用。
- `DeskItem` 应用 mass / friction / bounce / damp / gravity_scale。
- 所有碰撞体仍用默认形状。

验收：葡萄、生肉、面粉、麦芽拖拽和落桌手感明显不同；不影响配方、入桶和上菜逻辑。

### P2：反馈占位

- 记录 `feedback_profile`。
- 碰撞强度超过阈值时触发占位方法或 debug log。
- 暂不要求真实音效和粒子。

验收：不同物品可以走不同反馈分支，但没有资源也不报错。

### P3：单物品碰撞试点

- 只给葡萄接 `circle_small`。
- 验证可拾取、可拖拽、可入桶、可落桌。
- 重点观察是否难以点击、频繁穿透或过度乱滚。

验收：葡萄比默认方块更容易滚动；未破坏其它物品。

### P4：扩展碰撞体和反馈

- 生肉接 `block_flat`。
- 酒瓶类接 `bottle_tall`。
- 面粉接粉尘反馈。

验收：每个物品差异更强，但仍不造成材料永久损失或主线阻塞。

---

## 11. 手感原则

- 先调参数，再加形状，最后加规则。
- 物理戏剧优先表现为反馈，不优先表现为惩罚。
- 失误可以好笑，但玩家要能快速恢复。
- 每个物品只需要一个强记忆点，不要堆多个特殊规则。
- 先让 3 个基础材料形成差异，再扩展到所有成品。
- 每次只引入一个新碰撞体，便于调参和回滚。

---

## 12. 手动验证路径

项目当前无自动测试 runner，验证以 Godot 标准编辑器为准：

1. 运行物理沙盘或正式 Tavern 工作面。
2. 从快捷栏生成 `ale`、`grape`、`meat_raw`、`flour`。
3. 分别测试轻拖、快速甩、松手落桌、撞击其它物品。
4. 确认所有物品仍可拾取、拖拽、入桶、上菜。
5. 确认缺失 profile 时回退默认，不阻塞游戏。
6. 后续接碰撞体时，重点验证点击命中区域和桌面稳定性。

---

## 13. 与现有系统的关系

- 与 `CraftStyleSystem` 互补：物理 profile 影响动作手感，`CraftStyleSystem` 仍负责把动作数据分类为粗鲁、平静、温柔等风格。
- 与酒桶整合互补：本设计不决定入桶成功、不决定产出动画，只让材料进入那条链路前后具备不同物理个性。
- 与剧情互补：第一版不新增剧情分支；后续可以让 NPC 读动作风格，但不直接读取具体 profile。

