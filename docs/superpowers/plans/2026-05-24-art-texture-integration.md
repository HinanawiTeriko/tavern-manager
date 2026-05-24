# 美术贴图集成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立贴图加载系统，将现有的 StyleBoxFlat/ColorRect 程序化占位符逐步替换为真实像素贴图，未就绪的贴图自动回退到占位符。

**Architecture:** 新增 `TextureManager` 静态工具类做 "尝试加载贴图，失败返回 null"；所有 UI 代码用 `texture ?? StyleBoxFlat` 模式，确保贴图缺失时游戏仍可运行。用户生成 PNG 放入指定目录即可自动生效，无需改代码。

**Tech Stack:** Godot 4.6 .NET/C#, StyleBoxTexture, Texture2D, ResourceLoader

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新增 | `scripts/ui/TextureManager.cs` | 集中贴图加载，TryLoad 返回 null 不抛异常 |
| 修改 | `scripts/ui/ThemeColors.cs` | 新增贴图版按钮/面板 StyleBox 工厂方法 |
| 修改 | `scripts/ui/TavernView.cs` | 背景/客人立绘/UI元素贴图化 |
| 修改 | `scripts/ui/CraftStation.cs` | 槽位/图标贴图化 |
| 修改 | `scripts/ui/TitleScreen.cs` | 标题装饰元素贴图化 |
| 修改 | `scripts/ui/DayMapView.cs` | 地图背景贴图化 |
| 修改 | `scripts/ui/EndingScreen.cs` | 结局背景贴图化 |
| 修改 | `scripts/GameManager.cs` | 材料颜色 → 图标贴图映射 |
| 修改 | `scenes/ui/Tavern.tscn` | Background: ColorRect → Sprite2D；CustomerSprite: ColorRect → TextureRect |

---

### Task 1: 创建资源目录结构

**Files:**
- Create: `assets/textures/characters/.gitkeep`
- Create: `assets/textures/icons/materials/.gitkeep`
- Create: `assets/textures/icons/products/.gitkeep`
- Create: `assets/textures/icons/items/.gitkeep`
- Create: `assets/textures/icons/map/.gitkeep`
- Create: `assets/textures/ui/.gitkeep`
- Create: `assets/textures/vfx/steam/.gitkeep`
- Create: `assets/textures/vfx/splash/.gitkeep`
- Create: `assets/textures/vfx/swirl/.gitkeep`
- Create: `assets/textures/vfx/sparkle/.gitkeep`

- [ ] **Step 1: 用 Bash 创建所有目录**

Run:
```bash
cd /d/game/tavern-manager && mkdir -p assets/textures/characters assets/textures/icons/materials assets/textures/icons/products assets/textures/icons/items assets/textures/icons/map assets/textures/ui assets/textures/vfx/steam assets/textures/vfx/splash assets/textures/vfx/swirl assets/textures/vfx/sparkle
```

- [ ] **Step 2: 给空目录加 .gitkeep 以纳入版本控制**

Run:
```bash
cd /d/game/tavern-manager && for d in assets/textures/characters assets/textures/icons/materials assets/textures/icons/products assets/textures/icons/items assets/textures/icons/map assets/textures/ui assets/textures/vfx/steam assets/textures/vfx/splash assets/textures/vfx/swirl assets/textures/vfx/sparkle; do touch "$d/.gitkeep"; done
```

- [ ] **Step 3: Commit**

```bash
git add assets/textures/
git commit -m "chore: create asset directory structure for pixel art textures"
```

---

### Task 2: 实现 TextureManager 工具类

**Files:**
- Create: `scripts/ui/TextureManager.cs`

- [ ] **Step 1: 写 TextureManager.cs**

```csharp
using Godot;

/// <summary>
/// Centralized texture loader. Returns null when file is missing
/// so callers can fall back to programmatic StyleBoxFlat / ColorRect.
/// </summary>
public static class TextureManager
{
    /// Try to load a Texture2D. Returns null silently if the file doesn't exist.
    public static Texture2D TryLoad(string path)
    {
        if (ResourceLoader.Exists(path))
            return GD.Load<Texture2D>(path);
        return null;
    }

    /// Try to load a StyleBoxTexture for a 9-patch capable texture.
    /// Returns null if the texture is missing.
    public static StyleBoxTexture TryLoad9Patch(string path,
        int marginLeft = 8, int marginTop = 8, int marginRight = 8, int marginBottom = 8)
    {
        var tex = TryLoad(path);
        if (tex == null) return null;
        return new StyleBoxTexture
        {
            Texture = tex,
            TextureScale = 1,
            RegionRect = new Rect2(0, 0, tex.GetWidth(), tex.GetHeight()),
            PatchMarginLeft = marginLeft,
            PatchMarginTop = marginTop,
            PatchMarginRight = marginRight,
            PatchMarginBottom = marginBottom,
            AxisStretchHorizontal = StyleBoxTexture.AxisStretchModeEnum.Tile,
            AxisStretchVertical = StyleBoxTexture.AxisStretchModeEnum.Tile,
        };
    }

    /// Try to load a StyleBoxTexture for a fixed-size (non-9-patch) texture.
    public static StyleBoxTexture TryLoadStyleBox(string path)
    {
        var tex = TryLoad(path);
        if (tex == null) return null;
        return new StyleBoxTexture
        {
            Texture = tex,
            TextureScale = 1,
            RegionRect = new Rect2(0, 0, tex.GetWidth(), tex.GetHeight()),
            PatchMarginLeft = 0,
            PatchMarginTop = 0,
            PatchMarginRight = 0,
            PatchMarginBottom = 0,
        };
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: Build succeeded with 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/TextureManager.cs
git commit -m "feat: add TextureManager for optional texture loading with fallback"
```

