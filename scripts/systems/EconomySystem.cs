using Godot;
using System;

public class EconomySystem
{
    public int Gold { get; private set; } = 0;
    public int Reputation { get; private set; } = 0;
    public int TavernLevel { get; private set; } = 1;
    public int CurrentDay { get; set; } = 1;
    public const int MaxDays = 30;

    private readonly int[] _levelRepThresholds = { 0, 50, 150 };

    public int LevelRepThreshold =>
        TavernLevel < _levelRepThresholds.Length ? _levelRepThresholds[TavernLevel] : int.MaxValue;

    public void AddGold(int amount)
    {
        Gold += amount;
        GoldToday += amount;
        EmitChanged();
    }

    public bool SpendGold(int amount)
    {
        if (Gold < amount) return false;
        Gold -= amount;
        EmitChanged();
        return true;
    }

    public void AddReputation(int amount)
    {
        Reputation += amount;
        RepToday += amount;
        CheckLevelUp();
        EmitChanged();
    }

    // ── 每日追踪 ──
    public int GoldToday { get; private set; }
    public int RepToday { get; private set; }

    public void ResetDaily()
    {
        GoldToday = 0;
        RepToday = 0;
    }

    private void CheckLevelUp()
    {
        if (TavernLevel < 3 && Reputation >= _levelRepThresholds[TavernLevel])
        {
            TavernLevel++;
            GD.Print($"[Economy] 酒馆升级到 Lv.{TavernLevel}");
        }
    }

    public bool IsLastDay() => CurrentDay >= MaxDays;

    public event Action Changed;

    private void EmitChanged() => Changed?.Invoke();
}
