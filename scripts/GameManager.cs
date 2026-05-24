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

    private static readonly Dictionary<string, string> MN = new()
    { ["Ale"] = "麦芽", ["Wine"] = "葡萄", ["Bread"] = "面粉", ["Meat"] = "生肉", ["Herb"] = "草药" };

    // ── 当前场景引用 ──
    private TavernView _tavernView;
    private DayMapView _dayMapView;
    private EndingScreen _endingScreen;

    public override void _Ready()
    {
<<<<<<< HEAD
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

        GD.Print("[GameManager] 初始化完成");
=======
        _rec=new(){
            ["Ale"]=("麦芽酒",new[]{"Ale"},5,false),["Wine"]=("葡萄酒",new[]{"Wine"},5,false),
            ["Bread"]=("面包",new[]{"Bread"},3,false),["Meat"]=("烤肉",new[]{"Meat"},4,false),
            ["Herb Tea"]=("草药茶",new[]{"Herb"},3,false),["Herbal Ale"]=("草药麦酒",new[]{"Ale","Herb"},10,true),
            ["Meat Stew"]=("肉汤",new[]{"Meat","Ale"},12,true),["MeatSand"]=("肉夹面包",new[]{"Bread","Meat"},9,true),
            ["SpicedWine"]=("香料红酒",new[]{"Wine","Herb"},11,true),
        }; _oKeys=_rec.Keys.ToArray();
        _dp=new Panel{Visible=false,MouseFilter=Control.MouseFilterEnum.Ignore,ZIndex=100};
        var dcl=new Label{Name="CntLbl",HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};
        dcl.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        dcl.AddThemeColorOverride("font_color",Colors.White);dcl.AddThemeFontSizeOverride("font_size",13);
        _dp.AddChild(dcl);
>>>>>>> 2cf0f025c1b3b84d7f9aa08c6123d49285c0f62b
    }

    public override void _Process(double dt)
    {
        // E键菜单
        if (Input.IsActionJustPressed("menu_toggle") && _tavernView != null)
            _tavernView.ToggleMenu();

        // 夜晚客人逻辑
        if (DayCycle.Phase == DayPhase.Night && _tavernView != null)
        {
            Guests.Update(dt, Guests.HasGuest, false);
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

<<<<<<< HEAD
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
=======
    // ── 拖拽输入 ──
    public override void _Input(InputEvent e){
        if(!_ok)return;
        if(e is InputEventMouseButton mb){
            if(mb.ButtonIndex==MouseButton.Left){
                if(mb.Pressed){
                    if(_drag){if(_src!=Df.Bar)DropAll();} // 慢速源保持点击放下
                    else PickUp(mb.Position);
                }else{
                    if(_drag&&_src==Df.Bar)DropAll(); // 快捷栏源松开放下
                }
            }else if(mb.ButtonIndex==MouseButton.Right&&mb.Pressed){
                if(_drag)ReturnOne();else OnRClick(mb.Position);
>>>>>>> 2cf0f025c1b3b84d7f9aa08c6123d49285c0f62b
            }

<<<<<<< HEAD
            // Check for scheduled NPCs today
            var npcsToday = Narrative.GetTodayScenes(Economy.CurrentDay);
            if (npcsToday.Count > 0)
            {
                Narrative.TodayImportantNpc = npcsToday[0].Id;
=======
    void PickUp(Vector2 p){
        if(HT(_cr1,p)&&!string.IsNullOrEmpty(_c1)){Start(Df.Craft,0,_c1);_c1="";UpdC();return;}
        if(HT(_cr2,p)&&!string.IsNullOrEmpty(_c2)){Start(Df.Craft,1,_c2);_c2="";UpdC();return;}
        for(int i=0;i<10;i++){
            if(HT(_br[i],p)&&!string.IsNullOrEmpty(_barMat[i])&&_barCnt[i]>0){
                _dragCnt=1;Start(Df.Bar,i,_barMat[i]);_barCnt[i]--;if(_barCnt[i]<=0)_barMat[i]="";UpdB(i);return;
>>>>>>> 2cf0f025c1b3b84d7f9aa08c6123d49285c0f62b
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
<<<<<<< HEAD
        else if (view is DayMapView dmv)
        {
            _dayMapView = dmv;
            _dayMapView.ShowDay(Economy.CurrentDay, EconomySystem.MaxDays);
            _dayMapView.GatheringConfirmed += OnGatheringConfirmed;
=======
    }

    void DropAll(){
        if(!_drag)return;
        var p=GetViewport().GetMousePosition();
        if(_src==Df.Bar){
            if(HT(_cr1,p)&&string.IsNullOrEmpty(_c1)){_c1=_dm;UpdC();Finish();return;}
            if(HT(_cr2,p)&&string.IsNullOrEmpty(_c2)){_c2=_dm;UpdC();Finish();return;}
            ReturnAll();Finish();return;
        }
        if(HT(_cr1,p)&&string.IsNullOrEmpty(_c1)){_c1=_dm;UpdC();Finish();return;}
        if(HT(_cr2,p)&&string.IsNullOrEmpty(_c2)){_c2=_dm;UpdC();Finish();return;}
        for(int i=0;i<10;i++){if(HT(_br[i],p)&&string.IsNullOrEmpty(_barMat[i])){_barMat[i]=_dm;_barCnt[i]=_dragCnt;UpdB(i);Finish();return;}}
        for(int i=0;i<10;i++){if(HT(_br[i],p)&&_barMat[i]==_dm){_barCnt[i]+=_dragCnt;UpdB(i);Finish();return;}}
        if(_mo&&_bpPanel.Visible){for(int i=0;i<5;i++){if(HT(_bp[i],p)){_inv[MatKeys[i]]+=_dragCnt;UpdBL(i);Finish();return;}}}
        ReturnAll();Finish();
    }

    void ReturnOne(){
        _dragCnt--;
        switch(_src){
            case Df.Bar:_barMat[_si]=_dm;_barCnt[_si]=1;UpdB(_si);break;
            case Df.Craft:if(_si==0)_c1=_dm;else _c2=_dm;UpdC();break;
            case Df.BP:_inv[_dm]=1;UpdBL(_si);break;
>>>>>>> 2cf0f025c1b3b84d7f9aa08c6123d49285c0f62b
        }
        else if (view is EndingScreen es)
        {
            _endingScreen = es;
            _endingScreen.ShowEndings(Economy.Gold, Economy.Reputation, Narrative.Endings);
        }
    }

<<<<<<< HEAD
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
=======
    void Start(Df s,int i,string m){_src=s;_si=i;_dm=m;_drag=true;ShowDP();}
    void Finish(){_drag=false;HideDP();_src=Df.None;_si=-1;_dm="";_dragCnt=0;UpdAll();UpdAllBL();_srv.Disabled=string.IsNullOrEmpty(_c1)||!_custA;}

    void ShowDP(){
        _dp.Visible=true;
        float w=80,h=63; // 等比缩放快捷栏 96:76
        _dp.Size=new Vector2(w,h);
        _dp.Position=GetViewport().GetMousePosition()-new Vector2(w/2,h/2);
        var sb=new StyleBoxFlat{BgColor=MC(_dm),BorderWidthLeft=2,BorderWidthTop=2,BorderWidthRight=2,BorderWidthBottom=2,
            BorderColor=Colors.White,CornerRadiusTopLeft=3,CornerRadiusTopRight=3,CornerRadiusBottomLeft=3,CornerRadiusBottomRight=3};
        _dp.AddThemeStyleboxOverride("panel",sb);
        _dp.GL("CntLbl").Text=_dragCnt>1?$"{_dragCnt}":"";
    }
    void HideDP(){_dp.Visible=false;}
    void UpdateDP(Vector2 pos){var hs=_dp.Size/2;_dp.Position=pos-new Vector2(hs.X,hs.Y);}
    void UpdDPCount(){_dp.GL("CntLbl").Text=_dragCnt>1?$"{_dragCnt}":"";}
>>>>>>> 2cf0f025c1b3b84d7f9aa08c6123d49285c0f62b

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
        _tavernView.ShowCustomer(displayName, recipe?.Name ?? guest.OrderKey,
            Craft.MaterialColor(recipe?.Materials.Length > 0 ? recipe.Materials[0] : "Ale"));

        if (guest.HasDialogue)
        {
            Narrative.TodayImportantNpc = guest.NpcId;
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