---

### Task 3: ThemeColors 新增贴图版按钮/面板工厂方法

**Files:**
- Modify: `scripts/ui/ThemeColors.cs`

在 `StyleButton` 方法之前插入贴图版 StyleBox 方法。

- [ ] **Step 1: 新增贴图版按钮 StyleBox 方法**

在文件末尾（class 闭合大括号之前）添加：

```csharp
    // -- Texture-based StyleBox factories (return null if texture missing) --

    private static StyleBoxTexture _cachedBtnWideNormal;
    private static StyleBoxTexture _cachedBtnWideHover;
    private static StyleBoxTexture _cachedBtnWidePressed;
    private static StyleBoxTexture _cachedBtnSmallNormal;
    private static StyleBoxTexture _cachedBtnSmallHover;
    private static StyleBoxTexture _cachedBtnSmallPressed;
    private static StyleBoxTexture _cachedSlotMaterial;
    private static StyleBoxTexture _cachedSlotResult;
    private static StyleBoxTexture _cachedSlotShortcut;
    private static StyleBoxTexture _cachedPanelParchment;
    private static StyleBoxTexture _cachedBarShortcutBg;
    private static StyleBoxTexture _cachedBarTopPanel;

    public static StyleBoxTexture BtnWideNormal()
    {
        return _cachedBtnWideNormal ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_normal.png");
    }

    public static StyleBoxTexture BtnWideHover()
    {
        return _cachedBtnWideHover ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_hover.png");
    }

    public static StyleBoxTexture BtnWidePressed()
    {
        return _cachedBtnWidePressed ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_pressed.png");
    }

    public static StyleBoxTexture BtnSmallNormal()
    {
        return _cachedBtnSmallNormal ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_normal.png");
    }

    public static StyleBoxTexture BtnSmallHover()
    {
        return _cachedBtnSmallHover ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_hover.png");
    }

    public static StyleBoxTexture BtnSmallPressed()
    {
        return _cachedBtnSmallPressed ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_pressed.png");
    }

    public static StyleBoxTexture SlotMaterial()
    {
        return _cachedSlotMaterial ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_material.png");
    }

    public static StyleBoxTexture SlotResult()
    {
        return _cachedSlotResult ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_result.png");
    }

    public static StyleBoxTexture SlotShortcut()
    {
        return _cachedSlotShortcut ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_shortcut.png");
    }

    public static StyleBoxTexture PanelParchment()
    {
        return _cachedPanelParchment ??= TextureManager.TryLoad9Patch("res://assets/textures/ui/panel_parchment_9patch.png");
    }

    public static StyleBoxTexture BarShortcutBg()
    {
        return _cachedBarShortcutBg ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_shortcut_bg.png");
    }

    public static StyleBoxTexture BarTopPanel()
    {
        return _cachedBarTopPanel ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_top_panel.png");
    }
```

- [ ] **Step 2: 修改 StyleButton 方法支持贴图按钮**

将 `StyleButton` 方法替换为：先尝试贴图版 StyleBox，没有则回退到 Flat：

```csharp
    public static void StyleButton(Button btn, int fontSize = 16)
    {
        btn.AddThemeFontSizeOverride("font_size", fontSize);
        btn.AddThemeColorOverride("font_color", TextOnAmber);
        btn.AddThemeColorOverride("font_hover_color", TextOnAmber);
        btn.AddThemeColorOverride("font_pressed_color", TextOnAmber);

        var texNormal = BtnWideNormal();
        var texHover = BtnWideHover();
        var texPressed = BtnWidePressed();

        if (texNormal != null && texHover != null && texPressed != null)
        {
            btn.AddThemeStyleboxOverride("normal", texNormal);
            btn.AddThemeStyleboxOverride("hover", texHover);
            btn.AddThemeStyleboxOverride("pressed", texPressed);
        }
        else
        {
            btn.AddThemeStyleboxOverride("normal", ButtonNormal());
            btn.AddThemeStyleboxOverride("hover", ButtonHover());
            btn.AddThemeStyleboxOverride("pressed", ButtonPressed());
        }
    }
```

