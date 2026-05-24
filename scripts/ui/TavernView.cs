using Godot;
using System.Collections.Generic;
using System.Linq;

public partial class TavernView : Node2D
{
    private Sprite2D _bgSprite;
    private TextureRect _customerSprite;
    private Label _customerName;
    private Label _orderBubble;
    private ProgressBar _timerBar;
    private Label _goldLabel;
    private Label _repLabel;
    private Label _dayLabel;
    private Panel _menuPanel;
    private Label _messageLabel;
    private Button _endNightBtn;
    private ColorRect _dialogueOverlay;
    private GameManager _gm;

    public Control CraftStation => GetNode<Control>("CraftStation");
    public Control ShortcutBar => GetNode<Control>("ShortcutBar");
    public bool IsMenuOpen => _menuPanel.Visible;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _bgSprite = GetNode<Sprite2D>("Background");
        _customerSprite = GetNode<TextureRect>("CustomerArea/CustomerSprite");
        _customerName = GetNode<Label>("CustomerArea/CustomerName");
        _orderBubble = GetNode<Label>("CustomerArea/OrderBubble");
        _timerBar = GetNode<ProgressBar>("CustomerArea/TimerBar");
        _goldLabel = GetNode<Label>("TopPanel/GoldLabel");
        _repLabel = GetNode<Label>("TopPanel/ReputationLabel");
        _dayLabel = GetNode<Label>("TopPanel/DayLabel");
        _messageLabel = GetNode<Label>("BottomBar/MessageLabel");
        _endNightBtn = GetNode<Button>("TopPanel/EndNightBtn");
        _dialogueOverlay = GetNode<ColorRect>("DialogueOverlay");

        _menuPanel = GetNode<Panel>("OverlayMenu");
        GetNode<Button>("TopPanel/MenuButton").Pressed += ToggleMenu;
        GetNode<Button>("OverlayMenu/CloseBtn").Pressed += ToggleMenu;
        _menuPanel.Visible = false;

        _endNightBtn.Pressed += OnEndNight;

