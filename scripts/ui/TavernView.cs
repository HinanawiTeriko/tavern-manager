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

            // Material blocks
            foreach (var mat in recipe.Materials)
            {
                var box = new ColorRect {
                    Color = craft.MaterialColor(mat),
                    CustomMinimumSize = new Vector2(36, 20)
                };
                row.AddChild(box);
                if (mat != recipe.Materials[recipe.Materials.Length - 1])
                {
                    var plus = new Label { Text = "+" };
                    plus.AddThemeColorOverride("font_color", Colors.White);
                    row.AddChild(plus);
                }
            }

            var arrow = new Label { Text = $" = {recipe.Name}  {recipe.Price}金" };
            arrow.AddThemeColorOverride("font_color", Colors.White);
            arrow.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(arrow);

            recipeList.AddChild(row);
        }
    }

    public void BuildBackpackList(Dictionary<string, int> inventory, Dictionary<string, string> matNames, CraftSystem craft)
    {
        var backpackList = _menuPanel.GetNode<VBoxContainer>("BackpackPanel/BackpackList");
        foreach (var child in backpackList.GetChildren())
            child.QueueFree();

        foreach (var (mat, count) in inventory)
        {
            if (count <= 0) continue;
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 6);
            row.CustomMinimumSize = new Vector2(0, 32);

            var box = new ColorRect {
                Color = craft.MaterialColor(mat),
                CustomMinimumSize = new Vector2(36, 20)
            };
            row.AddChild(box);

            var displayName = matNames.ContainsKey(mat) ? matNames[mat] : mat;
            var label = new Label { Text = $"{displayName}  x{count}" };
            label.AddThemeColorOverride("font_color", Colors.White);
            label.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(label);

            backpackList.AddChild(row);
        }
    }
}