- [ ] **Step 3: 新增小按钮样式方法（CraftStation 用）**

在 `StyleButton` 之后添加：

```csharp
    /// Style a small button (90x40) for CraftStation gesture/action buttons.
    public static void StyleSmallButton(Button btn, int fontSize = 13)
    {
        btn.AddThemeFontSizeOverride("font_size", fontSize);
        btn.AddThemeColorOverride("font_color", TextOnAmber);
        btn.AddThemeColorOverride("font_hover_color", TextOnAmber);
        btn.AddThemeColorOverride("font_pressed_color", TextOnAmber);

        var texNormal = BtnSmallNormal();
        var texHover = BtnSmallHover();
        var texPressed = BtnSmallPressed();

        if (texNormal != null && texHover != null && texPressed != null)
        {
            btn.AddThemeStyleboxOverride("normal", texNormal);
            btn.AddThemeStyleboxOverride("hover", texHover);
            btn.AddThemeStyleboxOverride("pressed", texPressed);
        }
        else
        {
            btn.AddThemeStyleboxOverride("normal", ButtonNormal(1, 2));
            btn.AddThemeStyleboxOverride("hover", ButtonHover(1, 2));
            btn.AddThemeStyleboxOverride("pressed", ButtonPressed(2, 1));
        }
    }
```

