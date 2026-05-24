using Godot;
using System.Collections.Generic;

public partial class EndingScreen : Node2D
{
    private VBoxContainer _npcEndingsList;
    private Label _goldLabel;
    private Label _repLabel;
    private Label _titleLabel;

    public override void _Ready()
    {
        _npcEndingsList = GetNode<VBoxContainer>("Content/NPCEndingsList");
        _goldLabel = GetNode<Label>("Content/Stats/GoldLabel");
        _repLabel = GetNode<Label>("Content/Stats/RepLabel");
        _titleLabel = GetNode<Label>("Content/TitleLabel");

        GetNode<Button>("Content/QuitBtn").Pressed += () => GetTree().Quit();
        GetNode<Button>("Content/RestartBtn").Pressed += () =>
            GetTree().ChangeSceneToFile("res://scenes/ui/TitleScreen.tscn");
    }

    public void ShowEndings(int gold, int rep, Dictionary<string, string> npcEndings)
    {
        _goldLabel.Text = $"最终金币：{gold}";
        _repLabel.Text = $"最终声望：{rep}";

        foreach (var (npcId, ending) in npcEndings)
        {
            var row = new HBoxContainer();
            row.AddThemeConstantOverride("separation", 10);
            row.CustomMinimumSize = new Vector2(0, 40);
            var nameLabel = new Label
            {
                Text = npcId,
                CustomMinimumSize = new Vector2(120, 0)
            };
            nameLabel.AddThemeColorOverride("font_color", Colors.White);
            nameLabel.AddThemeFontSizeOverride("font_size", 18);
            row.AddChild(nameLabel);
            var endingLabel = new Label { Text = ending };
            endingLabel.AddThemeColorOverride("font_color", Colors.LightGray);
            endingLabel.AddThemeFontSizeOverride("font_size", 15);
            row.AddChild(endingLabel);
            _npcEndingsList.AddChild(row);
        }
    }
}
