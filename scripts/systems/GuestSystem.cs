using Godot;
using System;
using System.Collections.Generic;

public enum GuestType { Normal, Important }

public class GuestData
{
    public string Name;
    public GuestType Type;
    public string OrderKey;
    public string NpcId;
    public double Patience;
    public bool HasDialogue;

    public const double BasePatience = 60.0;
}

public class GuestSystem
{
    public GuestData CurrentGuest { get; private set; }
    public bool HasGuest => CurrentGuest != null;

    private readonly string[] _normalNames = {
        "铁锤格鲁姆","冰霜莱拉","暗影德恩","圣光凯尔","疾风维克斯",
        "暗夜尼克斯","山丘伯林","银弦艾莉亚","怒血索恩","黎明扎拉",
        "磐石芬恩","毒刃鲁克"
    };

    private readonly string[] _normalOrders;
    private readonly Random _rng = new();
    private double _spawnTimer;
    private double _nextSpawn = 2.0;

    public event Action<GuestData> GuestArrived;
    public event Action GuestLeft;
    public event Action PatienceLow;

    public GuestSystem(string[] recipeKeys)
    {
        _normalOrders = recipeKeys;
    }

    public void Update(double dt, bool hasGuest, bool menuOpen)
    {
        if (!hasGuest && !menuOpen)
        {
            _spawnTimer += dt;
            if (_spawnTimer >= _nextSpawn)
            {
                _spawnTimer = 0;
                _nextSpawn = _rng.NextDouble() * 3 + 2;
                SpawnNormal();
            }
        }

        if (hasGuest && !menuOpen)
        {
            CurrentGuest.Patience -= dt;
            if (CurrentGuest.Patience <= 15 && CurrentGuest.Patience + dt > 15)
                PatienceLow?.Invoke();
            if (CurrentGuest.Patience <= 0)
                ClearGuest();
        }
    }

    private void SpawnNormal()
    {
        CurrentGuest = new GuestData
        {
            Name = _normalNames[_rng.Next(_normalNames.Length)],
            Type = GuestType.Normal,
            OrderKey = _normalOrders[_rng.Next(_normalOrders.Length)],
            Patience = GuestData.BasePatience,
            HasDialogue = false
        };
        GuestArrived?.Invoke(CurrentGuest);
    }

    public void SpawnImportant(string npcId, string orderKey)
    {
        CurrentGuest = new GuestData
        {
            Name = npcId,
            Type = GuestType.Important,
            OrderKey = orderKey,
            NpcId = npcId,
            Patience = GuestData.BasePatience * 1.5,
            HasDialogue = true
        };
        GuestArrived?.Invoke(CurrentGuest);
    }

    public void ClearGuest()
    {
        GuestLeft?.Invoke();
        CurrentGuest = null;
        _spawnTimer = 0;
        _nextSpawn = _rng.NextDouble() * 2 + 2;
    }

    // ── 每日追踪 ──
    public int GuestsServedToday { get; private set; }
    public int OrdersSuccess { get; private set; }
    public int OrdersFailed { get; private set; }

    public void RecordGuestServed() => GuestsServedToday++;
    public void RecordOrderSuccess() => OrdersSuccess++;
    public void RecordOrderFailed() => OrdersFailed++;

    public void ResetDaily()
    {
        GuestsServedToday = 0;
        OrdersSuccess = 0;
        OrdersFailed = 0;
    }
}
