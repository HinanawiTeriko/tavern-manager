using Godot;
using System;
using System.Collections.Generic;

public partial class CraftStation : Control
{
    private ColorRect _slot1, _slot2, _resultSlot;
    private ColorRect _fireZone, _shakerZone, _stirZone;
    private Label _slot1Label, _slot2Label, _resultLabel;
    private ColorRect[] _shortcutSlots = new ColorRect[10];
    private Label[] _shortcutLabels = new Label[10];

    private bool _dragging;
    private string _dragMaterial;
    private int _dragCount;
    private Panel _dragPanel;
    private Vector2 _dragOffset;
    private int _dragSourceIndex = -1;

    private double _heatProgress;
    private const double HeatTime = 1.5;
    private bool _heating;

    private bool _shaking;
    private Vector2 _lastShakePos;
    private int _shakeCount;
    private const int ShakeThreshold = 6;

    public string[] BarMaterials = new string[10];
    public int[] BarCounts = new int[10];

    public string MaterialInSlot1 => _slot1Label != null && _slot1Label.Text != "空" ? _slot1Label.Text : null;
    public string MaterialInSlot2 => _slot2Label != null && _slot2Label.Text != "空" ? _slot2Label.Text : null;
    public string ResultKey { get; set; }

    public event Action CraftRequested;
    public event Action ServeRequested;
    public event Action ClearRequested;
    // Gesture completion events
    public event Action<string> GestureCompleted; // gesture name: "drag","shake","heat","stir"

    public override void _Ready()
    {
        _slot1 = GetNode<ColorRect>("Slot1");
        _slot2 = GetNode<ColorRect>("Slot2");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _fireZone = GetNode<ColorRect>("FireZone");
        _shakerZone = GetNode<ColorRect>("ShakerZone");
        _stirZone = GetNode<ColorRect>("StirZone");
        _slot1Label = GetNode<Label>("Slot1/Label");
        _slot2Label = GetNode<Label>("Slot2/Label");
        _resultLabel = GetNode<Label>("ResultSlot/Label");

        _slot1Label.Text = "空";
        _slot2Label.Text = "空";
        _resultLabel.Text = "";

        // Create drag preview panel
        _dragPanel = new Panel { Visible = false, ZIndex = 100, MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_dragPanel);

        // Reference shortcut bar slots
        var bar = GetNode<Control>("../ShortcutBar");
        for (int i = 0; i < 10; i++)
        {
            _shortcutSlots[i] = bar.GetNode<ColorRect>($"Slot{i}");
            _shortcutLabels[i] = bar.GetNode<Label>($"Slot{i}/Label");
        }

        // Initialize shortcut bar with default materials
        string[] defaults = {"Ale","Wine","Bread","Meat","Herb"};
        for (int i = 0; i < 5; i++)
        {
            BarMaterials[i] = defaults[i];
            BarCounts[i] = 5;
        }
        RefreshAll();
    }

    public override void _Input(InputEvent e)
    {
        if (e is InputEventMouseButton mb)
        {
            if (mb.ButtonIndex == MouseButton.Left)
            {
                if (mb.Pressed && !_dragging) TryPickUp(mb.Position);
                else if (!mb.Pressed && _dragging) TryDrop(mb.Position);
            }
        }
        if (_dragging && e is InputEventMouseMotion mm)
            UpdateDragPosition(mm.Position);

        // Shake detection while holding
        if (_shaking && e is InputEventMouseMotion sm)
        {
            var delta = sm.Position - _lastShakePos;
            if (Math.Abs(delta.X) > 40 || Math.Abs(delta.Y) > 40)
            {
                _shakeCount++;
                if (_shakeCount >= ShakeThreshold)
                {
                    _shaking = false;
                    GestureCompleted?.Invoke("shake");
                    _shakerZone.Color = new Color(0.2f, 0.3f, 0.8f);
                    GD.Print("[CraftStation] 摇晃完成！");
                }
            }
            _lastShakePos = sm.Position;
        }
    }

    public override void _Process(double dt)
    {
        if (_heating)
        {
            _heatProgress += dt;
            float ratio = (float)(_heatProgress / HeatTime);
            _fireZone.Color = new Color(1f, 1f - ratio, 0f);
            if (_heatProgress >= HeatTime)
            {
                _heating = false;
                GestureCompleted?.Invoke("heat");
                _fireZone.Color = new Color(0.8f, 0.2f, 0.1f);
                GD.Print("[CraftStation] 加热完成！");
            }
        }
    }

