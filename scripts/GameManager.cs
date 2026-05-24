using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using DialogueManagerRuntime;

public partial class GameManager : Node
{
    // ── 子系统 ──
    public EconomySystem Economy { get; private set; } = new();
    public DayCycleSystem DayCycle { get; private set; } = new();
    public NarrativeManager Narrative { get; private set; } = new();
    public GuestSystem Guests { get; private set; }
    public CraftSystem Craft { get; private set; } = new();

    // ── 库存 ──
    private Dictionary<string, int> _inv;
    public Dictionary<string, int> Inventory => _inv;
    public event Action InventoryChanged;
    public void NotifyInventoryChanged() => InventoryChanged?.Invoke();

    private static readonly Dictionary<string, string> MN = new()
    { ["Ale"] = "麦芽", ["Wine"] = "葡萄", ["Bread"] = "面粉", ["Meat"] = "生肉", ["Herb"] = "草药" };

    // ── 对话状态 ──
    private bool _isDialogueActive;

    // ── 当前场景引用 ──
    private TavernView _tavernView;
    private DayMapView _dayMapView;
    private EndingScreen _endingScreen;

    public override void _Ready()
    {
        // 加载库存数据
        _inv = LoadInitialInventory();

        // 加载配方数据
        Craft.LoadRecipes();

        // 加载 NPC 数据
        Narrative.LoadNpcData();

        // 初始化 GuestSystem
        Guests = new GuestSystem(Craft.RecipeKeys);
        Guests.GuestArrived += OnGuestArrived;
        Guests.GuestLeft += OnGuestLeft;
        Guests.PatienceLow += OnPatienceLow;

        // 初始化 Economy 变化事件
        Economy.Changed += () => RefreshTavernUI();

        // 初始化 DayCycle
        DayCycle.PhaseChanged += OnPhaseChanged;

        // ── 对话事件：暂停客人计时 ──
        DialogueManager.DialogueStarted += (_) => _isDialogueActive = true;
        DialogueManager.DialogueEnded += (_) => _isDialogueActive = false;

        GD.Print("[GameManager] 初始化完成");
    }

    public override void _Process(double dt)
    {
        // E键菜单
        if (Input.IsActionJustPressed("menu_toggle") && _tavernView != null)
            _tavernView.ToggleMenu();

        // 夜晚客人逻辑（对话进行中暂停计时）
        if (DayCycle.Phase == DayPhase.Night && _tavernView != null)
        {
            var menuOpen = _tavernView?.IsMenuOpen ?? false;
            if (!_isDialogueActive)
                Guests.Update(dt, Guests.HasGuest, menuOpen);
            if (Guests.HasGuest)
                _tavernView.UpdateTimer(Guests.CurrentGuest.Patience / GuestData.BasePatience);
        }
    }

