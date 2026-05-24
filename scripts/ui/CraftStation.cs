using Godot;
using System;

public partial class CraftStation : Control
{
    private ColorRect _slot1, _slot2, _resultSlot;
    private Button _heatBtn, _shakeBtn, _stirBtn;
    private Button _craftBtn, _serveBtn, _clearBtn;
    private Label _slot1Label, _slot2Label, _resultLabel;
    private ColorRect[] _shortcutSlots = new ColorRect[10];
    private Label[] _shortcutLabels = new Label[10];

    private bool _dragging;
    private string _dragMaterial;
    private Panel _dragPanel;

    // 手势进度
    private bool _heatDone, _shakeDone, _stirDone;
    private double _heatProgress;
    private const double HeatTime = 1.5;
    private bool _heating;

    public string[] BarMaterials = new string[10];
    public int[] BarCounts = new int[10];

    public string MaterialInSlot1 => _slot1Label != null && _slot1Label.Text != "空" ? _slot1Label.Text : null;
    public string MaterialInSlot2 => _slot2Label != null && _slot2Label.Text != "空" ? _slot2Label.Text : null;
    public string ResultKey { get; set; }

    public event Action CraftRequested;
    public event Action ServeRequested;
    public event Action ClearRequested;
    public event Action<string> GestureCompleted;

    public override void _Ready()
    {
        _slot1 = GetNode<ColorRect>("Slot1");
        _slot2 = GetNode<ColorRect>("Slot2");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _slot1Label = GetNode<Label>("Slot1/Label");
        _slot2Label = GetNode<Label>("Slot2/Label");
        _resultLabel = GetNode<Label>("ResultSlot/Label");

        // 按钮引用
        _heatBtn = GetNode<Button>("HeatBtn");
        _shakeBtn = GetNode<Button>("ShakeBtn");
        _stirBtn = GetNode<Button>("StirBtn");
        _craftBtn = GetNode<Button>("CraftBtn");
        _serveBtn = GetNode<Button>("ServeBtn");
        _clearBtn = GetNode<Button>("ClearBtn");

        _slot1Label.Text = "空";
        _slot2Label.Text = "空";
        _resultLabel.Text = "";

        // 手势按钮事件
        _heatBtn.Pressed += () => StartGesture("heat");
        _shakeBtn.Pressed += () => StartGesture("shake");
        _stirBtn.Pressed += () => { GestureCompleted?.Invoke("stir"); _stirDone = true; _stirBtn.Disabled = true; GD.Print("[CraftStation] 搅拌完成！"); };

        // 操作按钮事件
        _craftBtn.Pressed += () => CraftRequested?.Invoke();
        _serveBtn.Pressed += () => ServeRequested?.Invoke();
        _clearBtn.Pressed += () => { ClearRequested?.Invoke(); ResetGestureButtons(); };

        // 拖拽面板
        _dragPanel = new Panel { Visible = false, ZIndex = 100, MouseFilter = MouseFilterEnum.Ignore };
        AddChild(_dragPanel);

        // 快捷栏引用
        var bar = GetNode<Control>("../ShortcutBar");
        for (int i = 0; i < 10; i++)
        {
            _shortcutSlots[i] = bar.GetNode<ColorRect>($"Slot{i}");
            _shortcutLabels[i] = bar.GetNode<Label>($"Slot{i}/Label");
        }

        // 初始快捷栏
        string[] defaults = { "Ale", "Wine", "Bread", "Meat", "Herb" };
        for (int i = 0; i < 5; i++) { BarMaterials[i] = defaults[i]; BarCounts[i] = 5; }
        RefreshAll();
    }

    private void StartGesture(string name)
    {
        // 需要至少有一个材料在槽位里
        if (string.IsNullOrEmpty(MaterialInSlot1) && string.IsNullOrEmpty(MaterialInSlot2))
        {
            GD.Print("[CraftStation] 请先放入材料！");
            return;
        }

        switch (name)
        {
            case "heat":
                _heating = true;
                _heatProgress = 0;
                _heatBtn.Text = "加热中...";
                _heatBtn.Disabled = true;
                break;
            case "shake":
                GestureCompleted?.Invoke("shake");
                _shakeDone = true;
                _shakeBtn.Disabled = true;
                GD.Print("[CraftStation] 摇晃完成！");
                break;
        }
    }

    public override void _Process(double dt)
    {
        if (_heating)
        {
            _heatProgress += dt;
            float ratio = (float)(_heatProgress / HeatTime);
            if (_heatProgress >= HeatTime)
            {
                _heating = false;
                _heatDone = true;
                _heatBtn.Text = "加热 ✓";
                GestureCompleted?.Invoke("heat");
                GD.Print("[CraftStation] 加热完成！");
            }
            else
            {
                _heatBtn.Text = $"加热中 {ratio * 100:F0}%";
            }
        }
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
            _dragPanel.Position = mm.Position - new Vector2(24, 24);
    }

