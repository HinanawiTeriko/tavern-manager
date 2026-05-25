using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class CraftStation : Control
{
    // ── Child component refs ──
    private MixingArea _mixingArea;
    private ProductPanel _productPanel;
    private SeasoningZone _seasoningZone;
    private Control _operationButtons; // HBoxContainer holding dynamic op buttons
    private Button _clearBtn;
    private ColorRect _resultSlot;
    private Label _resultLabel;

    // ── Combine query bar ──
    private HBoxContainer _combineQueryBar;
    private Label _combineQueryLabel;
    private Button _combineYesBtn;
    private Button _combineNoBtn;
    private string _pendingA, _pendingB;

    // ── Drag state ──
    private bool _dragging;
    private string _dragMaterial;
    private ColorRect _dragPanel;
    private Control _overlayMenu;
    private ColorRect _dialogueOverlay;

    // ── Shortcut bar cache ──
    private string[] BarMaterials = new string[10];
    private int[] BarCounts = new int[10];
    private ColorRect[] _shortcutSlots = new ColorRect[10];
    private Label[] _shortcutLabels = new Label[10];

    private GameManager _gm;

    // ── Events ──
    public event Action<string, string> ServeRequested; // (itemKey, seasoningTag or null)
    public event Action ClearRequested;
    public event Action<string> GestureCompleted; // kept for compat

    // ── Heat progress ──
    private bool _heating;
    private double _heatProgress;
    private const double HeatTime = 1.5;
    private string _heatTargetOp;
    private Button _heatBtnRef;

    // ── Stir progress ──
    private bool _stirring;
    private int _stirCircles;
    private const int StirTarget = 3;
    private Vector2 _stirLastMouse;
    private double _stirTotalAngle;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");

        // Find child components (all exist in the scene)
        _mixingArea = GetNode<MixingArea>("MixingArea");
        _productPanel = GetNode<ProductPanel>("ProductPanel");
        _seasoningZone = GetNode<SeasoningZone>("SeasoningZone");
        _seasoningZone.Visible = false;
        _operationButtons = GetNode<Control>("OperationButtons");
        _clearBtn = GetNode<Button>("ClearBtn");
        _resultSlot = GetNode<ColorRect>("ResultSlot");
        _resultLabel = GetNode<Label>("ResultSlot/Label");
        _overlayMenu = GetNodeOrNull<Control>("../OverlayMenu");
        _dialogueOverlay = GetNodeOrNull<ColorRect>("../DialogueOverlay");

        // Combine query bar
        _combineQueryBar = GetNode<HBoxContainer>("CombineQueryBar");
        _combineQueryLabel = GetNode<Label>("CombineQueryBar/Label");
        _combineYesBtn = GetNode<Button>("CombineQueryBar/YesBtn");
        _combineNoBtn = GetNode<Button>("CombineQueryBar/NoBtn");
        _combineQueryBar.Visible = false;

        // ── MixingArea events ──
        _mixingArea.CombineQuery += (a, b) => ShowCombineQuery(a, b);
        _mixingArea.ContentsChanged += RefreshOperationButtons;
        _mixingArea.ContentsChanged += CheckResultReady;

        // ── Query bar buttons ──
        _combineYesBtn.Pressed += () => {
            _combineQueryBar.Visible = false;
            var result = _gm.Craft.GetCombineResult(_pendingA, _pendingB);
            if (result != null)
            {
                _mixingArea.Clear();
                _mixingArea.ForceAddItem(result);
            }
            else
                _mixingArea.ForceAddItems(_pendingA, _pendingB);
        };
        _combineNoBtn.Pressed += () => {
            _combineQueryBar.Visible = false;
            _mixingArea.ForceAddItem(_pendingA);
        };

        // ── Clear button ──
        _clearBtn.Pressed += () => {
            foreach (var item in _mixingArea.Contents)
                AddToInventory(item);
            _mixingArea.Clear();
            ClearResultSlot();
            _seasoningZone.Deactivate();
            ClearRequested?.Invoke();
        };

        // ── Seasoning events ──
        _seasoningZone.SeasoningApplied += (seasoning) => {
            _resultSlot.SetMeta("seasoning", seasoning);
        };

        // ── Style buttons ──
        ThemeColors.StyleSmallButton(_clearBtn, 12);
        ThemeColors.StyleSmallButton(_combineYesBtn, 12);
        ThemeColors.StyleSmallButton(_combineNoBtn, 12);

        // Result slot styling
        _resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);

        // ── Shortcut bar init ──
        InitShortcutBar();
        InitDragPanel();

        SyncFromInventory();
        _gm.InventoryChanged += SyncFromInventory;
    }

    public override void _ExitTree()
    {
        if (_gm != null) _gm.InventoryChanged -= SyncFromInventory;
    }

    // ── Combine query ──
    private void ShowCombineQuery(string a, string b)
    {
        _pendingA = a;
        _pendingB = b;
        var itemA = _gm.Craft.GetItem(a);
        var itemB = _gm.Craft.GetItem(b);
        _combineQueryLabel.Text = $"混合 {itemA?.Name ?? a} 和 {itemB?.Name ?? b}？";
        _combineQueryBar.Visible = true;
    }

    // ── Operation buttons ──
    private void RefreshOperationButtons()
    {
        foreach (var child in _operationButtons.GetChildren())
            child.QueueFree();

        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;

        var firstKey = contents[0];
        var ops = _gm.Craft.GetOperations(firstKey);

        if (ops.Count == 0) return;

        foreach (var kvp in ops)
        {
            var op = kvp.Key;
            var result = kvp.Value;
            var label = op switch { "heat" => "加热", "stir" => "搅拌", "shake" => "摇晃", "pour" => "倒出", _ => op };
            var btn = new Button { Text = label };
            ThemeColors.StyleSmallButton(btn, 12);

            switch (op)
            {
                case "heat":
                    btn.ButtonDown += () => StartHeat(btn, result);
                    btn.ButtonUp += () => StopHeat();
                    break;
                case "stir":
                    btn.ButtonDown += () => StartStir(btn, result);
                    btn.ButtonUp += () => StopStir();
                    break;
                case "shake":
                    btn.Pressed += () => ExecuteOperation(result);
                    break;
                default:
                    btn.Pressed += () => ExecuteOperation(result);
                    break;
            }
            _operationButtons.AddChild(btn);
        }
    }

    // ── Heat gesture ──
    private void StartHeat(Button btn, string resultKey)
    {
        _heating = true;
        _heatProgress = 0;
        _heatTargetOp = resultKey;
        _heatBtnRef = btn;
        btn.Text = "加热中...";
    }

    private void StopHeat()
    {
        if (!_heating) return;
        _heating = false;
        if (_heatProgress < HeatTime)
        {
            _heatBtnRef.Text = "加热";
        }
        _heatBtnRef = null;
    }

    // ── Stir gesture ──
    private void StartStir(Button btn, string resultKey)
    {
        _stirring = true;
        _stirCircles = 0;
        _stirTotalAngle = 0;
        _stirLastMouse = GetViewport().GetMousePosition();
        _heatTargetOp = resultKey;
        _heatBtnRef = btn;
        btn.Text = "搅拌中... (转圈)";
    }

    private void StopStir()
    {
        if (!_stirring) return;
        _stirring = false;
        if (_stirCircles < StirTarget)
        {
            _heatBtnRef.Text = "搅拌";
        }
        _heatBtnRef = null;
    }

    private void ExecuteOperation(string resultKey)
    {
        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;
        _mixingArea.ConsumeAndReplace(new[] { contents[0] }, resultKey);
        GestureCompleted?.Invoke("done");
    }

    // ── Check if single item with no further operations → move to result slot ──
    private void CheckResultReady()
    {
        var contents = _mixingArea.Contents;
        if (contents.Count == 1)
        {
            var key = contents[0];
            if (!_gm.Craft.HasOperations(key))
            {
                MoveToResultSlot(key);
                _mixingArea.Clear();
            }
        }
    }

    private void MoveToResultSlot(string key)
    {
        var item = _gm.Craft.GetItem(key);
        if (item != null)
        {
            _resultSlot.Color = new Color(item.Color[0], item.Color[1], item.Color[2]);
            _resultLabel.Text = item.Name;
        }
        else
        {
            _resultLabel.Text = key;
        }
        _resultSlot.SetMeta("item_key", key);
        _resultSlot.SetMeta("seasoning", "");

        _seasoningZone.Activate();
    }

    private void ClearResultSlot()
    {
        _resultLabel.Text = "";
        _resultSlot.Color = new Color(0.06f, 0.05f, 0.04f);
        _resultSlot.RemoveMeta("item_key");
        _resultSlot.RemoveMeta("seasoning");
        _seasoningZone.Deactivate();
    }

    // ── _Process: heat/stir progress + drag ──
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
                if (_heatBtnRef != null) _heatBtnRef.Text = "加热 ✓";
                GestureCompleted?.Invoke("heat");
                ExecuteOperation(_heatTargetOp);
            }
            else if (_heatBtnRef != null)
            {
                _heatBtnRef.Text = $"加热中 {ratio * 100:F0}%";
            }
        }

        if (_stirring)
        {
            var mouse = GetViewport().GetMousePosition();
            var btnCenter = _heatBtnRef != null ? _heatBtnRef.GlobalPosition : Vector2.Zero;
            var prev = _stirLastMouse - btnCenter;
            var cur = mouse - btnCenter;
            var anglePrev = Math.Atan2(prev.Y, prev.X);
            var angleCur = Math.Atan2(cur.Y, cur.X);
            var delta = angleCur - anglePrev;

            // Normalize delta to [-PI, PI] to handle angle wrap-around
            if (delta > Math.PI) delta -= Math.PI * 2;
            else if (delta < -Math.PI) delta += Math.PI * 2;

            if (Math.Abs(delta) > 0.005) _stirTotalAngle += delta;
            _stirLastMouse = mouse;

            _stirCircles = (int)(Math.Abs(_stirTotalAngle) / (Math.PI * 2));
            if (_heatBtnRef != null)
                _heatBtnRef.Text = $"搅拌... {_stirCircles}/{StirTarget}圈";
            if (_stirCircles >= StirTarget)
            {
                _stirring = false;
                if (_heatBtnRef != null) _heatBtnRef.Text = "搅拌 ✓";
                GestureCompleted?.Invoke("stir");
                ExecuteOperation(_heatTargetOp);
            }
        }
    }

    // ── Drag & Drop (input handling) ──
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
        // Menu open: check backpack list items
        if (_overlayMenu?.Visible == true)
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
            return;
        }

        // Result slot: pick up the finished item
        var serveKey = _resultSlot.GetMeta("item_key", "").AsString();
        if (!string.IsNullOrEmpty(serveKey) && HitTest(_resultSlot, pos))
        {
            StartDrag(pos, serveKey);
            _resultLabel.Text = "";
            ClearResultSlot();
            return;
        }

        // MixingArea: pick up an item from mixing area
        if (HitTest(_mixingArea, pos))
        {
            var contents = _mixingArea.Contents;
            if (contents.Count > 0)
            {
                string mat = contents[contents.Count - 1];
                _mixingArea.RemoveItem(mat);
                StartDrag(pos, mat);
                return;
            }
        }

        // Shortcut bar: pick up material
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
            // Drop on customer area → serve
            var customerArea = GetNode<Control>("../CustomerArea");
            if (HitTest(customerArea, pos))
            {
                if (_gm.Guests.HasGuest && !string.IsNullOrEmpty(_dragMaterial))
                {
                    var serveKey = _dragMaterial;
                    var serveSeasoning = _seasoningZone.GetAppliedSeasoning();
                    var item = _gm.Craft.GetItem(serveKey);
                    if (item != null)
                    {
                        _resultSlot.SetMeta("item_key", serveKey);
                        _resultSlot.SetMeta("seasoning", serveSeasoning ?? "");
                        EndDrag();
                        ServeRequested?.Invoke(serveKey, serveSeasoning);
                        return;
                    }
                }
                ReturnDrag();
                EndDrag();
                return;
            }

            // Drop on MixingArea → add item
            if (HitTest(_mixingArea, pos) && !string.IsNullOrEmpty(_dragMaterial))
            {
                _mixingArea.AddItem(_dragMaterial);
                EndDrag();
                return;
            }
        }

        // Drop on SeasoningZone
        if (HitTest(_seasoningZone, pos) && !string.IsNullOrEmpty(_dragMaterial))
        {
            if (_seasoningZone.TryApplySeasoning(_dragMaterial))
            {
                EndDrag();
                return;
            }
        }

        // Drop on shortcut bar
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
        var item = _gm.Craft.GetItem(material);
        _dragPanel.Color = item != null ? new Color(item.Color[0], item.Color[1], item.Color[2]) : Colors.Gray;
    }

    private void EndDrag()
    {
        _dragging = false;
        _dragPanel.Visible = false;
        _dragMaterial = null;
    }

    private void ReturnDrag()
    {
        AddToInventory(_dragMaterial);
    }

    // ── Shortcut bar ──
    private void InitShortcutBar()
    {
        var bar = GetNode<Control>("../ShortcutBar");
        bar.MouseFilter = MouseFilterEnum.Ignore;
        for (int i = 0; i < 10; i++)
        {
            _shortcutSlots[i] = bar.GetNode<ColorRect>($"Slot{i}");
            _shortcutSlots[i].MouseFilter = MouseFilterEnum.Ignore;
            _shortcutLabels[i] = bar.GetNode<Label>($"Slot{i}/Label");
            _shortcutLabels[i].MouseFilter = MouseFilterEnum.Ignore;

            var slotInnerColor = new Color(0.08f, 0.06f, 0.04f);
            _shortcutSlots[i].Color = slotInnerColor;
        }
    }

    private void InitDragPanel()
    {
        var dragCanvas = new CanvasLayer { Layer = 1 };
        GetParent().AddChild(dragCanvas);
        _dragPanel = new ColorRect { Visible = false, MouseFilter = MouseFilterEnum.Ignore };
        dragCanvas.AddChild(_dragPanel);
    }

    private void SyncFromInventory()
    {
        var inv = _gm.Inventory;
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
        foreach (var kvp in inv)
        {
            var key = kvp.Key;
            var count = kvp.Value;
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

    private void RefreshShortcut(int i)
    {
        if (string.IsNullOrEmpty(BarMaterials[i]))
        {
            _shortcutSlots[i].Color = new Color(0.1f, 0.08f, 0.06f);
            _shortcutLabels[i].Text = "";
        }
        else
        {
            var item = _gm.Craft.GetItem(BarMaterials[i]);
            _shortcutSlots[i].Color = item != null
                ? new Color(item.Color[0], item.Color[1], item.Color[2])
                : Colors.Gray;
            _shortcutLabels[i].Text = $"{item?.Name ?? BarMaterials[i]} x{BarCounts[i]}";
        }
    }

    public void RefreshAll()
    {
        for (int i = 0; i < 10; i++) RefreshShortcut(i);
    }

    private static bool HitTest(Control c, Vector2 p)
    {
        var r = c.GetGlobalRect();
        return p.X >= r.Position.X && p.X <= r.End.X && p.Y >= r.Position.Y && p.Y <= r.End.Y;
    }
}
