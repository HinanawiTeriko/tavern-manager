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

    public void ToggleMenu() => _menuPanel.Visible = !_menuPanel.Visible;

    private void OnEndNight()
    {
        GetTree().ChangeSceneToFile("res://scenes/ui/DayMap.tscn");
    }

    public void BuildRecipeList(Dictionary<string, RecipeData> recipes)
    {
        var recipeList = _menuPanel.GetNode<VBoxContainer>("RecipePanel/RecipeList");
        foreach (var child in recipeList.GetChildren())
            child.QueueFree();

        foreach (var (key, recipe) in recipes)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            row.CustomMinimumSize = new Vector2(0, 36);

            var label = new Label
            {
                Text = $"{recipe.Name}  {recipe.Price}金  [{string.Join(",", recipe.Gestures)}]"
            };
            label.AddThemeColorOverride("font_color", Colors.White);
            label.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(label);
            recipeList.AddChild(row);
        }
    }
}
