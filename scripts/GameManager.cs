using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using DialogueManagerRuntime;

public class LedgerData
{
    public int Day;
    public int GoldToday;
    public int RepToday;
    public int GoldTotal;
    public int RepTotal;
    public int GuestsServed;
    public int OrdersSuccess;
    public int OrdersFailed;
    public List<(string NpcName, string NpcTitle, string FateText)> NpcFates;
}

public partial class GameManager : Node
{
    // ── 子系统 ──
    public EconomySystem Economy { get; private set; } = new();
    public DayCycleSystem DayCycle { get; private set; } = new();
    public NarrativeManager Narrative { get; private set; } = new();
    public ShopSystem Shop { get; private set; } = new();
    public GuestSystem Guests { get; private set; }
    public CraftSystem Craft { get; private set; } = new();

    // ── 库存 ──
    private Dictionary<string, int> _inv;
    public Dictionary<string, int> Inventory => _inv;
    public event Action InventoryChanged;
    public void NotifyInventoryChanged()
    {
        if (_inv.TryGetValue("SleepPowder", out var sp) && sp > 0)
            Narrative.SetVar("has_sleep_powder", true);
        InventoryChanged?.Invoke();
    }

    // ── 对话状态 ──
    private bool _isDialogueActive;
    private string _dialoguePhase;

    // ── 当前场景引用 ──
    private TavernView _tavernView;
    private DayMapView _dayMapView;
    private EndingScreen _endingScreen;

    public LedgerData CurrentLedgerData { get; private set; }

    public override void _Ready()
    {
        // 加载库存数据
        _inv = LoadInitialInventory();

        // 加载配方数据
        Craft.LoadRecipes();

        // 加载 NPC 数据
        Narrative.LoadNpcData();

        // 初始化 ShopSystem
        Shop.LoadConfig();

        // 初始化 GuestSystem
        Guests = new GuestSystem(() => Craft.UnlockedRecipes.ToArray());
        Guests.GuestArrived += OnGuestArrived;
        Guests.GuestLeft += OnGuestLeft;
        Guests.PatienceLow += OnPatienceLow;

        // 初始化 Economy 变化事件
        Economy.Changed += () => RefreshTavernUI();

        // 初始化 DayCycle
        DayCycle.PhaseChanged += OnPhaseChanged;

        // ── 对话事件：暂停客人计时 ──
        DialogueManager.DialogueStarted += (_) => _isDialogueActive = true;
        DialogueManager.DialogueEnded += (_) => OnDialogueEnded();

        GD.Print("[GameManager] 初始化完成");
    }