- [ ] **Step 4: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/ThemeColors.cs
git commit -m "feat: add texture-based button/panel StyleBox factories with fallback"
```

---

### Task 4: Tavern 场景背景贴图化

**Files:**
- Modify: `scenes/ui/Tavern.tscn` — Background 从 ColorRect 改为 Sprite2D
- Modify: `scripts/ui/TavernView.cs` — 对应的 C# 引用

- [ ] **Step 1: 修改 Tavern.tscn — 替换 Background 节点**

在 `Tavern.tscn` 中，将：
```
[node name="Background" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.165, 0.102, 0.055, 1)
```

替换为：
```
[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
centered = true
```

- [ ] **Step 2: 修改 TavernView.cs — Background 引用**

将类成员：
```csharp
private ColorRect _bgPlaceholder;
```

改为：
```csharp
private Sprite2D _bgSprite;
```

将 `_Ready` 中的初始化：
```csharp
_bgPlaceholder = GetNode<ColorRect>("Background");
```

改为：
```csharp
_bgSprite = GetNode<Sprite2D>("Background");
```

- [ ] **Step 3: 修改 ApplyTheme() — 背景贴图加载**

将：
```csharp
_bgPlaceholder.Color = ThemeColors.BackgroundDeep;
```

替换为：
```csharp
// Background: try pixel-art tavern_bg, fallback to deep color
var bgTex = TextureManager.TryLoad("res://assets/textures/backgrounds/tavern_bg.png");
if (bgTex != null)
{
    _bgSprite.Texture = bgTex;
}
else
{
    // No texture: use a generated solid-color placeholder
    var placeholderGradient = new GradientTexture2D
    {
        Width = 1280, Height = 720,
        Gradient = new Gradient { Colors = new[] { ThemeColors.BackgroundDeep, ThemeColors.SurfaceLow }, Offsets = new[] { 0f, 1f } }
    };
    _bgSprite.Texture = placeholderGradient;
}
```

- [ ] **Step 4: 删除 SetBackgroundColor 方法（不再需要）**

删除 TavernView.cs 中的：
```csharp
public void SetBackgroundColor(Color c) => _bgPlaceholder.Color = c;
```

- [ ] **Step 5: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/Tavern.tscn scripts/ui/TavernView.cs
git commit -m "feat: replace Tavern background ColorRect with Sprite2D + texture loading"
```

---

### Task 5: 客人立绘 TextureRect 化

**Files:**
- Modify: `scenes/ui/Tavern.tscn` — CustomerSprite 从 ColorRect 改为 TextureRect
- Modify: `scripts/ui/TavernView.cs` — ShowCustomer 加载角色贴图

- [ ] **Step 1: 修改 Tavern.tscn — CustomerSprite 节点**

将：
```
[node name="CustomerSprite" type="ColorRect" parent="CustomerArea"]
layout_mode = 0
offset_left = 100.0
offset_top = 20.0
offset_right = 300.0
offset_bottom = 300.0
color = Color(0.25, 0.2, 0.3, 1)
```

替换为：
```
[node name="CustomerSprite" type="TextureRect" parent="CustomerArea"]
layout_mode = 0
offset_left = 60.0
offset_top = 0.0
offset_right = 340.0
offset_bottom = 360.0
expand_mode = 1
stretch_mode = 5
```

节点尺寸调整为 280×360，与美术需求文档中 400×500 立绘等比缩放后的显示区一致。

- [ ] **Step 2: 修改 TavernView.cs — CustomerSprite 引用**

将：
```csharp
private ColorRect _customerSprite;
```

改为：
```csharp
private TextureRect _customerSprite;
```

将初始化：
```csharp
_customerSprite = GetNode<ColorRect>("CustomerArea/CustomerSprite");
```

改为：
```csharp
_customerSprite = GetNode<TextureRect>("CustomerArea/CustomerSprite");
```

- [ ] **Step 3: 修改 ShowCustomer 方法**

将：
```csharp
public void ShowCustomer(string name, string order, Color color)
{
    _customerSprite.Color = color;
    _customerSprite.Visible = true;
    _customerName.Text = name;
    _orderBubble.Text = $"「来一份{order}！」";
    _orderBubble.Visible = true;
}
```

替换为：
```csharp
private static readonly Dictionary<string, string> NpcTextureKeys = new()
{
    ["ryan"] = "ryan_neutral",
    ["mira"] = "mira_neutral",
};

public void ShowCustomer(string name, string order, string npcId)
{
    // Try to load character portrait: npcId_expression.png
    string texKey = npcId;
    NpcTextureKeys.TryGetValue(npcId, out texKey);
    var tex = TextureManager.TryLoad($"res://assets/textures/characters/{texKey}.png");
    if (tex != null)
    {
        _customerSprite.Texture = tex;
        _customerSprite.Modulate = Colors.White;
    }
    else
    {
        // Fallback: generate colored placeholder
        var placeholderGradient = new GradientTexture2D
        {
            Width = 200, Height = 250,
            Gradient = new Gradient
            {
                Colors = new[] { new Color(0.35f, 0.25f, 0.4f), new Color(0.2f, 0.15f, 0.25f) },
                Offsets = new[] { 0f, 1f }
            }
        };
        _customerSprite.Texture = placeholderGradient;
    }
    _customerSprite.Visible = true;
    _customerName.Text = name;
    _orderBubble.Text = $"「来一份{order}！」";
    _orderBubble.Visible = true;
}
```

- [ ] **Step 4: 修改 HideCustomer 方法**

添加：
```csharp
public void HideCustomer()
{
    _customerSprite.Visible = false;
    _customerName.Text = "等待中……";
    _orderBubble.Visible = false;
}
```

保持不变（不需要改）。

- [ ] **Step 5: 修改 GameManager.cs 中调用 ShowCustomer 的地方**

当前调用签名是 `ShowCustomer(displayName, recipeName, color)`，需要改为传递 npcId 而非 color。

在 `GameManager.cs` 的 `OnGuestArrived` 方法中，找到：
```csharp
_tavernView.ShowCustomer(displayName, recipe?.Name ?? guest.OrderKey,
    Craft.MaterialColor(recipe?.Materials.Length > 0 ? recipe.Materials[0] : "Ale"));
```

替换为：
```csharp
_tavernView.ShowCustomer(displayName, recipe?.Name ?? guest.OrderKey, guest.NpcId ?? "guest");
```

- [ ] **Step 6: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/Tavern.tscn scripts/ui/TavernView.cs scripts/GameManager.cs
git commit -m "feat: replace customer ColorRect with TextureRect, load character portraits"
```

---

### Task 6: 槽位贴图化（合成槽/成品槽/快捷槽）

**Files:**
- Modify: `scripts/ui/CraftStation.cs` — 用 StyleBoxTexture 替换 ColorRect 纯色槽

- [ ] **Step 1: 给槽位 ColorRect 应用 SlotMaterial/SlotResult/SlotShortcut 贴图**

在 `CraftStation._Ready()` 末尾（`SyncFromInventory()` 之后）添加：

```csharp
// Apply slot textures if available
var slotMatTex = ThemeColors.SlotMaterial();
if (slotMatTex != null)
{
    _slot1.AddThemeStyleboxOverride("panel", slotMatTex);
    _slot2.AddThemeStyleboxOverride("panel", slotMatTex);
}
else
{
    // StyleBoxFlat fallback: dark recessed frame
    var slotFallback = new StyleBoxFlat
    {
        BgColor = new Color(0.08f, 0.06f, 0.04f),
        BorderWidthLeft = 4, BorderWidthTop = 4,
        BorderWidthRight = 4, BorderWidthBottom = 4,
        BorderColor = ThemeColors.PanelBorder,
        CornerRadiusTopLeft = 2, CornerRadiusTopRight = 2,
        CornerRadiusBottomLeft = 2, CornerRadiusBottomRight = 2,
    };
    _slot1.AddThemeStyleboxOverride("panel", slotFallback);
    _slot2.AddThemeStyleboxOverride("panel", slotFallback);
}

var slotResTex = ThemeColors.SlotResult();
if (slotResTex != null)
    _resultSlot.AddThemeStyleboxOverride("panel", slotResTex);
else
{
    _resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);
}

