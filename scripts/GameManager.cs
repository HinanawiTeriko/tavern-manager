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
    private Dictionary<string, int> _inv = new()
    { ["Ale"] = 50, ["Wine"] = 50, ["Bread"] = 50, ["Meat"] = 50, ["Herb"] = 50 };

    private static readonly string[] MatKeys = { "Ale", "Wine", "Bread", "Meat", "Herb" };
    private static readonly Dictionary<string, string> MN = new()
    { ["Ale"] = "麦芽", ["Wine"] = "葡萄", ["Bread"] = "面粉", ["Meat"] = "生肉", ["Herb"] = "草药" };

    // ── 当前场景引用 ──
    private TavernView _tavernView;
    private DayMapView _dayMapView;
    private EndingScreen _endingScreen;

    public override void _Ready()
    {
        // 加载配方数据
        Craft.LoadRecipes();

        // 初始化 GuestSystem
        Guests = new GuestSystem(Craft.RecipeKeys);
        Guests.GuestArrived += OnGuestArrived;
        Guests.GuestLeft += OnGuestLeft;
        Guests.PatienceLow += OnPatienceLow;

        // 初始化 Economy 变化事件
        Economy.Changed += () => RefreshTavernUI();

        // 初始化 DayCycle
        DayCycle.PhaseChanged += OnPhaseChanged;

        GD.Print("[GameManager] 初始化完成");
    }

    public override void _Process(double dt)
    {
        // E键菜单
        if (Input.IsActionJustPressed("menu_toggle") && _tavernView != null)
            _tavernView.ToggleMenu();

        // 夜晚客人逻辑
        if (DayCycle.Phase == DayPhase.Night && _tavernView != null)
            Guests.Update(dt, Guests.HasGuest, false);
    }

    public void RegisterView(Node view)
    {
        if (view is TavernView tv)
        {
            _tavernView = tv;
            RefreshTavernUI();

            // 检查今日是否有重要 NPC 到访（由 NarrativeManager 外部设置）
            if (!string.IsNullOrEmpty(Narrative.TodayImportantNpc))
            {
                var npcId = Narrative.TodayImportantNpc;
                var orderKey = Guests.HasGuest ? Guests.CurrentGuest.OrderKey : "Bread";
                Guests.SpawnImportant(npcId, orderKey);
                Narrative.TodayImportantNpc = null; // 清除标记，避免重复生成
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
        DayCycle.NextPhase(); // Day → Night
    }

    private LocationData[] LoadLocationsData()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        if (file == null) return System.Array.Empty<LocationData>();
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText());
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
        if (guest.HasDialogue)
        {
            Narrative.TodayImportantNpc = guest.NpcId;
            // 触发 Dialogue Manager 对话
            try
            {
                var dm = DialogueManager.Instance;
                if (dm != null && GodotObject.IsInstanceValid(dm))
                {
                    dm.Call("show_example_dialogue_balloon",
                        $"res://dialogue/{guest.NpcId}_day{Economy.CurrentDay}.dialogue", "start");
                }
            }
            catch
            {
                /* Dialogue Manager 可能未就绪 */
            }
        }
        else
        {
            var recipe = Craft.GetRecipe(guest.OrderKey);
            _tavernView.ShowCustomer(guest.Name, recipe?.Name ?? guest.OrderKey,
                Craft.MaterialColor(recipe?.Materials[0] ?? "Ale"));
        }
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

    // ── 合成与上菜 ──
    public void TryCraft()
    {
        if (Craft.TryMatch(Craft.Slot1, Craft.Slot2, out var key))
        {
            Craft.CraftedKey = key;
            _tavernView?.ShowMessage($"制作完成：{Craft.Recipes[key].Name}！", Colors.GreenYellow);
        }
        else
        {
            Craft.CraftedKey = null;
            _tavernView?.ShowMessage("没有匹配的配方！", Colors.OrangeRed);
        }
    }

    public void ServeToGuest()
    {
        if (!Guests.HasGuest || string.IsNullOrEmpty(Craft.CraftedKey)) return;

        if (Craft.CraftedKey == Guests.CurrentGuest.OrderKey)
        {
            Economy.AddGold(Craft.Recipes[Craft.CraftedKey].Price);
            Economy.AddReputation(2);
            _tavernView?.ShowMessage($"完美！{Guests.CurrentGuest.Name} 很满意！", Colors.LimeGreen);
        }
        else
        {
            _tavernView?.ShowMessage($"错了！{Guests.CurrentGuest.Name} 很失望……", Colors.Red);
        }
        Craft.ClearCraftSlots();
        Guests.ClearGuest();
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
