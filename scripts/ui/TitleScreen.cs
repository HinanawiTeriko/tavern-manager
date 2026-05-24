using Godot;

public partial class TitleScreen : Node2D
{
    public override void _Ready()
    {
        GetNode<Button>("UI/StartButton").Pressed += OnStart;
    }

    private void OnStart()
    {
        GetTree().ChangeSceneToFile("res://scenes/ui/DayMap.tscn");
    }
}
