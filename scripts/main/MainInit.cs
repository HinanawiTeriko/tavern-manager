using Godot;

// Main 场景初始化桥接脚本
public partial class MainInit : Node2D
{
    public override void _Ready()
    {
        var gm = GetNode<GameManager>("/root/GameManager");
        gm.StartGame(this);
    }
}
