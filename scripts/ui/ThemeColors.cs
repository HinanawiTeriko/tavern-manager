using Godot;

/// <summary>
/// Design system: "Hearth & Shadow" pixel-art palette.
/// Centralized so all UI scenes/systems reference the same colors.
/// </summary>
public static class ThemeColors
{
    // Primary amber — warmth, firelight, interactivity
    public static readonly Color AmberPrimary    = new(1.0f, 0.741f, 0.498f);  // #ffbd7f
    public static readonly Color AmberBright     = new(1.0f, 0.584f, 0.0f);    // #ff9500
    public static readonly Color AmberDark       = new(0.8f, 0.45f, 0.0f);
    public static readonly Color TextOnAmber     = new(0.294f, 0.157f, 0.0f);  // #4b2800

    // Surfaces — dark tavern interior
    public static readonly Color BackgroundDeep  = new(0.086f, 0.075f, 0.067f); // #161311
    public static readonly Color SurfaceLow      = new(0.122f, 0.106f, 0.098f); // #1f1b19
    public static readonly Color SurfaceMid      = new(0.137f, 0.122f, 0.114f); // #231f1d
    public static readonly Color SurfaceHigh     = new(0.18f, 0.161f, 0.153f);  // #2e2927
    public static readonly Color SurfaceHighest  = new(0.224f, 0.204f, 0.192f); // #393431

    // Text
    public static readonly Color TextLight        = new(0.918f, 0.882f, 0.867f); // #eae1dd
    public static readonly Color TextSubtitle     = new(0.859f, 0.761f, 0.678f); // #dbc2ad
    public static readonly Color TextDim          = new(0.64f, 0.553f, 0.478f);  // #a38d7a

    // Functional
    public static readonly Color Success          = new(0.29f, 0.55f, 0.25f);   // moss green
    public static readonly Color Danger           = new(0.65f, 0.15f, 0.1f);    // low-sat red
    public static readonly Color PanelBorder      = new(0.333f, 0.263f, 0.204f); // #554334

    // -- Helper methods --

    /// Amber-styled normal StyleBoxFlat for buttons.
    public static StyleBoxFlat ButtonNormal(int w = 2, int wBot = 4)
    {
        return new StyleBoxFlat
        {
            BgColor = AmberPrimary,
            BorderWidthLeft = w, BorderWidthTop = w,
            BorderWidthRight = w, BorderWidthBottom = wBot,
            BorderColor = new Color(0, 0, 0, 0.4f),
            CornerRadiusTopLeft = 4, CornerRadiusTopRight = 4,
            CornerRadiusBottomLeft = 4, CornerRadiusBottomRight = 4
        };
    }

    public static StyleBoxFlat ButtonHover(int w = 2, int wBot = 4)
    {
        return new StyleBoxFlat
        {
            BgColor = AmberBright,
            BorderWidthLeft = w, BorderWidthTop = w,
            BorderWidthRight = w, BorderWidthBottom = wBot,
            BorderColor = new Color(0, 0, 0, 0.5f),
            CornerRadiusTopLeft = 4, CornerRadiusTopRight = 4,
            CornerRadiusBottomLeft = 4, CornerRadiusBottomRight = 4
        };
    }

    public static StyleBoxFlat ButtonPressed(int wTop = 4, int w = 2)
    {
        return new StyleBoxFlat
        {
            BgColor = AmberDark,
            BorderWidthLeft = w, BorderWidthTop = wTop,
            BorderWidthRight = w, BorderWidthBottom = w,
            BorderColor = new Color(0, 0, 0, 0.5f),
            CornerRadiusTopLeft = 4, CornerRadiusTopRight = 4,
            CornerRadiusBottomLeft = 4, CornerRadiusBottomRight = 4
        };
    }

    /// Apply amber button theme to any Button node.
    /// Prefers pixel-art textures; falls back to StyleBoxFlat.
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

    /// Dark wood panel style.
    public static StyleBoxFlat WoodPanel()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(SurfaceMid, 0.85f),
            BorderWidthLeft = 2, BorderWidthTop = 2,
            BorderWidthRight = 2, BorderWidthBottom = 2,
            BorderColor = PanelBorder
        };
    }

    /// Parchment / ledger panel style.
    public static StyleBoxFlat ParchmentPanel()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(0.18f, 0.15f, 0.11f, 0.92f),
            BorderWidthLeft = 2, BorderWidthTop = 2,
            BorderWidthRight = 2, BorderWidthBottom = 2,
            BorderColor = new Color(AmberPrimary, 0.25f)
        };
    }

    /// Style a header/large label.
    public static void StyleHeader(Label label, int fontSize = 28)
    {
        label.AddThemeColorOverride("font_color", AmberPrimary);
        label.AddThemeFontSizeOverride("font_size", fontSize);
        label.AddThemeConstantOverride("outline_size", 2);
        label.AddThemeColorOverride("font_outline_color", new Color(0, 0, 0, 0.5f));
    }

    /// Style body text label.
    public static void StyleBody(Label label, int fontSize = 16)
    {
        label.AddThemeColorOverride("font_color", TextLight);
        label.AddThemeFontSizeOverride("font_size", fontSize);
    }

    /// Style dim/secondary text label.
    public static void StyleDim(Label label, int fontSize = 14)
    {
        label.AddThemeColorOverride("font_color", TextSubtitle);
        label.AddThemeFontSizeOverride("font_size", fontSize);
    }

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

    public static StyleBoxTexture BtnWideNormal() =>
        _cachedBtnWideNormal ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_normal.png");

    public static StyleBoxTexture BtnWideHover() =>
        _cachedBtnWideHover ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_hover.png");

    public static StyleBoxTexture BtnWidePressed() =>
        _cachedBtnWidePressed ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_wide_pressed.png");

    public static StyleBoxTexture BtnSmallNormal() =>
        _cachedBtnSmallNormal ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_normal.png");

    public static StyleBoxTexture BtnSmallHover() =>
        _cachedBtnSmallHover ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_hover.png");

    public static StyleBoxTexture BtnSmallPressed() =>
        _cachedBtnSmallPressed ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/btn_small_pressed.png");

    public static StyleBoxTexture SlotMaterial() =>
        _cachedSlotMaterial ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_material.png");

    public static StyleBoxTexture SlotResult() =>
        _cachedSlotResult ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_result.png");

    public static StyleBoxTexture SlotShortcut() =>
        _cachedSlotShortcut ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/slot_shortcut.png");

    public static StyleBoxTexture PanelParchment() =>
        _cachedPanelParchment ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/panel_parchment_9patch.png");

    public static StyleBoxTexture BarShortcutBg() =>
        _cachedBarShortcutBg ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_shortcut_bg.png");

    public static StyleBoxTexture BarTopPanel() =>
        _cachedBarTopPanel ??= TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_top_panel.png");
}
