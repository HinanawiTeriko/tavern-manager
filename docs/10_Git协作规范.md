# Git 协作规范

**适用对象**：所有人类开发者 + AI 助手

---

## 标准流程（每次提交必须走完）

```bash
# 1. 开工前拉最新
git pull origin main

# 2. 写代码...

# 3. 提交前检查
git status                         # 确认改了哪些文件
dotnet build                       # 必须 0 errors！
grep -r "<<<<<<" --include="*.cs" . # 确认无残留冲突标记

# 4. 精确提交
git add <具体文件1> <具体文件2>      # ❌ 严禁 git add . 或 git add -A
git commit -m "type: 简述"

# 5. 先拉再推
git pull --rebase origin main
git push
```

---

## 禁止提交的文件

以下文件**绝对不能** add 或 commit：

| 文件/目录 | 原因 |
|-----------|------|
| `.godot/mono/temp/` | 编译缓存，每人本地不同 |
| `.godot/editor/` | 编辑器个人布局/缓存 |
| `.env` | 可能含密钥 |
| `.mcp.json` | 个人 MCP 配置 |
| `*.dll`, `*.pdb` | 编译产物 |
| 任何含 `<<<<<<` 的文件 | 冲突未解决 |

`.gitignore` 已配置：
```
.godot/*
!.godot/mono/
.godot/mono/temp/       # 编译产物忽略
```

---

## 合并冲突处理

如果有冲突（`CONFLICT`），**必须解决干净才能提交**：

```bash
# 1. 在 IDE 中打开冲突文件
# 2. 删除 <<<<<<<、=======、>>>>>>> 标记
# 3. 保留正确的代码
# 4. 验证
dotnet build            # 必须 0 errors
grep -r "<<<<<<" .

# 5. 提交
git add <解决的文件>
git commit -m "merge: 简述冲突内容"
```

**严禁**带着冲突标记提交。下一个人 pull 下来项目直接跑不了。

---

## AI 助手专用规则

如果你是 AI，以下行为必须遵守：

1. **提交前必须 `dotnet build` 通过**，有 error 不提交
2. **每次提交前检查 `git status`**，只 add 计划内的文件，不顺手带无关改动
3. **不提交 `.godot/mono/temp/`**，如果被误 add，先 `git rm --cached -r` 移除
4. **解决冲突后搜 `<<<<<<`** 确认 0 残留
5. **一个 commit 只做一个主题**：feat:/fix:/refactor:/docs:
6. **不修改 `addons/`** 下任何文件

---

## 协作红线（一票否决）

- ❌ 提交后 `dotnet build` 报错
- ❌ 提交中包含 `<<<<<<` / `=======` / `>>>>>>>` 标记
- ❌ `git add .` 或 `git add -A` 一把梭
- ❌ 提交 `.godot/mono/temp/` 编译产物
- ❌ `git push --force` 到 main

---

## 日常节奏

```
开工 → git pull
修改 → 小步提交（每完成一个功能点就 commit）
收工 → git pull --rebase && git push
```

**核心习惯：每次 `git commit` 之前，跑一次 `dotnet build`。过了再推，不过不推。**