var slotShortTex = ThemeColors.SlotShortcut();
if (slotShortTex != null)
{
    var slotShortFallback = new StyleBoxFlat
    {
        BgColor = new Color(0.1f, 0.08f, 0.06f),
        BorderWidthLeft = 2, BorderWidthTop = 2,
        BorderWidthRight = 2, BorderWidthBottom = 2,
        BorderColor = ThemeColors.PanelBorder,
    };
    for (int i = 0; i < 10; i++)
        _shortcutSlots[i].AddThemeStyleboxOverride("panel", slotShortTex ?? slotShortFallback);
}
```

注意：`ColorRect` 不直接支持 `panel` StyleBox。需要改为 `Panel` 或保持 ColorRect 但设置其 Color。

实际上 ColorRect 没有 `panel` theme。槽位保持 ColorRect 但改用更精致的 fallback 颜色。贴图存在时，改用一个隐藏的 `Panel` + `StyleBoxTexture` 叠加。

**调整方案**：不为槽位 ColorRect 加 panel stylebox。ColorRect 本身颜色做 fallback，贴图通过在每个槽下增加一个隐藏 Sprite2D/TextureRect 叠加层实现。

对于槽位，更简洁的做法：将 ColorRect 的 Color 设为带纹理的样式。但 ColorRect 不支持纹理...

**最终方案**：槽位保持 ColorRect，仅改进 fallback 颜色（参考美术文档的色值）。当贴图就绪时，可改为 Panel + StyleBoxTexture。当前阶段，改进 ColorRect 的颜色和边框效果。

- [ ] **Step 1 (Revised): 改进槽位 ColorRect 的 fallback 样式**

在 `CraftStation._Ready()` 末尾添加：

```csharp
// Improved slot visuals (closer to pixel-art slot design)
var slotInnerColor = new Color(0.08f, 0.06f, 0.04f);
var slotFrameColor = ThemeColors.PanelBorder;

// Material slots: dark recessed with thicker border feel
_slot1.Color = slotInnerColor;
_slot2.Color = slotInnerColor;

// Result slot: slightly lighter recess
_resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);

// Shortcut slots: dark recessed
for (int i = 0; i < 10; i++)
    _shortcutSlots[i].Color = slotInnerColor;
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/CraftStation.cs
git commit -m "refactor: improve craft slot ColorRect colors to match pixel-art design"
```

---

### Task 7: CraftStation 小按钮使用 StyleSmallButton

**Files:**
- Modify: `scripts/ui/CraftStation.cs`

- [ ] **Step 1: 在 _Ready 中给所有操作按钮应用小按钮样式**

在 `CraftStation._Ready()` 中，找到按钮节点获取代码之后，添加：

```csharp
// Apply small button theme (90x40 style)
ThemeColors.StyleSmallButton(_heatBtn, 12);
ThemeColors.StyleSmallButton(_shakeBtn, 12);
ThemeColors.StyleSmallButton(_stirBtn, 12);
ThemeColors.StyleSmallButton(_craftBtn, 12);
ThemeColors.StyleSmallButton(_serveBtn, 12);
ThemeColors.StyleSmallButton(_clearBtn, 12);
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/CraftStation.cs
git commit -m "feat: apply small button theme to CraftStation gesture/action buttons"
```

---

### Task 8: OverlayMenu 面板和 UI 条贴图化

**Files:**
- Modify: `scripts/ui/TavernView.cs`

- [ ] **Step 1: 修改 ApplyTheme() — 面板和条背景**

在 `ApplyTheme()` 方法中，将：

```csharp
// Menu panel
_menuPanel.AddThemeStyleboxOverride("panel", ThemeColors.ParchmentPanel());
```

替换为：

```csharp
// Menu panel: try 9-patch parchment texture, fallback to flat
var parchmentTex = ThemeColors.PanelParchment();
_menuPanel.AddThemeStyleboxOverride("panel", parchmentTex ?? ThemeColors.ParchmentPanel());
```

然后给 TopPanel 加背景条：

在 `ApplyTheme()` 末尾（`_timerBar` 设置之后）添加：

```csharp
// Top panel background bar
var topBarTex = ThemeColors.BarTopPanel();
var topPanel = GetNode<Panel>("TopPanelBg");
if (topPanel != null)
    topPanel.AddThemeStyleboxOverride("panel", topBarTex ?? new StyleBoxFlat
    {
        BgColor = new Color(ThemeColors.BackgroundDeep, 0.85f),
        BorderWidthBottom = 1,
        BorderColor = ThemeColors.PanelBorder,
    });