    public void RegisterView(Node view)
    {
        if (view is TavernView tv)
        {
            _tavernView = tv;
            RefreshTavernUI();

            // ── 连接 CraftStation ──
            var craftStation = tv.GetNode<CraftStation>("CraftStation");
            if (craftStation != null)
            {
                craftStation.GestureCompleted += (gesture) => {
                    switch (gesture)
                    {
                        case "drag": Craft.GestureDragDone = true; break;
                        case "shake": Craft.GestureShakeDone = true; break;
                        case "heat": Craft.GestureHeatDone = true; break;
                        case "stir": Craft.GestureStirDone = true; break;
                    }
                    if (!string.IsNullOrEmpty(Craft.CraftedKey) && Craft.AllGesturesDone(Craft.CraftedKey))
                    {
                        tv.ShowMessage($"制作完成：{Craft.Recipes[Craft.CraftedKey].Name}！", Colors.GreenYellow);
                    }
                };

                craftStation.CraftRequested += () => {
                    Craft.ResetGestures();
                    var mat1 = craftStation.MaterialInSlot1;
                    var mat2 = craftStation.MaterialInSlot2;
                    if (string.IsNullOrEmpty(mat1))
                    {
                        tv.ShowMessage("请先拖入材料！", Colors.Orange);
                        return;
                    }
                    if (Craft.TryMatch(mat1, mat2, out var key))
                    {
                        Craft.CraftedKey = key;
                        craftStation.ResultKey = key;
                        craftStation.ShowResult(Craft.Recipes[key].Name, Colors.GreenYellow);
                        Craft.GestureDragDone = true;
                        tv.ShowMessage($"需要手势：{string.Join(", ", Craft.Recipes[key].Gestures)}", Colors.Yellow);
                    }
                    else
                    {
                        Craft.CraftedKey = null;
                        craftStation.ResultKey = null;
                        craftStation.ShowResult("无效配方", Colors.OrangeRed);
                        tv.ShowMessage("没有匹配的配方！", Colors.OrangeRed);
                    }
                };

                craftStation.ServeRequested += () => {
                    if (!Guests.HasGuest || string.IsNullOrEmpty(Craft.CraftedKey)) return;

                    if (!Craft.AllGesturesDone(Craft.CraftedKey))
                    {
                        tv.ShowMessage("请先完成所有手势！", Colors.Orange);
                        return;
                    }

                    if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
                    {
                        Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
                        Economy.AddReputation(2);
                        tv.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
                    }
                    else
                    {
                        tv.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
                    }
                    Craft.ClearCraftSlots();
                    craftStation.ClearSlots();
                    Guests.ClearGuest();
                };

                craftStation.ClearRequested += () => {
                    Craft.ClearCraftSlots();
                    craftStation.ClearSlots();
                    craftStation.ShowResult("", Colors.White);
                };
            }

            // Check for scheduled NPCs today
            var npcsToday = Narrative.GetTodayScenes(Economy.CurrentDay);
            if (npcsToday.Count > 0)
            {
                Narrative.TodayImportantNpc = npcsToday[0].Id;
            }

            // 检查今日是否有重要 NPC 到访（由 NarrativeManager 外部设置）
            if (!string.IsNullOrEmpty(Narrative.TodayImportantNpc))
            {
                var npc = Narrative.AllNpcs.FirstOrDefault(n => n.Id == Narrative.TodayImportantNpc);
                if (npc != null)
                {
                    var scene = npc.Scenes.FirstOrDefault(s => s.Day == Economy.CurrentDay);
                    Guests.SpawnImportant(npc.Id, scene?.Order ?? "Bread");
                }
            }
        }
        else if (view is DayMapView dmv)
        {
            _dayMapView = dmv;
            _dayMapView.ShowDay(Economy.CurrentDay, EconomySystem.MaxDays);
            _dayMapView.GatheringConfirmed += OnGatheringConfirmed;
        }
        else if (view is EndingScreen es)
        {
            _endingScreen = es;
            _endingScreen.ShowEndings(Economy.Gold, Economy.Reputation, Narrative.Endings);
        }
    }

    // ── 采集结果处理 ──
    private void OnGatheringConfirmed(Dictionary<string, int> assignments)
    {
        var rng = new Random();
        var locations = LoadLocationsData();
        foreach (var (locId, count) in assignments)
        {
            var loc = System.Array.Find(locations, l => l.Id == locId);
            if (loc == null) continue;
            for (int i = 0; i < count; i++)
            {
                var mat = loc.Materials[rng.Next(loc.Materials.Length)];
                _inv[mat] = _inv.TryGetValue(mat, out var existing) ? existing + 1 : 1;
            }
        }
        InventoryChanged?.Invoke();
        DayCycle.NextPhase(); // Day → Night
    }

