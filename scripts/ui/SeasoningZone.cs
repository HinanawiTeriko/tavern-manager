using Godot;
using System;

public partial class SeasoningZone : Control
{
    private GameManager _gm;
    private string _appliedSeasoning;
    private Label _hintLabel;
    private Label _appliedLabel;
    private HBoxContainer _btnRow;

    public event Action<string> SeasoningApplied;
    public event Action SeasoningCleared;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        MouseFilter = MouseFilterEnum.Stop;
        ClipContents = true;

        _hintLabel = new Label
        {
            Text = "拖入香料",
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            MouseFilter = MouseFilterEnum.Ignore,
            AnchorRight = 1f,
            AnchorBottom = 0.6f,
            OffsetRight = 0,
            OffsetBottom = 0
        };
        _hintLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
        _hintLabel.AddThemeFontSizeOverride("font_size", 12);
        AddChild(_hintLabel);

        _appliedLabel = new Label
        {
            Visible = false,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            MouseFilter = MouseFilterEnum.Ignore,
            AnchorRight = 1f,
            AnchorBottom = 0.6f,
            OffsetRight = 0,
            OffsetBottom = 0
        };
        _appliedLabel.AddThemeColorOverride("font_color", new Color(0.3f, 0.9f, 0.3f));
        _appliedLabel.AddThemeFontSizeOverride("font_size", 12);
        AddChild(_appliedLabel);

        _btnRow = new HBoxContainer();
        _btnRow.AddThemeConstantOverride("separation", 2);
        AddChild(_btnRow);

        Visible = false;
    }

    public void Activate()
    {
        _appliedSeasoning = null;
        _appliedLabel.Visible = false;
        _hintLabel.Visible = true;
        RebuildButtons();
        // Position button row at bottom 40% of zone
        _btnRow.OffsetLeft = 2;
        _btnRow.OffsetTop = (int)(Size.Y * 0.6f);
        _btnRow.OffsetRight = (int)Size.X - 2;
        _btnRow.OffsetBottom = (int)Size.Y - 2;
        Visible = true;
        QueueRedraw();
    }

    public void Deactivate()
    {
        _appliedSeasoning = null;
        Visible = false;
        QueueRedraw();
    }

    public bool TryApplySeasoning(string itemKey)
    {
        if (!Visible) return false;
        var seasoning = _gm.Seasoning.GetSeasoning(itemKey);
        if (seasoning == null) return false;

        // Consume from inventory if it's an inventory item
        if (itemKey == "sleep_powder")
        {
            if (!_gm.Inventory.TryGetValue(itemKey, out var cnt) || cnt < 1)
                return false;
            _gm.Inventory[itemKey] = cnt - 1;
            if (_gm.Inventory[itemKey] <= 0) _gm.Inventory.Remove(itemKey);
            _gm.NotifyInventoryChanged();
        }

        ApplySeasoning(itemKey);
        return true;
    }

    public string GetAppliedSeasoning() => _appliedSeasoning;

    public void ClearSeasoning()
    {
        _appliedSeasoning = null;
        _appliedLabel.Visible = false;
        _hintLabel.Visible = true;
        RebuildButtons();
        QueueRedraw();
        SeasoningCleared?.Invoke();
    }

    private void ApplySeasoning(string key)
    {
        _appliedSeasoning = key;
        var seasoning = _gm.Seasoning.GetSeasoning(key);
        _appliedLabel.Text = seasoning != null ? $"已加: {seasoning.Name}" : $"已加: {key}";
        _appliedLabel.Visible = true;
        _hintLabel.Visible = false;
        foreach (var child in _btnRow.GetChildren()) child.QueueFree();
        QueueRedraw();
        SeasoningApplied?.Invoke(key);
    }

    private void RebuildButtons()
    {
        foreach (var child in _btnRow.GetChildren()) child.QueueFree();

        foreach (var kvp in _gm.Seasoning.Seasonings)
        {
            var key = kvp.Key;
            var data = kvp.Value;

            // sleep_powder only shown if player has it
            if (key == "sleep_powder")
            {
                if (!_gm.Inventory.TryGetValue(key, out var cnt) || cnt < 1)
                    continue;
            }

            var btn = new Button { Text = data.Name, CustomMinimumSize = new Vector2(28, 24) };
            ThemeColors.StyleSmallButton(btn, 10);
            btn.Pressed += () => ApplySeasoning(key);
            _btnRow.AddChild(btn);
        }
    }

    public override void _Draw()
    {
        var rect = new Rect2(Vector2.Zero, Size);
        // Background fill — dark brown, same family as MixingArea but distinct
        var bg = _appliedSeasoning != null
            ? new Color(0.15f, 0.13f, 0.06f)
            : new Color(0.13f, 0.10f, 0.07f);
        DrawRect(rect, bg);

        // Dashed amber border — indicates "drop here"
        var dashColor = new Color(ThemeColors.AmberPrimary, 0.5f);
        float dash = 5f, gap = 4f;
        float w = rect.Size.X, h = rect.Size.Y;

        // Top & bottom dashes
        for (float x = 0; x < w; x += dash + gap)
            DrawLine(new Vector2(x, 0), new Vector2(Math.Min(x + dash, w), 0), dashColor);
        for (float x = 0; x < w; x += dash + gap)
            DrawLine(new Vector2(x, h), new Vector2(Math.Min(x + dash, w), h), dashColor);

        // Left & right dashes
        for (float y = 0; y < h; y += dash + gap)
            DrawLine(new Vector2(0, y), new Vector2(0, Math.Min(y + dash, h)), dashColor);
        for (float y = 0; y < h; y += dash + gap)
            DrawLine(new Vector2(w, y), new Vector2(w, Math.Min(y + dash, h)), dashColor);
    }
}