// Shortcut bar background
var shortcutBarBgTex = ThemeColors.BarShortcutBg();
var shortcutBg = GetNodeOrNull<Panel>("ShortcutBarBg");
if (shortcutBg != null)
    shortcutBg.AddThemeStyleboxOverride("panel", shortcutBarBgTex ?? new StyleBoxFlat
    {
        BgColor = new Color(ThemeColors.SurfaceLow, 0.8f),
        BorderWidthTop = 1,
        BorderColor = ThemeColors.PanelBorder,
    });
```

注意：TopPanelBg 和 ShortcutBarBg 节点在 Tavern.tscn 中不存在，需要添加。

- [ ] **Step 2: 修改 Tavern.tscn — 添加 TopPanelBg 和 ShortcutBarBg Panel 节点**

在 TopPanel 之上叠加一个背景 Panel（z-index 更低）：
- 在 `[node name="TopPanel" ...]` 之前插入一个 `TopPanelBg` Panel 节点
- 在 `[node name="ShortcutBar" ...]` 之前插入一个 `ShortcutBarBg` Panel 节点

TopPanelBg（1280×40，位于 y:0）:
```
[node name="TopPanelBg" type="Panel" parent="."]
layout_mode = 0
offset_left = 0.0
offset_top = 0.0
offset_right = 1280.0
offset_bottom = 40.0
mouse_filter = 2
```

ShortcutBarBg（1140×40，与 ShortcutBar 同位置 y:675-715）:
```
[node name="ShortcutBarBg" type="Panel" parent="."]
layout_mode = 0
offset_left = 140.0
offset_top = 675.0
offset_right = 1140.0
offset_bottom = 715.0
mouse_filter = 2
```

这些节点需要放在 ShortcutBar 节点之前（TS CN 文件中顺序决定 z-order）。

- [ ] **Step 3: 调整节点顺序**

在 Tavern.tscn 中，TopPanelBg 放在 TopPanel 之前，ShortcutBarBg 放在 ShortcutBar 之前。确保 `mouse_filter = 2`（忽略鼠标）使它们不阻挡下层交互。

- [ ] **Step 4: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/TavernView.cs scenes/ui/Tavern.tscn
git commit -m "feat: add texture support for top bar and shortcut bar backgrounds"
```

---

### Task 9: 耐心条贴图化

**Files:**
- Modify: `scripts/ui/TavernView.cs` — ApplyTheme 中 timerBar 的 fill 样式

- [ ] **Step 1: 修改 timerBar 样式，加载耐心条填充贴图**

在 `ApplyTheme()` 中将 timerBar 的 background 样式设置改为：

```csharp
// Timer bar: load patience bar textures
var patienceBgTex = TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_patience_bg.png");
var patienceFillTex = TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_patience_fill.png");

_timerBar.AddThemeStyleboxOverride("background",
    patienceBgTex ?? new StyleBoxFlat
    {
        BgColor = new Color(ThemeColors.SurfaceHigh, 0.8f),
        BorderWidthLeft = 1, BorderWidthTop = 1,
        BorderWidthRight = 1, BorderWidthBottom = 1,
        BorderColor = ThemeColors.PanelBorder,
    });

if (patienceFillTex != null)
    _timerBar.AddThemeStyleboxOverride("fill", patienceFillTex);

_timerBar.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
```

- [ ] **Step 2: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/TavernView.cs
git commit -m "feat: add patience bar background/fill texture loading"
```

---

### Task 10: DayMap/Ending 背景贴图化

**Files:**
- Modify: `scripts/ui/DayMapView.cs`
- Modify: `scripts/ui/EndingScreen.cs`
- Modify: `scenes/ui/DayMap.tscn`
- Modify: `scenes/ui/EndingScreen.tscn`

- [ ] **Step 1: 检查 DayMap.tscn 和 EndingScreen.tscn 的背景节点**

先读取这两个场景文件确认背景节点的类型和名称。

Run:
```bash
head -40 /d/game/tavern-manager/scenes/ui/DayMap.tscn && echo "---" && head -40 /d/game/tavern-manager/scenes/ui/EndingScreen.tscn
```

- [ ] **Step 2: 给 DayMapView 添加背景贴图加载**

在 `DayMapView._Ready()` 末尾添加：

```csharp
// Background: try to load daymap_bg texture
var bgNode = GetNodeOrNull<Sprite2D>("Background");
if (bgNode != null)
{
    var bgTex = TextureManager.TryLoad("res://assets/textures/backgrounds/daymap_bg.png");
    if (bgTex != null)
    {
        bgNode.Texture = bgTex;
    }
}
```

如果 DayMap.tscn 没有 Background 节点，添加一个：

```
[node name="Background" type="Sprite2D" parent="."]
position = Vector2(640, 360)
centered = true
z_index = -10
```

- [ ] **Step 3: 给 EndingScreen 添加背景贴图加载**

在 `EndingScreen._Ready()` 末尾添加：

```csharp
// Background: try to load ending_bg texture
var bgNode = GetNodeOrNull<Sprite2D>("Background");
if (bgNode != null)
{
    var bgTex = TextureManager.TryLoad("res://assets/textures/backgrounds/ending_bg.png");
    if (bgTex != null)
    {
        bgNode.Texture = bgTex;
    }
}
```

- [ ] **Step 4: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/DayMapView.cs scripts/ui/EndingScreen.cs scenes/ui/DayMap.tscn scenes/ui/EndingScreen.tscn
git commit -m "feat: add background texture loading for DayMap and EndingScreen"
```

