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
    public static void StyleButton(Button btn, int fontSize = 16)
    {
        btn.AddThemeFontSizeOverride("font_size", fontSize);
        btn.AddThemeColorOverride("font_color", TextOnAmber);
        btn.AddThemeColorOverride("font_hover_color", TextOnAmber);
        btn.AddThemeColorOverride("font_pressed_color", TextOnAmber);
        btn.AddThemeStyleboxOverride("normal", ButtonNormal());
        btn.AddThemeStyleboxOverride("hover", ButtonHover());
        btn.AddThemeStyleboxOverride("pressed", ButtonPressed());
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
}
