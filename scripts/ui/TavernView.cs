using Godot;
using System.Collections.Generic;

public partial class TavernView : Node2D
{
    private ColorRect _bgPlaceholder;
    private ColorRect _customerSprite;
    private Label _customerName;
    private Label _orderBubble;
    private ProgressBar _timerBar;
    private Label _goldLabel;
    private Label _repLabel;
    private Label _dayLabel;
    private Panel _menuPanel;
    private Label _messageLabel;
    private Button _endNightBtn;

    public Control CraftStation => GetNode<Control>("CraftStation");
    public Control ShortcutBar => GetNode<Control>("ShortcutBar");
    public bool IsMenuOpen => _menuPanel.Visible;

    public override void _Ready()
    {
        _bgPlaceholder = GetNode<ColorRect>("Background");
        _customerSprite = GetNode<ColorRect>("CustomerArea/CustomerSprite");
        _customerName = GetNode<Label>("CustomerArea/CustomerName");
        _orderBubble = GetNode<Label>("CustomerArea/OrderBubble");
        _timerBar = GetNode<ProgressBar>("CustomerArea/TimerBar");
        _goldLabel = GetNode<Label>("TopPanel/GoldLabel");
        _repLabel = GetNode<Label>("TopPanel/ReputationLabel");
        _dayLabel = GetNode<Label>("TopPanel/DayLabel");
        _messageLabel = GetNode<Label>("BottomBar/MessageLabel");
        _endNightBtn = GetNode<Button>("TopPanel/EndNightBtn");

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
        // Background
        _bgPlaceholder.Color = ThemeColors.BackgroundDeep;

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

        // Menu panel
        _menuPanel.AddThemeStyleboxOverride("panel", ThemeColors.ParchmentPanel());

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
        var gm = GetNode<GameManager>("/root/GameManager");
        gm.InventoryChanged += () => { if (_menuPanel.Visible) BuildBackpackList(gm.Craft); };

        // Bottom bar message
        _messageLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
        _messageLabel.AddThemeFontSizeOverride("font_size", 14);

        // Timer bar
        var timerStyle = new StyleBoxFlat
        {
            BgColor = new Color(ThemeColors.SurfaceHigh, 0.8f),
            BorderWidthLeft = 1, BorderWidthTop = 1,
            BorderWidthRight = 1, BorderWidthBottom = 1,
            BorderColor = ThemeColors.PanelBorder
        };
        _timerBar.AddThemeStyleboxOverride("background", timerStyle);
        _timerBar.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
    }

    public void SetBackgroundColor(Color c) => _bgPlaceholder.Color = c;

    public void ShowCustomer(string name, string order, Color color)
    {
        _customerSprite.Color = color;
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

    public void ToggleMenu()
    {
        _menuPanel.Visible = !_menuPanel.Visible;
        if (_menuPanel.Visible)
        {
            var gm = GetNode<GameManager>("/root/GameManager");
            BuildRecipeList(gm.Craft);
            BuildBackpackList(gm.Craft);
        }
    }

    private void OnEndNight()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        gm.EndNight();
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
                var box = new ColorRect
                {
                    Color = craft.MaterialColor(mat),
                    CustomMinimumSize = new Vector2(36, 20)
                };
                row.AddChild(box);
                if (mat != recipe.Materials[recipe.Materials.Length - 1])
                {
                    var plus = new Label { Text = "+" };
                    plus.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
                    row.AddChild(plus);
                }
            }

            var arrow = new Label { Text = $" = {recipe.Name}  {recipe.Price}金" };
            arrow.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            arrow.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(arrow);

            recipeList.AddChild(row);
        }
    }

    public void BuildBackpackList(CraftSystem craft)
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        var inventory = gm.Inventory;
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

            var box = new ColorRect
            {
                Color = craft.MaterialColor(mat),
                CustomMinimumSize = new Vector2(36, 20)
            };
            row.AddChild(box);

            var displayName = craft.Materials.TryGetValue(mat, out var md) ? md.Name : mat;
            var label = new Label { Text = $"{displayName}  x{count}" };
            label.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            label.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(label);

            backpackList.AddChild(row);
        }
    }
}