    private void TryPickUp(Vector2 pos)
    {
        // Check craft slots first
        if (HitTest(_slot1, pos) && !string.IsNullOrEmpty(MaterialInSlot1))
        {
            StartDrag(pos, -1, MaterialInSlot1);
            _slot1Label.Text = "空";
            _slot1.Color = new Color(0.15f, 0.12f, 0.1f);
            return;
        }
        if (HitTest(_slot2, pos) && !string.IsNullOrEmpty(MaterialInSlot2))
        {
            StartDrag(pos, -1, MaterialInSlot2);
            _slot2Label.Text = "空";
            _slot2.Color = new Color(0.15f, 0.12f, 0.1f);
            return;
        }
        // Check shortcut bar
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos) && !string.IsNullOrEmpty(BarMaterials[i]) && BarCounts[i] > 0)
            {
                BarCounts[i]--;
                string mat = BarMaterials[i];
                if (BarCounts[i] <= 0) BarMaterials[i] = null;
                RefreshShortcut(i);
                StartDrag(pos, i, mat);
                return;
            }
        }
    }

    private void TryDrop(Vector2 pos)
    {
        // Drop on craft slot 1
        if (HitTest(_slot1, pos) && string.IsNullOrEmpty(MaterialInSlot1))
        {
            _slot1Label.Text = _dragMaterial;
            _slot1.Color = GameManager.MaterialColor(_dragMaterial);
            EndDrag();
            GestureCompleted?.Invoke("drag");
            return;
        }
        // Drop on craft slot 2
        if (HitTest(_slot2, pos) && string.IsNullOrEmpty(MaterialInSlot2))
        {
            _slot2Label.Text = _dragMaterial;
            _slot2.Color = GameManager.MaterialColor(_dragMaterial);
            EndDrag();
            GestureCompleted?.Invoke("drag");
            return;
        }
        // Drop on shortcut bar
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos))
            {
                if (string.IsNullOrEmpty(BarMaterials[i]))
                {
                    BarMaterials[i] = _dragMaterial;
                    BarCounts[i] = 1;
                    EndDrag();
                    RefreshShortcut(i);
                    return;
                }
                else if (BarMaterials[i] == _dragMaterial)
                {
                    BarCounts[i]++;
                    EndDrag();
                    RefreshShortcut(i);
                    return;
                }
            }
        }
        // Drop on fire zone => start heating
        if (HitTest(_fireZone, pos))
        {
            _heating = true;
            _heatProgress = 0;
            EndDrag();
            return;
        }
        // Drop on shaker zone => start shaking
        if (HitTest(_shakerZone, pos))
        {
            _shaking = true;
            _lastShakePos = pos;
            _shakeCount = 0;
            EndDrag();
            return;
        }
        // Drop on stir zone => instant stir complete
        if (HitTest(_stirZone, pos))
        {
            GestureCompleted?.Invoke("stir");
            GD.Print("[CraftStation] 搅拌完成！");
            EndDrag();
            return;
        }
        // Otherwise return to source
        ReturnDrag();
        EndDrag();
    }

    private void StartDrag(Vector2 pos, int index, string material)
    {
        _dragging = true;
        _dragSourceIndex = index;
        _dragMaterial = material;
        _dragPanel.Visible = true;
        _dragPanel.Size = new Vector2(48, 48);
        _dragPanel.Position = pos - new Vector2(24, 24);
        var color = GameManager.MaterialColor(material);
        var sb = new StyleBoxFlat { BgColor = color, BorderWidthLeft = 2, BorderWidthTop = 2, BorderWidthRight = 2, BorderWidthBottom = 2 };
        _dragPanel.AddThemeStyleboxOverride("panel", sb);
    }

    private void EndDrag()
    {
        _dragging = false;
        _dragPanel.Visible = false;
        _dragSourceIndex = -1;
        _dragMaterial = null;
    }

    private void ReturnDrag()
    {
        // Return material to shortcut bar
        for (int i = 0; i < 10; i++)
        {
            if (BarMaterials[i] == _dragMaterial)
            {
                BarCounts[i]++;
                RefreshShortcut(i);
                return;
            }
        }
        for (int i = 0; i < 10; i++)
        {
            if (string.IsNullOrEmpty(BarMaterials[i]))
            {
                BarMaterials[i] = _dragMaterial;
                BarCounts[i] = 1;
                RefreshShortcut(i);
                return;
            }
        }
    }

    private void UpdateDragPosition(Vector2 pos)
    {
        _dragPanel.Position = pos - new Vector2(24, 24);
    }

    private void RefreshShortcut(int i)
    {
        _shortcutSlots[i].Color = string.IsNullOrEmpty(BarMaterials[i])
            ? new Color(0.1f, 0.08f, 0.06f)
            : GameManager.MaterialColor(BarMaterials[i]);
        _shortcutLabels[i].Text = string.IsNullOrEmpty(BarMaterials[i]) ? "" : $"x{BarCounts[i]}";
    }

    public void RefreshAll()
    {
        for (int i = 0; i < 10; i++) RefreshShortcut(i);
    }

    public void ShowResult(string text, Color color)
    {
        _resultLabel.Text = text;
        _resultLabel.AddThemeColorOverride("font_color", color);
    }

    public void ClearSlots()
    {
        _slot1Label.Text = "空";
        _slot2Label.Text = "空";
        _slot1.Color = new Color(0.15f, 0.12f, 0.1f);
        _slot2.Color = new Color(0.15f, 0.12f, 0.1f);
        _resultLabel.Text = "";
        ResultKey = null;
    }

    private static bool HitTest(Control c, Vector2 p)
    {
        var r = c.GetGlobalRect();
        return p.X >= r.Position.X && p.X <= r.End.X && p.Y >= r.Position.Y && p.Y <= r.End.Y;
    }
}