    public override void _Process(double dt)
    {
        // E键菜单（仅在酒馆场景有效）
        if (Input.IsActionJustPressed("menu_toggle") && _tavernView != null && GodotObject.IsInstanceValid(_tavernView))
            _tavernView.ToggleMenu();

        // 夜晚客人逻辑（对话进行中暂停计时）
        // 仅在酒馆场景有效，LedgerScreen 虽也是 Night 但不应该有客人逻辑
        if (DayCycle.Phase == DayPhase.Night && _tavernView != null && GodotObject.IsInstanceValid(_tavernView))
        {
            var menuOpen = _tavernView.IsMenuOpen;
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
                        if (!Craft.IsRecipeUnlocked(key))
                        {
                            tv.ShowMessage("配方未解锁！请前往商店购买。", Colors.Orange);
                            return;
                        }
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

                    var isImportant = Guests.CurrentGuest.HasDialogue;
                    var npcId = Guests.CurrentGuest.NpcId;

                    if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
                    {
                        Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
                        Economy.AddReputation(2);
                        Guests.RecordOrderSuccess();
                        tv.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
                        if (isImportant) Narrative.SetVar("serve_result", "success");
                    }
                    else
                    {
                        Guests.RecordOrderFailed();
                        tv.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
                        if (isImportant) Narrative.SetVar("serve_result", "fail");
                    }
                    Guests.RecordGuestServed();
                    Craft.ClearCraftSlots();
                    craftStation.ClearSlots();

                    if (isImportant && !string.IsNullOrEmpty(npcId))
                    {
                        var postPath = $"res://dialogue/{npcId}_day{Economy.CurrentDay}.post.dialogue";
                        if (ResourceLoader.Exists(postPath))
                        {
                            _dialoguePhase = "post";
                            tv.SetDialogueMode(true);
                            CallDeferred(nameof(StartDialogueDeferred), postPath);
                        }
                        else
                        {
                            Guests.ClearGuest();
                        }
                    }
                    else
                    {
                        Guests.ClearGuest();
                    }
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
            // 第2天在菌菇林地必定采集到沉睡花粉（保证玩家能体验下药剧情）
            var materials = (Economy.CurrentDay == 2 && locId == "mushroom_forest")
                ? new[] { "SleepPowder" }
                : loc.Materials;
            for (int i = 0; i < count; i++)
            {
                var mat = materials[rng.Next(materials.Length)];
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
        GD.Print($"[GameManager] OnPhaseChanged: {phase}, CurrentDay before={Economy.CurrentDay}");
        if (phase == DayPhase.Night)
        {
            GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/Tavern.tscn");
        }
        else
        {
            Economy.CurrentDay++;
            GD.Print($"[GameManager] CurrentDay 递增到 {Economy.CurrentDay}");
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
        if (_tavernView == null || !GodotObject.IsInstanceValid(_tavernView)) return;

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
            var dialoguePath = $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.pre.dialogue";
            _dialoguePhase = "pre";
            _tavernView.SetDialogueMode(true);
            CallDeferred(nameof(StartDialogueDeferred), dialoguePath);
        }
    }

    private void StartDialogueDeferred(string dialoguePath)
    {
        var dialogueResource = GD.Load<Resource>(dialoguePath);
        if (dialogueResource == null)
        {
            GD.PrintErr($"[GameManager] 对话文件加载失败: {dialoguePath}");
            RecoverFromDialogueFailure();
            return;
        }
        var extraStates = new Godot.Collections.Array<Variant> { Narrative.DialogueVars };
        var balloon = DialogueManager.ShowExampleDialogueBalloon(dialogueResource, "start", extraStates);
        if (balloon == null)
        {
            GD.PrintErr($"[GameManager] 显示对话气球失败: {dialoguePath}");
            RecoverFromDialogueFailure();
            return;
        }
        balloon.Set("will_block_other_input", false);
    }

    private void RecoverFromDialogueFailure()
    {
        _dialoguePhase = null;
        _isDialogueActive = false;
        if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
            _tavernView.SetDialogueMode(false);
        if (Guests.HasGuest && Guests.CurrentGuest.HasDialogue)
            Guests.ClearGuest();
    }

    private void OnGuestLeft()
    {
        if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
            _tavernView.HideCustomer();
    }

    private void OnDialogueEnded()
    {
        _isDialogueActive = false;

        if (_dialoguePhase == "pre")
        {
            _dialoguePhase = null;
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);

            var drugged = Narrative.DialogueVars.TryGetValue("ryan_drugged", out var dv) && dv.AsBool();
            if (drugged && Guests.HasGuest && Guests.CurrentGuest.NpcId == "ryan")
            {
                Guests.ClearGuest();
                _tavernView?.HideCustomer();
            }
        }
        else if (_dialoguePhase == "post")
        {
            _dialoguePhase = null;
            Guests.ClearGuest();
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.SetDialogueMode(false);
        }
    }

    private void OnPatienceLow()
    {
        if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
            _tavernView.ShowMessage("客人等得不耐烦了……", Colors.Orange);
    }

    // ── 打烊 ──
    public void EndNight()
    {
        GD.Print($"[GameManager] EndNight 调用 — Phase={DayCycle.Phase}, HasGuest={Guests.HasGuest}, CurrentDay={Economy.CurrentDay}");
        if (DayCycle.Phase != DayPhase.Night)
        {
            GD.Print("[GameManager] EndNight 失败：当前不是夜晚");
            return;
        }
        if (Guests.HasGuest)
        {
            if (_tavernView != null && GodotObject.IsInstanceValid(_tavernView))
                _tavernView.ShowMessage("还有客人在等呢！", Colors.Orange);
            GD.Print("[GameManager] EndNight 失败：还有客人");
            return;
        }

        var fates = Narrative.GetTodayNpcFates(Economy.CurrentDay);
        GD.Print($"[GameManager] 生成 LedgerData, NPC fates: {fates?.Count ?? 0}");

        CurrentLedgerData = new LedgerData
        {
            Day = Economy.CurrentDay,
            GoldToday = Economy.GoldToday,
            RepToday = Economy.RepToday,
            GoldTotal = Economy.Gold,
            RepTotal = Economy.Reputation,
            GuestsServed = Guests.GuestsServedToday,
            OrdersSuccess = Guests.OrdersSuccess,
            OrdersFailed = Guests.OrdersFailed,
            NpcFates = fates,
        };

        Economy.ResetDaily();
        Guests.ResetDaily();

        GD.Print("[GameManager] 切换到 LedgerScreen");
        GetTree().CallDeferred("change_scene_to_file", "res://scenes/ui/LedgerScreen.tscn");
    }

    // ── 商店购买 ──
    public bool BuyMaterial(string key, int quantity, bool miraActive = false)
    {
        if (quantity < 1) return false;
        var unitPrice = Shop.GetMaterialPrice(key, miraActive);
        var total = unitPrice * quantity;
        if (!Economy.SpendGold(total)) return false;
        _inv.TryGetValue(key, out var existing);
        _inv[key] = existing + quantity;
        NotifyInventoryChanged();
        return true;
    }

    public bool BuyRecipeUnlock(string key)
    {
        if (Craft.IsRecipeUnlocked(key)) return false;
        var price = Shop.GetRecipeUnlockPrice(key);
        if (price <= 0) return false;
        if (!Economy.SpendGold(price)) return false;
        Craft.UnlockRecipe(key);
        return true;
    }

    // ── UI ──
    private void RefreshTavernUI()
    {
        if (_tavernView == null || !GodotObject.IsInstanceValid(_tavernView)) return;
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
            "SleepPowder" => new(0.55f, 0.4f, 0.75f),
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
