# 开发流程规范 v1.0

> 适用：地下城酒馆 Godot 4.6 .NET 2D 项目 | 个人开发 | AI 辅助
> 核心原则：上一阶段未完成，不进下一阶段。

---

## 流程总览

```
需求 → Spec → Plan → Worktree → 编码 → 编译+验证 → Code Review → Commit main
```

7 个阶段，每阶段一道闸门。所有 AI 对话遵循此流程。

---

## 1. Spec — 设计文档

**目的**：代码不动之前，需求先定清楚。

**产出**：`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

**内容要求**：
- 功能描述（做什么，明确不做什么）
- 涉及的文件/系统（路径级别）
- 数据结构变更
- 交互/UI 行为描述
- 边界情况和已知限制

**闸门**：spec 经你确认通过 → 进入 Plan。

---

## 2. Plan — 实现计划

**目的**：把 spec 拆成有序可执行的任务列表。

**产出**：`docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`

**内容要求**：
- 任务编号 + 描述 + 涉及文件
- 依赖关系（A blocked by B）
- 可并行任务标注
- 每个任务的验证方式

**规则**：
- 每个任务原则上只改 ≤1 个文件
- 任务粒度：单个任务应在 20 分钟内可完成

**闸门**：plan 经你确认通过 → 进入 Worktree。

---

## 3. Worktree — 隔离工作区

**目的**：所有改动在临时分支进行，main 保持干净。

**操作**：
- `git worktree add` 创建临时分支，命名 `feature/<topic>` 或 `fix/<topic>`
- 编码在 worktree 目录完成
- 完成后合并回 main，删除 worktree

**闸门**：worktree 就绪 + plan 在手 → 进入编码。

---

## 4. 编码

**规则**：
- 严格按 plan 任务顺序执行，做完一个标记完成
- 只改 plan 中指定的文件，禁止顺手重构
- 禁止添加 plan 外的功能
- 每个任务完成后立即 `dotnet build`
- 遇到 plan 未覆盖的情况 → 暂停，更新 plan

**闸门**：全部任务完成 + 编译 0 错误 → 进入验证。

---

## 5. 编译+验证

**目的**：证明改的东西能用，没搞坏别的东西。

**步骤**：
1. `dotnet build` — 0 errors
2. Godot 编辑器运行，手动走一遍核心路径
3. 检查关联功能未退化（回归）
4. 有测试则跑测试

**闸门**：全部通过 → 进入 Code Review。

---

## 6. Code Review

**目的**：以审查者视角再过一遍 diff。

**检查清单**：
- 每个 changed file 是否在 plan 中都有对应（无多余改动）
- null 引用风险
- 新旧代码边界衔接
- 硬编码、死代码
- 资源泄漏（FileAccess 未 using、事件未取消订阅）

**闸门**：问题清零或明确标记"已知/后续" → 进入 Commit。

---

## 7. Commit

**规则**：
- commit message 格式：`type: 简短描述`（feat:/fix:/refactor:/docs:）
- 一个功能一个 commit（不拆太碎也不打大包）
- commit 到 main 分支

---

## 配套约束

### 对话管理
- 一次对话只做一个功能
- 对话过长（上下文膨胀）→ 重开新对话，引用 spec/plan 文档恢复上下文
- CLAUDE.md 是项目速查入口，随时更新

### AI 行为规范
- spec/plan 未确认前，AI 不写代码
- 编码中遇到 plan 未覆盖情况，AI 暂停并报告，不等指示自行发挥
- AI 每次回复只做一件事（一个问题/一个任务/一个审查项）
