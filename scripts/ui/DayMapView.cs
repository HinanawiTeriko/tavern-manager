using Godot;
using System.Collections.Generic;
using System.Text.Json;

public class LocationData
{
    public string Id { get; set; }
    public string Name { get; set; }
    public int Cost { get; set; }
    public string[] Materials { get; set; }
    public string Description { get; set; }
}

public class LocationsFile
{
    public int MaxStamina { get; set; }
    public LocationData[] Locations { get; set; }
}

public partial class DayMapView : Node2D
{
    private VBoxContainer _locationList;
    private Label _staminaLabel;
    private Label _dayLabel;
    private Button _goButton;
    private Panel _resultPanel;
    private Label _resultLabel;
    private Button _continueBtn;

    private Dictionary<string, int> _assignments = new();
    private int _staminaLeft;
    private int _maxStamina;
    private LocationData[] _locations;

    private Dictionary<string, Label> _assignLabels = new();
    private Dictionary<string, Button> _locAddBtns = new();
    private Dictionary<string, Button> _locSubBtns = new();

    // ── 商店 ──
    private bool _isShopTab;
    private Button _gatherTabBtn;
    private Button _shopTabBtn;
    private Control _shopPanel;
    private Label _shopTitle;
    private Label _goldLabel;
    private VBoxContainer _materialList;
    private VBoxContainer _recipeList;
    private bool _isMiraShop;

    public event System.Action<Dictionary<string, int>> GatheringConfirmed;

    public override void _Ready()
    {
        _locationList = GetNode<VBoxContainer>("MapArea/LocationList");
        _staminaLabel = GetNode<Label>("TopBar/StaminaLabel");
        _dayLabel = GetNode<Label>("TopBar/DayLabel");
        _goButton = GetNode<Button>("GoButton");
        _resultPanel = GetNode<Panel>("ResultPanel");
        _resultLabel = GetNode<Label>("ResultPanel/ResultLabel");
        _continueBtn = GetNode<Button>("ResultPanel/ContinueBtn");

        // Theme: static labels
        var titleLabel = GetNode<Label>("MapArea/TitleLabel");
        ThemeColors.StyleHeader(titleLabel, 26);

        ThemeColors.StyleHeader(_dayLabel, 22);

        _staminaLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
        _staminaLabel.AddThemeFontSizeOverride("font_size", 20);

        // Theme: buttons
        ThemeColors.StyleButton(_goButton, 24);
        ThemeColors.StyleButton(_continueBtn, 16);

        // Theme: result panel
        _resultPanel.AddThemeStyleboxOverride("panel", ThemeColors.ParchmentPanel());
        _resultLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
        _resultLabel.AddThemeFontSizeOverride("font_size", 18);

        _goButton.Pressed += OnGoPressed;
        _continueBtn.Pressed += OnContinue;

        LoadLocations();
        BuildLocationUI();

        // Gold label
        _goldLabel = GetNode<Label>("TopBar/GoldLabel");
        _goldLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
        _goldLabel.AddThemeFontSizeOverride("font_size", 20);

        // Tab buttons + shop UI
        BuildTabButtons();
        BuildShopUI();

        // Background: try daymap_bg texture, fallback to deep color
        var bgNode = GetNodeOrNull<Sprite2D>("Background");
        if (bgNode != null)
        {
            var bgTex = TextureManager.TryLoad("res://assets/textures/backgrounds/daymap_bg.png");
            if (bgTex != null)
            {
                bgNode.Texture = bgTex;
            }
            else
            {
                var placeholderGradient = new GradientTexture2D
                {
                    Width = 1280, Height = 720,
                    Gradient = new Gradient { Colors = new[] { ThemeColors.BackgroundDeep, ThemeColors.SurfaceMid }, Offsets = new[] { 0f, 1f } }
                };
                bgNode.Texture = placeholderGradient;
            }
        }
    }