    private void TryPickUp(Vector2 pos)
    {
        // 成品槽优先——拖成品去快捷栏或客人区
        if (HitTest(_resultSlot, pos) && !string.IsNullOrEmpty(ResultKey))
        {
            string key = ResultKey;
            StartDrag(pos, key);
            _resultLabel.Text = "";
            ResultKey = null;
            return;
        }
        if (HitTest(_slot1, pos) && !string.IsNullOrEmpty(MaterialInSlot1))
        {
            StartDrag(pos, MaterialInSlot1);
            _slot1Label.Text = "空";
            _slot1.Color = new Color(0.15f, 0.12f, 0.1f);
            return;
        }
        if (HitTest(_slot2, pos) && !string.IsNullOrEmpty(MaterialInSlot2))
        {
            StartDrag(pos, MaterialInSlot2);
            _slot2Label.Text = "空";
            _slot2.Color = new Color(0.15f, 0.12f, 0.1f);
            return;
        }
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos) && !string.IsNullOrEmpty(BarMaterials[i]) && BarCounts[i] > 0)
            {
                BarCounts[i]--;
                string mat = BarMaterials[i];
                if (BarCounts[i] <= 0) BarMaterials[i] = null;
                RefreshShortcut(i);
                StartDrag(pos, mat);
                return;
            }
        }
    }

    private void TryDrop(Vector2 pos)
    {
        // 拖到客人区 → 上菜
        var customerArea = GetNode<Control>("../CustomerArea");
        if (HitTest(customerArea, pos))
        {
            // 如果是快捷栏的成品 → 检查是否匹配订单，直接上菜
            var gm = GetNode<GameManager>("/root/GameManager");
            if (gm.Guests.HasGuest && gm.Craft.Recipes.ContainsKey(_dragMaterial))
            {
                gm.Craft.CraftedKey = _dragMaterial;
                gm.Craft.GestureDragDone = true;
                gm.Craft.GestureShakeDone = true;
                gm.Craft.GestureHeatDone = true;
                gm.Craft.GestureStirDone = true;
                ResultKey = null;
                _resultLabel.Text = "";
                EndDrag();
                ServeRequested?.Invoke();
                return;
            }
            EndDrag();
            return;
        }
        if (HitTest(_slot1, pos) && string.IsNullOrEmpty(MaterialInSlot1))
        {
            _slot1Label.Text = _dragMaterial;
            _slot1.Color = GameManager.MaterialColor(_dragMaterial);
            EndDrag();
            GestureCompleted?.Invoke("drag");
            return;
        }
        if (HitTest(_slot2, pos) && string.IsNullOrEmpty(MaterialInSlot2))
        {
            _slot2Label.Text = _dragMaterial;
            _slot2.Color = GameManager.MaterialColor(_dragMaterial);
            EndDrag();
            GestureCompleted?.Invoke("drag");
            return;
        }
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
        ReturnDrag();
        EndDrag();
    }

    private void StartDrag(Vector2 pos, string material)
    {
        _dragging = true;
        _dragMaterial = material;
        _dragPanel.Visible = true;
        _dragPanel.Size = new Vector2(64, 64);
        _dragPanel.Position = pos - new Vector2(32, 32);
        var color = GameManager.MaterialColor(material);
        var sb = new StyleBoxFlat { BgColor = color, BorderWidthLeft = 2, BorderWidthTop = 2, BorderWidthRight = 2, BorderWidthBottom = 2 };
        _dragPanel.AddThemeStyleboxOverride("panel", sb);
    }

    private void EndDrag()
    {
        _dragging = false;
        _dragPanel.Visible = false;
        _dragMaterial = null;
    }

    private void ReturnDrag()
    {
        for (int i = 0; i < 10; i++)
        {
            if (BarMaterials[i] == _dragMaterial) { BarCounts[i]++; RefreshShortcut(i); return; }
        }
        for (int i = 0; i < 10; i++)
        {
            if (string.IsNullOrEmpty(BarMaterials[i])) { BarMaterials[i] = _dragMaterial; BarCounts[i] = 1; RefreshShortcut(i); return; }
        }
    }

    private void RefreshShortcut(int i)
    {
        _shortcutSlots[i].Color = string.IsNullOrEmpty(BarMaterials[i])
            ? new Color(0.1f, 0.08f, 0.06f)
            : GameManager.MaterialColor(BarMaterials[i]);
        // 显示中文名 + 数量
        string matName = BarMaterials[i] switch
        {
            "Ale" => "麦芽", "Wine" => "葡萄", "Bread" => "面粉", "Meat" => "生肉", "Herb" => "草药",
            _ => BarMaterials[i]
        };
        _shortcutLabels[i].Text = string.IsNullOrEmpty(BarMaterials[i]) ? "" : $"{matName} x{BarCounts[i]}";
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
        ResetGestureButtons();
    }

    public void ResetGestureButtons()
    {
        _heatDone = false;
        _shakeDone = false;
        _stirDone = false;
        _heating = false;
        _heatProgress = 0;
        _heatBtn.Text = "加热";
        _heatBtn.Disabled = false;
        _shakeBtn.Text = "摇晃";
        _shakeBtn.Disabled = false;
        _stirBtn.Text = "搅拌";
        _stirBtn.Disabled = false;
    }

    private static bool HitTest(Control c, Vector2 p)
    {
        var r = c.GetGlobalRect();
        return p.X >= r.Position.X && p.X <= r.End.X && p.Y >= r.Position.Y && p.Y <= r.End.Y;
    }
}
