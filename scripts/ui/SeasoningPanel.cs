using Godot;
using System;

public partial class SeasoningPanel : Control
{
    private HBoxContainer _btnRow;
    private GameManager _gm;
    private string _currentItemKey;

    public event Action<string> SeasoningApplied; // seasoning key
    public event Action SeasoningSkipped;         // 不加香料

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _btnRow = new HBoxContainer();
        AddChild(_btnRow);
        Visible = false;
    }

    /// 对某个成品显示香料选项
    public void ShowFor(string itemKey)
    {
        if (!_gm.Craft.IsProduct(itemKey)) { Visible = false; return; }

        _currentItemKey = itemKey;

        // 清旧按钮
        foreach (var child in _btnRow.GetChildren()) child.QueueFree();

        foreach (var kvp in _gm.Seasoning.Seasonings)
        {
            var key = kvp.Key;
            var data = kvp.Value;
            var btn = new Button { Text = data.Name };
            ThemeColors.StyleSmallButton(btn, 12);
            btn.Pressed += () => {
                SeasoningApplied?.Invoke(key);
                Hide();
            };
            _btnRow.AddChild(btn);
        }

        var skipBtn = new Button { Text = "不加" };
        ThemeColors.StyleSmallButton(skipBtn, 12);
        skipBtn.Pressed += () => { SeasoningSkipped?.Invoke(); Hide(); };
        _btnRow.AddChild(skipBtn);

        Visible = true;
    }
}