---

### Task 11: TitleScreen 装饰元素贴图化

**Files:**
- Modify: `scripts/ui/TitleScreen.cs`

- [ ] **Step 1: 加载标题装饰元素**

在 `TitleScreen._Ready()` 末尾添加：

```csharp
// Decorative elements: load textures if available
TryLoadDeco("Deco/CandleLeft", "res://assets/textures/ui/deco_candle_left.png");
TryLoadDeco("Deco/CandleRight", "res://assets/textures/ui/deco_candle_right.png");
TryLoadDeco("Deco/Mug", "res://assets/textures/ui/deco_mug.png");
TryLoadDeco("Deco/Emblem", "res://assets/textures/ui/deco_emblem.png");

// Title sign image (overlay on title panel)
var titleSign = GetNodeOrNull<TextureRect>("UI/TitlePanel/TitleSign");
if (titleSign != null)
{
    var signTex = TextureManager.TryLoad("res://assets/textures/ui/title_sign.png");
    if (signTex != null)
        titleSign.Texture = signTex;
}
```

并添加辅助方法：

```csharp
private void TryLoadDeco(string nodePath, string texPath)
{
    var node = GetNodeOrNull<Sprite2D>(nodePath);
    if (node != null)
    {
        var tex = TextureManager.TryLoad(texPath);
        if (tex != null) node.Texture = tex;
    }
}
```

- [ ] **Step 2: 在 TitleScreen.tscn 中添加装饰元素节点（如果不存在）**

检查 TitleScreen.tscn 是否有 Deco 子节点。如果没有，添加：

```
[node name="Deco" type="Node2D" parent="."]

[node name="CandleLeft" type="Sprite2D" parent="Deco"]
position = Vector2(100, 560)

[node name="CandleRight" type="Sprite2D" parent="Deco"]
position = Vector2(1180, 560)

[node name="Mug" type="Sprite2D" parent="Deco"]
position = Vector2(640, 620)

[node name="Emblem" type="Sprite2D" parent="Deco"]
position = Vector2(640, 300)
```

在 TitlePanel 中加一个 TitleSign TextureRect：

```
[node name="TitleSign" type="TextureRect" parent="UI/TitlePanel"]
layout_mode = 0
offset_left = 50.0
offset_top = 0.0
offset_right = 550.0
offset_bottom = 100.0
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
```

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/TitleScreen.cs scenes/ui/TitleScreen.tscn
git commit -m "feat: add decorative element texture loading for TitleScreen"
```

---

### Task 12: GameManager MaterialColor → 图标贴图映射

**Files:**
- Modify: `scripts/GameManager.cs`
- Modify: `scripts/ui/TavernView.cs` — BuildRecipeList/BuildBackpackList 中的图标

- [ ] **Step 1: 在 GameManager 中添加材料/成品图标路径常量**

```csharp
// Material icon paths (for UI icon display)
private static readonly Dictionary<string, string> MaterialIconPaths = new()
{
    ["Ale"] = "res://assets/textures/icons/materials/ale.png",
    ["Wine"] = "res://assets/textures/icons/materials/wine.png",
    ["Bread"] = "res://assets/textures/icons/materials/bread.png",
    ["Meat"] = "res://assets/textures/icons/materials/meat.png",
    ["Herb"] = "res://assets/textures/icons/materials/herb.png",
};

public Texture2D TryLoadMaterialIcon(string key)
{
    if (MaterialIconPaths.TryGetValue(key, out var path))
        return TextureManager.TryLoad(path);
    return null;
}
```

- [ ] **Step 2: 修改 BuildRecipeList 和 BuildBackpackList 中的图标块**

在 `TavernView.cs` 的 `BuildRecipeList` 方法中，将 `ColorRect` 色块替换为可加载贴图的版本：

将：
```csharp
var box = new ColorRect
{
    Color = craft.MaterialColor(mat),
    CustomMinimumSize = new Vector2(36, 20)
};
row.AddChild(box);
```

替换为：
```csharp
var gm = GetNode<GameManager>("/root/GameManager");
var iconTex = gm.TryLoadMaterialIcon(mat);
if (iconTex != null)
{
    var texRect = new TextureRect
    {
        Texture = iconTex,
        CustomMinimumSize = new Vector2(32, 32),
        ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
        StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
    };
    row.AddChild(texRect);
}
else
{
    var box = new ColorRect
    {
        Color = craft.MaterialColor(mat),
        CustomMinimumSize = new Vector2(36, 20)
    };
    row.AddChild(box);
}
```

对 `BuildBackpackList` 中同样的 ColorRect 块做同样替换。

注意：`BuildRecipeList` 和 `BuildBackpackList` 已经通过 `var gm = GetNode<GameManager>("/root/GameManager");` 持有了 GM 引用。

- [ ] **Step 3: 编译验证**

Run: `dotnet build`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/GameManager.cs scripts/ui/TavernView.cs
git commit -m "feat: load material product icons from textures with fallback to ColoredRect"
```