    private LocationData[] LoadLocationsData()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        if (file == null) return System.Array.Empty<LocationData>();
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText(), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        return data?.Locations ?? System.Array.Empty<LocationData>();
    }

    // ── 昼夜阶段切换 ──
    private void OnPhaseChanged(DayPhase phase)
    {
        if (phase == DayPhase.Night)
        {
            GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/Tavern.tscn");
        }
        else
        {
            Economy.CurrentDay++;
            if (Economy.CurrentDay > EconomySystem.MaxDays)
            {
                GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/EndingScreen.tscn");
            }
            else
            {
                GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/DayMap.tscn");
            }
        }
    }

    // ── 客人事件 ──
    private void OnGuestArrived(GuestData guest)
    {
        if (_tavernView == null) return;

        // 始终显示客人信息
        var recipe = Craft.GetRecipe(guest.OrderKey);
        var displayName = guest.Name;
        if (guest.HasDialogue)
        {
            var npc = Narrative.AllNpcs.FirstOrDefault(n => n.Id == guest.NpcId);
            if (npc != null) displayName = npc.Name;
        }
        _tavernView.ShowCustomer(displayName, recipe?.Name ?? guest.OrderKey, guest.NpcId ?? "guest");

        if (guest.HasDialogue)
        {
            Narrative.TodayImportantNpc = guest.NpcId;
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.dialogue";
            CallDeferred(nameof(StartDialogueDeferred), dialoguePath);
        }
    }

    private void StartDialogueDeferred(string dialoguePath)
    {
        var dialogueResource = GD.Load<Resource>(dialoguePath);
        if (dialogueResource == null)
        {
            GD.PrintErr($"[GameManager] 对话文件加载失败: {dialoguePath}");
            return;
        }
        var extraStates = new Godot.Collections.Array<Variant> { Narrative.DialogueVars };
        var balloon = DialogueManager.ShowExampleDialogueBalloon(dialogueResource, "start", extraStates);
        if (balloon != null)
            balloon.Set("will_block_other_input", false);
    }

    private void OnGuestLeft()
    {
        if (_tavernView != null)
            _tavernView.HideCustomer();
    }

    private void OnPatienceLow()
    {
        if (_tavernView != null)
            _tavernView.ShowMessage("客人等得不耐烦了……", Colors.Orange);
    }

    // ── 打烊 ──
    public void EndNight()
    {
        if (DayCycle.Phase != DayPhase.Night) return;
        if (Guests.HasGuest)
        {
            _tavernView?.ShowMessage("还有客人在等呢！", Colors.Orange);
            return;
        }
        DayCycle.NextPhase();
    }

    // ── UI ──
    private void RefreshTavernUI()
    {
        if (_tavernView == null) return;
        _tavernView.UpdateTopBar(Economy.Gold, Economy.Reputation,
            Economy.CurrentDay, EconomySystem.MaxDays);
    }

    public static Color MaterialColor(string key)
    {
        return key switch
        {
            "Ale" => new(0.8f, 0.6f, 0.2f),
            "Wine" => new(0.6f, 0.1f, 0.2f),
            "Bread" => new(0.7f, 0.55f, 0.3f),
            "Meat" => new(0.65f, 0.2f, 0.1f),
            "Herb" => new(0.2f, 0.7f, 0.2f),
            _ => Colors.Gray
        };
    }

    private static readonly Dictionary<string, string> MaterialIconPaths = new()
    {
        ["Ale"] = "res://assets/textures/icons/materials/ale.png",
        ["Wine"] = "res://assets/textures/icons/materials/wine.png",
        ["Bread"] = "res://assets/textures/icons/materials/bread.png",
        ["Meat"] = "res://assets/textures/icons/materials/meat.png",
        ["Herb"] = "res://assets/textures/icons/materials/herb.png",
    };

    public Texture2D TryLoadMaterialIcon(string key)
    {
        if (MaterialIconPaths.TryGetValue(key, out var path))
            return TextureManager.TryLoad(path);
        return null;
    }

    // ── 库存加载 ──
    private Dictionary<string, int> LoadInitialInventory()
    {
        try
        {
            using var file = FileAccess.Open("res://data/inventory_default.json", FileAccess.ModeFlags.Read);
            if (file != null)
            {
                var json = file.GetAsText();
                return JsonSerializer.Deserialize<Dictionary<string, int>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                    ?? new() { ["Ale"] = 20, ["Wine"] = 20, ["Bread"] = 20, ["Meat"] = 20, ["Herb"] = 20 };
            }
        }
        catch { }
        return new() { ["Ale"] = 20, ["Wine"] = 20, ["Bread"] = 20, ["Meat"] = 20, ["Herb"] = 20 };
    }

    // ── 兼容旧 MainInit ──
    public void StartGame(Node _) { } // 旧入口，新架构通过 RegisterView 自动检测

    // ── 场景就绪检测 ──
    public override void _EnterTree()
    {
        GetTree().NodeAdded += OnNodeAdded;
    }

    private void OnNodeAdded(Node node)
    {
        CallDeferred(nameof(RegisterViewDeferred), node);
    }

    private void RegisterViewDeferred(Node node)
    {
        if (node is TavernView tv) RegisterView(tv);
        else if (node is DayMapView dmv) RegisterView(dmv);
        else if (node is EndingScreen es) RegisterView(es);
    }
}