    private void LoadLocations()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText(),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        _locations = data.Locations;
        _maxStamina = data.MaxStamina;
        _staminaLeft = _maxStamina;
    }

    public void ShowDay(int day, int totalDays)
    {
        _dayLabel.Text = $"第 {day}/{totalDays} 天 — 白天·采集";
        _staminaLeft = _maxStamina;
        _assignments.Clear();
        foreach (var kv in _assignLabels)
            kv.Value.Text = "0";
        UpdateStaminaDisplay();
        _resultPanel.Visible = false;
        _continueBtn.Visible = true;
        foreach (var btn in _locAddBtns.Values)
            btn.Disabled = false;
        foreach (var btn in _locSubBtns.Values)
            btn.Disabled = true;
        _goButton.Disabled = false;
        _goButton.Visible = true;
        _isShopTab = false;
        if (_gatherTabBtn != null) UpdateTabAppearance();
        if (_shopPanel != null) _shopPanel.Visible = false;
        // Reset gather panel visibility
        var mapArea = GetNode<Control>("MapArea");
        mapArea.GetNode<Label>("TitleLabel").Visible = true;
        mapArea.GetNode<VBoxContainer>("LocationList").Visible = true;
        UpdateGoldDisplay();
    }

    private void BuildLocationUI()
    {
        foreach (var loc in _locations)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.CustomMinimumSize = new Vector2(0, 52);

            var info = new VBoxContainer();
            info.CustomMinimumSize = new Vector2(360, 0);

            var nameLabel = new Label { Text = $"{loc.Name}  [{loc.Cost}体力]" };
            nameLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            info.AddChild(nameLabel);

            var descLabel = new Label { Text = loc.Description };
            descLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
            descLabel.AddThemeFontSizeOverride("font_size", 13);
            info.AddChild(descLabel);

            row.AddChild(info);

            var countLabel = new Label
            {
                Text = "0",
                CustomMinimumSize = new Vector2(40, 0),
                HorizontalAlignment = HorizontalAlignment.Center
            };
            countLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
            countLabel.AddThemeFontSizeOverride("font_size", 22);
            row.AddChild(countLabel);

            var addBtn = new Button { Text = "+", CustomMinimumSize = new Vector2(40, 36) };
            ThemeColors.StyleButton(addBtn, 16);
            string locId = loc.Id;
            addBtn.Pressed += () => AddAssignment(locId, loc.Cost, countLabel);
            row.AddChild(addBtn);

            var subBtn = new Button { Text = "-", CustomMinimumSize = new Vector2(40, 36), Disabled = true };
            ThemeColors.StyleButton(subBtn, 16);
            subBtn.Pressed += () => RemoveAssignment(locId, loc.Cost, countLabel);
            row.AddChild(subBtn);

            _assignLabels[loc.Id] = countLabel;
            _locAddBtns[loc.Id] = addBtn;
            _locSubBtns[loc.Id] = subBtn;

            _locationList.AddChild(row);
        }
    }

    private void AddAssignment(string locId, int cost, Label countLabel)
    {
        if (_staminaLeft < cost) return;
        _staminaLeft -= cost;
        _assignments.TryGetValue(locId, out var cur);
        _assignments[locId] = cur + 1;
        countLabel.Text = _assignments[locId].ToString();
        UpdateStaminaDisplay();
        if (_locSubBtns.TryGetValue(locId, out var subBtn))
            subBtn.Disabled = false;
        if (_staminaLeft < 1)
            foreach (var btn in _locAddBtns.Values) btn.Disabled = true;
    }

    private void RemoveAssignment(string locId, int cost, Label countLabel)
    {
        if (!_assignments.TryGetValue(locId, out var cur) || cur < 1) return;
        _staminaLeft += cost;
        _assignments[locId] = cur - 1;
        if (_assignments[locId] <= 0) _assignments.Remove(locId);
        countLabel.Text = _assignments.TryGetValue(locId, out var remaining) ? remaining.ToString() : "0";
        UpdateStaminaDisplay();
        foreach (var btn in _locAddBtns.Values) btn.Disabled = false;
        if (_locSubBtns.TryGetValue(locId, out var subBtn))
            subBtn.Disabled = !_assignments.ContainsKey(locId);
    }

    private void UpdateStaminaDisplay()
    {
        _staminaLabel.Text = $"体力：{_staminaLeft}/{_maxStamina}";
    }

    private void OnGoPressed()
    {
        if (_assignments.Count == 0)
        {
            _resultLabel.Text = "请至少分配一点体力到采集点！";
            _resultPanel.Visible = true;
            _continueBtn.Visible = false;
            return;
        }
        _goButton.Disabled = true;

        var rng = new System.Random();
        var results = new List<string>();
        foreach (var (locId, count) in _assignments)
        {
            var loc = System.Array.Find(_locations, l => l.Id == locId);
            if (loc == null) continue;
            for (int i = 0; i < count; i++)
            {
                var mat = loc.Materials[rng.Next(loc.Materials.Length)];
                results.Add($"[{loc.Name}] 获得 {mat} x1");
            }
        }

        _resultLabel.Text = "采集结果：\n" + string.Join("\n", results);
        _resultPanel.Visible = true;
        _continueBtn.Visible = true;
    }

    private void OnContinue()
    {
        _resultPanel.Visible = false;
        GatheringConfirmed?.Invoke(_assignments);
    }

    public void UpdateGoldDisplay()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        if (gm != null)
            _goldLabel.Text = $"金币：{gm.Economy.Gold}";
    }

    private void BuildTabButtons()
    {
        var mapArea = GetNode<Control>("MapArea");
        var tabRow = new HBoxContainer();
        tabRow.AddThemeConstantOverride("separation", 8);
        tabRow.CustomMinimumSize = new Vector2(0, 40);

        _gatherTabBtn = new Button { Text = "采集", CustomMinimumSize = new Vector2(100, 36) };
        ThemeColors.StyleButton(_gatherTabBtn, 16);
        _gatherTabBtn.Pressed += () => SwitchTab(false);
        tabRow.AddChild(_gatherTabBtn);

        _shopTabBtn = new Button { Text = "商店", CustomMinimumSize = new Vector2(100, 36) };
        ThemeColors.StyleButton(_shopTabBtn, 16);
        _shopTabBtn.Pressed += () => SwitchTab(true);
        tabRow.AddChild(_shopTabBtn);

        mapArea.AddChild(tabRow);
        mapArea.MoveChild(tabRow, 0);

        // 把原有节点往下移，给 tab 栏腾空间
        var titleLabel = mapArea.GetNode<Label>("TitleLabel");
        titleLabel.OffsetTop = 45;
        titleLabel.OffsetBottom = 80;
        var locationList = mapArea.GetNode<VBoxContainer>("LocationList");
        locationList.OffsetTop = 95;
        locationList.OffsetBottom = 420;

        UpdateTabAppearance();
    }

    private void SwitchTab(bool shop)
    {
        _isShopTab = shop;
        UpdateTabAppearance();

        var mapArea = GetNode<Control>("MapArea");
        var titleLabel = mapArea.GetNode<Label>("TitleLabel");
        var locationList = mapArea.GetNode<VBoxContainer>("LocationList");

        titleLabel.Visible = !shop;
        locationList.Visible = !shop;
        _shopPanel.Visible = shop;

        if (shop)
            RefreshShopUI();

        _goButton.Visible = !shop;
    }

    private void UpdateTabAppearance()
    {
        if (_gatherTabBtn == null || _shopTabBtn == null) return;
        _gatherTabBtn.Modulate = _isShopTab ? Colors.DimGray : Colors.White;
        _shopTabBtn.Modulate = _isShopTab ? Colors.White : Colors.DimGray;
    }

    private void BuildShopUI()
    {
        _shopPanel = new ScrollContainer();
        _shopPanel.AnchorLeft = 0;
        _shopPanel.AnchorRight = 1;
        _shopPanel.OffsetLeft = 0;
        _shopPanel.OffsetTop = 95;
        _shopPanel.OffsetRight = 1000;
        _shopPanel.OffsetBottom = 420;
        _shopPanel.Visible = false;
        GetNode<Control>("MapArea").AddChild(_shopPanel);

        var shopContent = new VBoxContainer();
        shopContent.AddThemeConstantOverride("separation", 8);
        _shopPanel.AddChild(shopContent);

        _shopTitle = new Label();
        _shopTitle.CustomMinimumSize = new Vector2(0, 36);
        ThemeColors.StyleHeader(_shopTitle, 22);
        shopContent.AddChild(_shopTitle);

        var matTitle = new Label { Text = "—— 购买材料 ——" };
        matTitle.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        matTitle.AddThemeFontSizeOverride("font_size", 16);
        matTitle.CustomMinimumSize = new Vector2(0, 30);
        shopContent.AddChild(matTitle);

        _materialList = new VBoxContainer();
        _materialList.AddThemeConstantOverride("separation", 4);
        shopContent.AddChild(_materialList);

        var recipeTitle = new Label { Text = "—— 解锁配方 ——" };
        recipeTitle.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        recipeTitle.AddThemeFontSizeOverride("font_size", 16);
        recipeTitle.CustomMinimumSize = new Vector2(0, 30);
        shopContent.AddChild(recipeTitle);

        _recipeList = new VBoxContainer();
        _recipeList.AddThemeConstantOverride("separation", 4);
        shopContent.AddChild(_recipeList);
    }

    private void RefreshShopUI()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        if (gm == null) return;

        _isMiraShop = gm.Shop.IsMiraShopToday(gm.Economy.CurrentDay, gm.Narrative);
        _shopTitle.Text = _isMiraShop ? "米拉的旅行商店" : "商店";

        BuildMaterialRows(gm);
        BuildRecipeRows(gm);
        UpdateGoldDisplay();
    }

    private void BuildMaterialRows(GameManager gm)
    {
        foreach (var child in _materialList.GetChildren())
            child.QueueFree();

        var materials = new[] { ("Ale", "麦芽"), ("Wine", "葡萄"), ("Bread", "面粉"), ("Meat", "生肉"), ("Herb", "草药") };

        foreach (var (key, name) in materials)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            row.CustomMinimumSize = new Vector2(0, 40);

            var nameLabel = new Label { Text = name, CustomMinimumSize = new Vector2(70, 0) };
            nameLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            nameLabel.AddThemeFontSizeOverride("font_size", 16);
            row.AddChild(nameLabel);

            int price = gm.Shop.GetMaterialPrice(key, _isMiraShop);
            var priceLabel = new Label
            {
                Text = _isMiraShop ? $"{gm.Shop.GetMaterialPrice(key)}→{price}金" : $"{price}金",
                CustomMinimumSize = new Vector2(70, 0)
            };
            priceLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
            priceLabel.AddThemeFontSizeOverride("font_size", 14);
            row.AddChild(priceLabel);

            var subBtn = new Button { Text = "-", CustomMinimumSize = new Vector2(36, 30) };
            ThemeColors.StyleButton(subBtn, 14);
            string matKey = key;
            var qtyLabel = new Label { Text = "0", CustomMinimumSize = new Vector2(30, 0), HorizontalAlignment = HorizontalAlignment.Center };
            qtyLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
            qtyLabel.AddThemeFontSizeOverride("font_size", 18);
            var addBtn = new Button { Text = "+", CustomMinimumSize = new Vector2(36, 30) };
            ThemeColors.StyleButton(addBtn, 14);

            subBtn.Pressed += () => {
                var cur = int.Parse(qtyLabel.Text);
                if (cur > 0) { cur--; qtyLabel.Text = cur.ToString(); }
            };
            addBtn.Pressed += () => {
                var cur = int.Parse(qtyLabel.Text);
                cur++; qtyLabel.Text = cur.ToString();
            };

            var buyBtn = new Button { Text = "购买", CustomMinimumSize = new Vector2(56, 30) };
            ThemeColors.StyleButton(buyBtn, 14);
            buyBtn.Pressed += () => {
                var qty = int.Parse(qtyLabel.Text);
                if (qty < 1) return;
                if (gm.BuyMaterial(matKey, qty, _isMiraShop))
                {
                    qtyLabel.Text = "0";
                    UpdateGoldDisplay();
                }
            };

            row.AddChild(subBtn);
            row.AddChild(qtyLabel);
            row.AddChild(addBtn);
            row.AddChild(buyBtn);
            _materialList.AddChild(row);
        }
    }

    private void BuildRecipeRows(GameManager gm)
    {
        foreach (var child in _recipeList.GetChildren())
            child.QueueFree();

        var unlocks = new[] {
            ("Herbal Ale", "草药麦酒"), ("SpicedWine", "香料红酒"),
            ("MeatSand", "肉夹面包"), ("Meat Stew", "肉汤")
        };

        foreach (var (key, name) in unlocks)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 8);
            row.CustomMinimumSize = new Vector2(0, 40);

            var nameLabel = new Label { Text = name, CustomMinimumSize = new Vector2(100, 0) };
            nameLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
            nameLabel.AddThemeFontSizeOverride("font_size", 16);
            row.AddChild(nameLabel);

            if (gm.Craft.IsRecipeUnlocked(key))
            {
                var owned = new Label { Text = "已拥有", CustomMinimumSize = new Vector2(80, 0) };
                owned.AddThemeColorOverride("font_color", ThemeColors.TextDim);
                owned.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(owned);
            }
            else
            {
                int price = gm.Shop.GetRecipeUnlockPrice(key);
                if (price < 0) { _recipeList.AddChild(row); return; }
                var priceLabel = new Label { Text = $"{price}金", CustomMinimumSize = new Vector2(60, 0) };
                priceLabel.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
                priceLabel.AddThemeFontSizeOverride("font_size", 14);
                row.AddChild(priceLabel);

                var unlockBtn = new Button { Text = "解锁", CustomMinimumSize = new Vector2(56, 30) };
                ThemeColors.StyleButton(unlockBtn, 14);
                string rKey = key;
                unlockBtn.Pressed += () => {
                    if (gm.BuyRecipeUnlock(rKey))
                    {
                        UpdateGoldDisplay();
                        BuildRecipeRows(gm);
                    }
                };
                row.AddChild(unlockBtn);
            }

            _recipeList.AddChild(row);
        }
    }
}