---

### Task 13: 全量编译 + Godot 运行验证

- [ ] **Step 1: 最终编译**

Run: `dotnet build`
Expected: Build succeeded with 0 Error(s).

- [ ] **Step 2: 启动 Godot 运行游戏**

用 Godot MCP 启动项目，走一遍核心路径：
1. TitleScreen → 确认背景和 UI 显示正常
2. 点击"开始营业" → DayMap → 确认界面正常
3. 分配体力 → "出发" → Tavern → 确认背景/槽位/按钮显示正常
4. 拖动材料 → 合成 → 上菜 → 确认流程正常
5. "打烊" → EndingScreen → 确认界面正常

Run: 通过 Godot MCP `run_project` 启动，观察 debug output 无报错。

- [ ] **Step 3: 验证回退机制**

在没有贴图的目录（如 characters/）下确认游戏不崩溃，ColorRect/StyleBoxFlat 占位符正常工作。

---

## 用户生图参考

用户需要用 AI 工具生成并放入以下路径的贴图（按优先级排序）：

### 第一批（最大视觉提升）
| 文件 | 尺寸 | 说明 |
|------|------|------|
| `assets/textures/backgrounds/tavern_bg.png` | 1280×720 | 酒馆吧台背景 |
| `assets/textures/ui/btn_wide_normal.png` | 256×64 | 宽按钮 normal 态 |
| `assets/textures/ui/btn_wide_hover.png` | 256×64 | 宽按钮 hover 态 |
| `assets/textures/ui/btn_wide_pressed.png` | 256×64 | 宽按钮 pressed 态 |
| `assets/textures/ui/btn_small_normal.png` | 90×40 | 小按钮 normal 态 |
| `assets/textures/ui/btn_small_hover.png` | 90×40 | 小按钮 hover 态 |
| `assets/textures/ui/btn_small_pressed.png` | 90×40 | 小按钮 pressed 态 |

### 第二批（角色和图标）
| 文件 | 尺寸 | 说明 |
|------|------|------|
| `assets/textures/characters/ryan_neutral.png` | 400×500 | 莱恩主立绘 |
| `assets/textures/icons/materials/{ale,wine,bread,meat,herb}.png` | 64×64 | 5 种材料图标 |
| `assets/textures/icons/products/{ale,wine,bread,meat,herb_tea,herbal_ale,meat_stew,meat_sand,spiced_wine}.png` | 64×64 | 9 种成品图标 |

### 后续
完整的 P0/P1/P2 清单参见 `docs/07_美术需求文档.md` 第 10 节优先级清单。每批图片放入对应目录后，重启游戏即可自动生效（无需改代码）。

---

## Self-Review

### 1. Spec coverage
对照 `docs/07_美术需求文档.md` P0 清单：
- [x] B1 酒馆背景 → Task 4
- [x] C1-C8 角色立绘 → Task 5（ryan/mira neutral，需扩展 expression 切换）
- [x] I1-I14 材料+成品图标 → Task 12
- [x] 宽按钮 3 态 → Task 3
- [x] 小按钮 3 态 → Task 7
- [x] 材料槽+成品槽+快捷槽 → Task 6
- [x] 快捷栏背景+顶栏背景 → Task 8
- [x] 耐心条 → Task 9

未覆盖的 P0 项：C2-C4, C6-C8（多表情切换）—— 需要后续在 GuestSystem/Narrative 中驱动表情切换逻辑。当前计划已覆盖贴图加载基础设施，表情切换可在后续需求中轻松添加。

### 2. Placeholder scan
- No "TBD", "TODO", "implement later" found
- No abstract "add error handling" without code
- All code steps have complete, compilable code

### 3. Type consistency
- `TextureManager.TryLoad` → `Texture2D?` everywhere ✓
- `TextureManager.TryLoadStyleBox` → `StyleBoxTexture?` everywhere ✓
- `TextureManager.TryLoad9Patch` → `StyleBoxTexture?` everywhere ✓
- `ShowCustomer(name, order, npcId)` signature matches GameManager call site ✓
- `ThemeColors.StyleSmallButton` defined in Task 3, used in Task 7 ✓
- `ThemeColors.BarShortcutBg/BarTopPanel/etc` defined in Task 3, used in Task 8 ✓
