using Godot;

// ============================================================
// 地下城酒馆 - 开始界面脚本
// ============================================================
public partial class TitleScreen : Node2D
{
    public override void _Ready()
    {
        GetNode<Button>("UI/StartButton").Pressed += OnStart;
    }

    private void OnStart()
    {
        // 切换到游戏主场景
        GetTree().ChangeSceneToFile("res://scenes/main/Main.tscn");
    }
}