        // -- Apply design system theme --
        ApplyTheme();
    }

    private void ApplyTheme()
    {
        // Background: try pixel-art tavern_bg, fallback to generated gradient
        var bgTex = TextureManager.TryLoad("res://assets/textures/backgrounds/tavern_bg.png");
        if (bgTex != null)
        {
            _bgSprite.Texture = bgTex;
        }
        else
        {
            var placeholderGradient = new GradientTexture2D
            {
                Width = 1280, Height = 720,
                Gradient = new Gradient { Colors = new[] { ThemeColors.BackgroundDeep, ThemeColors.SurfaceLow }, Offsets = new[] { 0f, 1f } }
            };
            _bgSprite.Texture = placeholderGradient;
        }

        // Customer area
        _customerName.AddThemeColorOverride("font_color", ThemeColors.TextLight);
        _customerName.AddThemeFontSizeOverride("font_size", 18);
        _orderBubble.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        _orderBubble.AddThemeFontSizeOverride("font_size", 15);

        // Top bar
        _goldLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
        _goldLabel.AddThemeFontSizeOverride("font_size", 16);
        _repLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
        _repLabel.AddThemeFontSizeOverride("font_size", 16);
        _dayLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        _dayLabel.AddThemeFontSizeOverride("font_size", 15);

        // Buttons in top bar
        ThemeColors.StyleButton(GetNode<Button>("TopPanel/MenuButton"), 14);
        ThemeColors.StyleButton(_endNightBtn, 14);

        // Menu panel: try 9-patch parchment texture, fallback to flat
        var parchmentTex = ThemeColors.PanelParchment();
        _menuPanel.AddThemeStyleboxOverride("panel", (StyleBox)parchmentTex ?? ThemeColors.ParchmentPanel());

        // Menu tab buttons
        ThemeColors.StyleButton(GetNode<Button>("OverlayMenu/TabBtns/BtnRecipes"), 14);
        ThemeColors.StyleButton(GetNode<Button>("OverlayMenu/TabBtns/BtnBackpack"), 14);
        ThemeColors.StyleButton(GetNode<Button>("OverlayMenu/CloseBtn"), 14);

        // Tab switching
        var recipePanel = GetNode<Control>("OverlayMenu/RecipePanel");
        var backpackPanel = GetNode<Control>("OverlayMenu/BackpackPanel");
        GetNode<Button>("OverlayMenu/TabBtns/BtnRecipes").Pressed += () => { recipePanel.Visible = true; backpackPanel.Visible = false; };
        GetNode<Button>("OverlayMenu/TabBtns/BtnBackpack").Pressed += () => { recipePanel.Visible = false; backpackPanel.Visible = true; };

        // Live-refresh backpack when inventory changes
        _gm.InventoryChanged += OnInventoryChanged;

        // Bottom bar message
        _messageLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
        _messageLabel.AddThemeFontSizeOverride("font_size", 14);

        // Timer bar: try patience bar textures, fallback to flat
        var patienceBgTex = TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_patience_bg.png");
        var patienceFillTex = TextureManager.TryLoadStyleBox("res://assets/textures/ui/bar_patience_fill.png");
        _timerBar.AddThemeStyleboxOverride("background",
            (StyleBox)patienceBgTex ?? new StyleBoxFlat
            {
                BgColor = new Color(ThemeColors.SurfaceHigh, 0.8f),
                BorderWidthLeft = 1, BorderWidthTop = 1,
                BorderWidthRight = 1, BorderWidthBottom = 1,
                BorderColor = ThemeColors.PanelBorder
            });
        if (patienceFillTex != null)
            _timerBar.AddThemeStyleboxOverride("fill", patienceFillTex);
        _timerBar.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);

        // Top panel background strip
        var topBarTex = ThemeColors.BarTopPanel();
        var topPanelBg = GetNodeOrNull<Panel>("TopPanelBg");
        if (topPanelBg != null)
            topPanelBg.AddThemeStyleboxOverride("panel", (StyleBox)topBarTex ?? new StyleBoxFlat
            {
                BgColor = new Color(ThemeColors.BackgroundDeep, 0.85f),
                BorderWidthBottom = 1,
                BorderColor = ThemeColors.PanelBorder,
            });

        // Shortcut bar background
        var shortcutBarBgTex = ThemeColors.BarShortcutBg();
        var shortcutBg = GetNodeOrNull<Panel>("ShortcutBarBg");
        if (shortcutBg != null)
            shortcutBg.AddThemeStyleboxOverride("panel", (StyleBox)shortcutBarBgTex ?? new StyleBoxFlat
            {
                BgColor = new Color(ThemeColors.SurfaceLow, 0.8f),
                BorderWidthTop = 1,
                BorderColor = ThemeColors.PanelBorder,
            });
    }

    private static readonly Dictionary<string, string> NpcTextureKeys = new()
    {
        ["ryan"] = "ryan_neutral",
        ["mira"] = "mira_neutral",
    };

    public void ShowCustomer(string name, string order, string npcId = "guest")
    {
        string texKey = NpcTextureKeys.TryGetValue(npcId, out var k) ? k : npcId;
        var tex = TextureManager.TryLoad($"res://assets/textures/characters/{texKey}.png");
        if (tex != null)
        {
            _customerSprite.Texture = tex;
            _customerSprite.Modulate = Colors.White;
        }
        else
        {
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
            _customerSprite.Modulate = Colors.White;
        }
        _customerSprite.Visible = true;
        _customerName.Text = name;
        _orderBubble.Text = $"「来一份{order}！」";
        _orderBubble.Visible = true;
    }

    public void HideCustomer()
    {
        _customerSprite.Visible = false;
        _customerName.Text = "等待中……";
        _orderBubble.Visible = false;
    }

    public void UpdateTimer(double ratio) => _timerBar.Value = ratio * 100;

    public void UpdateTopBar(int gold, int rep, int day, int maxDay)
    {
        _goldLabel.Text = $"金币：{gold}";
        _repLabel.Text = $"声望：{rep}";
        _dayLabel.Text = $"第{day}/{maxDay}天";
    }

    public void ShowMessage(string text, Color color)
    {
        _messageLabel.Text = text;
        _messageLabel.AddThemeColorOverride("font_color", color);
    }

    public void SetDialogueMode(bool active)
    {
        _dialogueOverlay.Visible = active;
        CraftStation.MouseFilter = active
            ? Control.MouseFilterEnum.Ignore
            : Control.MouseFilterEnum.Stop;
        ShortcutBar.MouseFilter = active
            ? Control.MouseFilterEnum.Ignore
            : Control.MouseFilterEnum.Stop;
    }

    public override void _ExitTree()
    {
        if (_gm != null)
            _gm.InventoryChanged -= OnInventoryChanged;
    }

    private void OnInventoryChanged()
    {
        if (!GodotObject.IsInstanceValid(this)) return;
        if (_menuPanel.Visible) BuildBackpackList(_gm.Craft);
    }

    public void ToggleMenu()
    {
        _menuPanel.Visible = !_menuPanel.Visible;
        if (_menuPanel.Visible)
        {
            BuildRecipeList(_gm.Craft);
            BuildBackpackList(_gm.Craft);
        }
    }

    private void OnEndNight()
    {
        _gm.EndNight();
    }

    public void BuildRecipeList(CraftSystem craft)
    {
        var recipeList = _menuPanel.GetNode<VBoxContainer>("RecipePanel/RecipeList");
        foreach (var child in recipeList.GetChildren())
            child.QueueFree();

        foreach (var (key, recipe) in craft.Recipes)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 6);
            row.CustomMinimumSize = new Vector2(0, 32);

            foreach (var mat in recipe.Materials)
            {
                var iconTex = _gm.TryLoadMaterialIcon(mat);
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
                if (mat != recipe.Materials[recipe.Materials.Length - 1])
                {
                    var plus = new Label { Text = "+" };
                    plus.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
                    row.AddChild(plus);
                }
            }

            if (craft.IsRecipeUnlocked(key))
            {
                var arrow = new Label { Text = $" = {recipe.Name}  {recipe.Price}金" };
                arrow.AddThemeColorOverride("font_color", ThemeColors.TextLight);
                arrow.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(arrow);
            }
            else
            {
                var locked = new Label { Text = " = ??? (未解锁)" };
                locked.AddThemeColorOverride("font_color", ThemeColors.TextDim);
                locked.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(locked);
            }

            var gestureText = string.Join(" ", recipe.Gestures.Select(g => g switch
            {
                "drag" => "[拖拽]",
                "shake" => "[摇晃]",
                "heat" => "[加热]",
                "stir" => "[搅拌]",
                _ => $"[{g}]"
            }));
            var gestureLabel = new Label { Text = gestureText };
            gestureLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
            gestureLabel.AddThemeFontSizeOverride("font_size", 13);
            row.AddChild(gestureLabel);

            recipeList.AddChild(row);
        }
    }

    public void BuildBackpackList(CraftSystem craft)
    {
        var inventory = _gm.Inventory;
        var backpackList = _menuPanel.GetNode<VBoxContainer>("BackpackPanel/BackpackList");
        foreach (var child in backpackList.GetChildren())
            child.QueueFree();

        foreach (var (mat, count) in inventory)
        {
            if (count <= 0) continue;
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 6);
            row.CustomMinimumSize = new Vector2(0, 32);
            row.SetMeta("material_key", mat);

            var iconTex = _gm.TryLoadMaterialIcon(mat);
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

            var displayName = craft.Materials.TryGetValue(mat, out var md) ? md.Name : mat;
            var label = new Label { Text = $"{displayName}  x{count}" };
            label.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            label.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(label);

            backpackList.AddChild(row);
        }
    }
}
