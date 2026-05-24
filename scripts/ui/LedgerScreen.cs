using Godot;

public partial class LedgerScreen : Node2D
{
    private Label _titleLabel;
    private VBoxContainer _statsList;
    private Label _fateTitle;
    private VBoxContainer _fateList;
    private Button _continueBtn;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("UI/TitleLabel");
        _statsList = GetNode<VBoxContainer>("UI/StatsList");
        _fateTitle = GetNode<Label>("UI/FateTitle");
        _fateList = GetNode<VBoxContainer>("UI/FateList");
        _continueBtn = GetNode<Button>("UI/ContinueBtn");

        _continueBtn.Pressed += OnContinue;

        var gm = GetNode<GameManager>("/root/GameManager");
        var data = gm.CurrentLedgerData;
        if (data != null)
            Render(data);
    }

    private void Render(LedgerData data)
    {
        _titleLabel.Text = $"第 {data.Day} 天 · 营业结算";
        ThemeColors.StyleHeader(_titleLabel, 30);

        AddStatRow($"金币收入    +{data.GoldToday} 金      累计: {data.GoldTotal} 金");
        AddStatRow($"声望变化    +{data.RepToday}           累计: {data.RepTotal}");
        AddStatRow($"服务客人    {data.GuestsServed} 位");
        AddStatRow($"成功订单    {data.OrdersSuccess} 单");
        AddStatRow($"失败订单    {data.OrdersFailed} 单");

        if (data.NpcFates != null && data.NpcFates.Count > 0)
        {
            _fateTitle.Text = "今日宿命";
            ThemeColors.StyleHeader(_fateTitle, 22);

            foreach (var (name, title, fateText) in data.NpcFates)
            {
                var card = new VBoxContainer();
                card.AddThemeConstantOverride("separation", 4);

                var nameLabel = new Label { Text = $"{name} · {title}" };
                nameLabel.AddThemeColorOverride("font_color", ThemeColors.AmberPrimary);
                nameLabel.AddThemeFontSizeOverride("font_size", 20);
                card.AddChild(nameLabel);

                var fateLabel = new Label { Text = fateText };
                fateLabel.AddThemeColorOverride("font_color", ThemeColors.TextLight);
                fateLabel.AddThemeFontSizeOverride("font_size", 15);
                card.AddChild(fateLabel);

                _fateList.AddChild(card);
            }
        }
        else
        {
            _fateTitle.Visible = false;
        }

        ThemeColors.StyleButton(_continueBtn, 20);
    }

    private void AddStatRow(string text)
    {
        var label = new Label { Text = text };
        label.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
        label.AddThemeFontSizeOverride("font_size", 16);
        _statsList.AddChild(label);
    }

    private void OnContinue()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        gm.DayCycle.NextPhase();
    }
}
