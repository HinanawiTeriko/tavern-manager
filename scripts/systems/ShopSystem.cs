using Godot;
using System.Collections.Generic;
using System.Text.Json;

public class ShopMaterialEntry
{
    public string Key { get; set; }
    public int Price { get; set; }
}

public class ShopRecipeEntry
{
    public string Key { get; set; }
    public int Price { get; set; }
}

public class ShopConfig
{
    public ShopMaterialEntry[] Materials { get; set; }
    public ShopRecipeEntry[] RecipeUnlocks { get; set; }
    public double MiraDiscount { get; set; } = 0.8;
}

public class ShopSystem
{
    private Dictionary<string, int> _materialPrices = new();
    private Dictionary<string, int> _recipeUnlockPrices = new();
    private double _miraDiscount = 0.8;

    public void LoadConfig()
    {
        try
        {
            using var file = FileAccess.Open("res://data/shop.json", FileAccess.ModeFlags.Read);
            if (file == null)
            {
                GD.PrintErr("[Shop] shop.json 未找到");
                return;
            }
            var json = file.GetAsText();
            var data = JsonSerializer.Deserialize<ShopConfig>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            _materialPrices.Clear();
            if (data.Materials != null)
                foreach (var m in data.Materials)
                    _materialPrices[m.Key] = m.Price;

            _recipeUnlockPrices.Clear();
            if (data.RecipeUnlocks != null)
                foreach (var r in data.RecipeUnlocks)
                    _recipeUnlockPrices[r.Key] = r.Price;

            _miraDiscount = data.MiraDiscount;
            GD.Print($"[Shop] 加载 {_materialPrices.Count} 种材料, {_recipeUnlockPrices.Count} 种可解锁配方");
        }
        catch (System.Exception e)
        {
            GD.PrintErr($"[Shop] 加载配置失败: {e.Message}");
        }
    }

    public int GetMaterialPrice(string key, bool miraActive = false)
    {
        if (!_materialPrices.TryGetValue(key, out var price)) return 999;
        if (miraActive) return Mathf.FloorToInt(price * _miraDiscount);
        return price;
    }

    public int GetRecipeUnlockPrice(string key)
    {
        _recipeUnlockPrices.TryGetValue(key, out var price);
        return price; // 0 if not found
    }

    public bool IsMiraShopToday(int currentDay, NarrativeManager narrative)
    {
        var scenes = narrative.GetTodayScenes(currentDay);
        foreach (var npc in scenes)
        {
            if (npc.Id == "mira") return true;
        }
        return false;
    }
}
