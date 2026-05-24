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

        _goButton.Pressed += OnGoPressed;
        _continueBtn.Pressed += OnContinue;

        LoadLocations();
        BuildLocationUI();
    }

    private void LoadLocations()
    {
        using var file = FileAccess.Open("res://data/locations.json", FileAccess.ModeFlags.Read);
        var data = JsonSerializer.Deserialize<LocationsFile>(file.GetAsText(), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
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
            nameLabel.AddThemeColorOverride("font_color", Colors.White);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            info.AddChild(nameLabel);
            var descLabel = new Label { Text = loc.Description };
            descLabel.AddThemeColorOverride("font_color", new Color(0.6f, 0.6f, 0.6f));
            descLabel.AddThemeFontSizeOverride("font_size", 13);
            info.AddChild(descLabel);
            row.AddChild(info);

            var countLabel = new Label
            {
                Text = "0",
                CustomMinimumSize = new Vector2(40, 0),
                HorizontalAlignment = HorizontalAlignment.Center
            };
            countLabel.AddThemeColorOverride("font_color", Colors.White);
            countLabel.AddThemeFontSizeOverride("font_size", 22);
            row.AddChild(countLabel);

            var addBtn = new Button { Text = "+", CustomMinimumSize = new Vector2(40, 36) };
            string locId = loc.Id;
            addBtn.Pressed += () => AddAssignment(locId, loc.Cost, countLabel);
            row.AddChild(addBtn);

            var subBtn = new Button { Text = "-", CustomMinimumSize = new Vector2(40, 36), Disabled = true };
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
        // Re-enable add buttons
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
}
