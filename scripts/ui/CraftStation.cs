using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

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
    private ColorRect _dragPanel;

    // 手势进度
    private bool _heatDone, _shakeDone, _stirDone;
    private double _heatProgress;
    private const double HeatTime = 1.5;
    private bool _heating;

    // 快捷栏显示缓存：同步自 GameManager._inv
    private string[] BarMaterials = new string[10];
    private int[] BarCounts = new int[10];

    private GameManager _gm;
    private Control _overlayMenu;
    private ColorRect _dialogueOverlay;

    public string MaterialInSlot1 => _slot1Label != null && _slot1Label.Text != "空" ? _slot1Label.Text : null;
    public string MaterialInSlot2 => _slot2Label != null && _slot2Label.Text != "空" ? _slot2Label.Text : null;
    public string ResultKey { get; set; }

    public event Action CraftRequested;
    public event Action ServeRequested;
    public event Action ClearRequested;
    public event Action<string> GestureCompleted;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _overlayMenu = GetNodeOrNull<Control>("../OverlayMenu");
        _dialogueOverlay = GetNodeOrNull<ColorRect>("../DialogueOverlay");

        _slot1 = GetNode<ColorRect>("Slot1");
        _slot2 = GetNode<ColorRect>("Slot2");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _slot1Label = GetNode<Label>("Slot1/Label");
        _slot2Label = GetNode<Label>("Slot2/Label");
        _resultLabel = GetNode<Label>("ResultSlot/Label");

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
        _serveBtn.Pressed += () => {
            if (!_gm.Guests.HasGuest) { GD.Print("[CraftStation] 没有客人，无法上菜"); return; }
            if (string.IsNullOrEmpty(_gm.Craft.CraftedKey)) { GD.Print("[CraftStation] 请先合成"); return; }
            // 按键上菜与拖拽上菜保持一致，自动完成全部手势
            _gm.Craft.GestureDragDone = true;
            _gm.Craft.GestureShakeDone = true;
            _gm.Craft.GestureHeatDone = true;
            _gm.Craft.GestureStirDone = true;
            ServeRequested?.Invoke();
        };
        // Clear: 先清空槽位，再退回材料（避免退回过程中异常导致槽位无法清空）
        _clearBtn.Pressed += () => {
            var m1 = MaterialInSlot1;
            var m2 = MaterialInSlot2;
            ClearRequested?.Invoke();
            ResetGestureButtons();
            if (m1 != null) AddToInventory(m1);
            if (m2 != null) AddToInventory(m2);
        };

        // 拖拽面板：放在独立 CanvasLayer 上，确保渲染在所有 UI 之上
        var dragCanvas = new CanvasLayer { Layer = 1 };
        GetParent().AddChild(dragCanvas);
        _dragPanel = new ColorRect { Visible = false, MouseFilter = MouseFilterEnum.Ignore };
        dragCanvas.AddChild(_dragPanel);

        // 快捷栏引用
        var bar = GetNode<Control>("../ShortcutBar");
        bar.MouseFilter = MouseFilterEnum.Ignore;
        for (int i = 0; i < 10; i++)
        {
            _shortcutSlots[i] = bar.GetNode<ColorRect>($"Slot{i}");
            _shortcutSlots[i].MouseFilter = MouseFilterEnum.Ignore;
            _shortcutLabels[i] = bar.GetNode<Label>($"Slot{i}/Label");
            _shortcutLabels[i].MouseFilter = MouseFilterEnum.Ignore;
        }

        // 合成槽和自身设为 Ignore，让鼠标事件穿透到 _Input，不然 GUI 系统会吃掉事件
        MouseFilter = MouseFilterEnum.Ignore;
        _slot1.MouseFilter = MouseFilterEnum.Ignore;
        _slot2.MouseFilter = MouseFilterEnum.Ignore;
        _slot1Label.MouseFilter = MouseFilterEnum.Ignore;
        _slot2Label.MouseFilter = MouseFilterEnum.Ignore;
        _resultSlot.MouseFilter = MouseFilterEnum.Ignore;
        _resultLabel.MouseFilter = MouseFilterEnum.Ignore;

        // Apply small button theme to gesture/action buttons
        ThemeColors.StyleSmallButton(_heatBtn, 12);
        ThemeColors.StyleSmallButton(_shakeBtn, 12);
        ThemeColors.StyleSmallButton(_stirBtn, 12);
        ThemeColors.StyleSmallButton(_craftBtn, 12);
        ThemeColors.StyleSmallButton(_serveBtn, 12);
        ThemeColors.StyleSmallButton(_clearBtn, 12);

        // Improved slot visuals (closer to pixel-art slot design)
        var slotInnerColor = new Color(0.08f, 0.06f, 0.04f);
        _slot1.Color = slotInnerColor;
        _slot2.Color = slotInnerColor;
        _resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);
        for (int i = 0; i < 10; i++)
            _shortcutSlots[i].Color = slotInnerColor;

        // 从库存同步到快捷栏（必须在初始化槽位颜色之后调用，否则颜色会被覆盖）
        SyncFromInventory();
        _gm.InventoryChanged += SyncFromInventory;
    }

    public override void _ExitTree()
    {
        if (_gm != null)
            _gm.InventoryChanged -= SyncFromInventory;
    }

    /// 从 GameManager._inv 重建快捷栏显示
    private void SyncFromInventory()
    {
        var inv = _gm.Inventory;
        // 保留已有槽位类型，更新数量
        for (int i = 0; i < 10; i++)
        {
            if (!string.IsNullOrEmpty(BarMaterials[i]) && inv.TryGetValue(BarMaterials[i], out var cnt) && cnt > 0)
            {
                BarCounts[i] = cnt;
                RefreshShortcut(i);
            }
            else
            {
                BarMaterials[i] = null;
                BarCounts[i] = 0;
            }
        }
        // 填充新出现的材料到空槽位
        foreach (var (key, count) in inv)
        {
            if (count <= 0) continue;
            bool alreadyShown = false;
            for (int i = 0; i < 10; i++)
                if (BarMaterials[i] == key) { alreadyShown = true; break; }
            if (alreadyShown) continue;
            for (int i = 0; i < 10; i++)
            {
                if (string.IsNullOrEmpty(BarMaterials[i]))
                {
                    BarMaterials[i] = key;
                    BarCounts[i] = count;
                    RefreshShortcut(i);
                    break;
                }
            }
        }
        // 刷新所有空槽位
        for (int i = 0; i < 10; i++)
            if (string.IsNullOrEmpty(BarMaterials[i]))
                RefreshShortcut(i);
    }

    private void AddToInventory(string key, int amount = 1)
    {
        if (string.IsNullOrEmpty(key)) return;
        _gm.Inventory.TryGetValue(key, out var cur);
        _gm.Inventory[key] = cur + amount;
        _gm.NotifyInventoryChanged();
    }

    private void RemoveFromInventory(string key, int amount = 1)
    {
        if (string.IsNullOrEmpty(key)) return;
        if (_gm.Inventory.TryGetValue(key, out var cur))
        {
            int remaining = cur - amount;
            if (remaining <= 0)
                _gm.Inventory.Remove(key);
            else
                _gm.Inventory[key] = remaining;
        }
        _gm.NotifyInventoryChanged();
    }

    private void StartGesture(string name)
    {
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
        if (_overlayMenu?.Visible == true) return;

        if (_dragging)
            _dragPanel.Position = GetViewport().GetMousePosition() - new Vector2(32, 32);

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
        if (_overlayMenu?.Visible == true) return;
        if (_dialogueOverlay?.Visible == true) return;

        if (e is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed && !_dragging) TryPickUp(mb.Position);
            else if (!mb.Pressed && _dragging) TryDrop(mb.Position);
        }
    }

    private void TryPickUp(Vector2 pos)
    {
        // 菜单打开时：优先检查背包列表项
        if (_overlayMenu?.Visible == true)
        {
            var backpackPanel = GetNodeOrNull<Control>("../OverlayMenu/BackpackPanel");
            if (backpackPanel?.Visible == true)
            {
                var backpackList = GetNodeOrNull<VBoxContainer>("../OverlayMenu/BackpackPanel/BackpackList");
                if (backpackList != null)
                {
                    foreach (Control row in backpackList.GetChildren())
                    {
                        if (HitTest(row, pos))
                        {
                            string mat = row.GetMeta("material_key").AsString();
                            if (!string.IsNullOrEmpty(mat) && _gm.Inventory.TryGetValue(mat, out var cnt) && cnt > 0)
                            {
                                RemoveFromInventory(mat);
                                StartDrag(pos, mat);
                                return;
                            }
                        }
                    }
                }
            }
            return; // 菜单打开时不拾取其他区域
        }

        // 成品槽优先
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
                string mat = BarMaterials[i];
                RemoveFromInventory(mat);
                StartDrag(pos, mat);
                return;
            }
        }
    }

    private void TryDrop(Vector2 pos)
    {
        var menuOpen = _overlayMenu?.Visible == true;

        if (!menuOpen)
        {
            // 拖到客人区 → 上菜
            var customerArea = GetNode<Control>("../CustomerArea");
            if (HitTest(customerArea, pos))
            {
                var gm = GetNode<GameManager>("/root/GameManager");
                if (gm.Guests.HasGuest && _dragMaterial != null && gm.Craft.Recipes.ContainsKey(_dragMaterial))
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
                // 条件不满足（没客人/不是成品）→ 归还材料
                ReturnDrag();
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
        }

        // 快捷栏（菜单打开或关闭时均可拖入）
        for (int i = 0; i < 10; i++)
        {
            if (HitTest(_shortcutSlots[i], pos))
            {
                if (string.IsNullOrEmpty(BarMaterials[i]))
                {
                    BarMaterials[i] = _dragMaterial;
                    AddToInventory(_dragMaterial);
                    EndDrag();
                    RefreshShortcut(i);
                    return;
                }
                else if (BarMaterials[i] == _dragMaterial)
                {
                    AddToInventory(_dragMaterial);
                    EndDrag();
                    RefreshShortcut(i);
                    return;
                }
            }
        }

        if (menuOpen) { ReturnDrag(); EndDrag(); return; }
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
        _dragPanel.Color = GameManager.MaterialColor(material);
    }

    private void EndDrag()
    {
        _dragging = false;
        _dragPanel.Visible = false;
        _dragMaterial = null;
    }

    private void ReturnDrag()
    {
        // 归还拖拽中的材料到库存
        AddToInventory(_dragMaterial);
    }

    private void RefreshShortcut(int i)
    {
        _shortcutSlots[i].Color = string.IsNullOrEmpty(BarMaterials[i])
            ? new Color(0.1f, 0.08f, 0.06f)
            : GameManager.MaterialColor(BarMaterials[i]);
        string matName = BarMaterials[i] switch
        {
            "Ale" => "麦芽", "Wine" => "葡萄", "Bread" => "面粉", "Meat" => "生肉", "Herb" => "草药", "SleepPowder" => "沉睡花粉",
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
        _resultLabel.RemoveThemeColorOverride("font_color");
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
