using Godot;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

public class ItemData
{
    public string Name { get; set; }
    public float[] Color { get; set; }
    public int Price { get; set; }
}

public class CombineRule
{
    public string A { get; set; }
    public string B { get; set; }
    public string Result { get; set; }
}

public class CombineFile
{
    public CombineRule[] Combines { get; set; }
}

public class CraftSystem
{
    // ── 物品字典 ──
    public Dictionary<string, ItemData> Items { get; private set; } = new();

    // ── 加工图: item_key → { operation → result_key } ──
    private Dictionary<string, Dictionary<string, string>> _ops = new();

    // ── 组合规则: 按 (a,b) 排序存储 ──
    private Dictionary<(string, string), string> _combine = new();

    // ── 配方解锁（兼容旧 ShopSystem） ──
    public HashSet<string> UnlockedRecipes { get; private set; } = new();
    public bool IsRecipeUnlocked(string key) => UnlockedRecipes.Contains(key);
    public void UnlockRecipe(string key) => UnlockedRecipes.Add(key);

    // ── 加载 ──

    public void LoadData()
    {
        LoadItems();
        LoadOperations();
        LoadCombines();
        GD.Print($"[Craft] 加载 {Items.Count} 种物品, {_ops.Count} 个加工节点, {_combine.Count} 条组合规则");
    }

    private void LoadItems()
    {
        using var file = FileAccess.Open("res://data/items.json", FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        Items = JsonSerializer.Deserialize<Dictionary<string, ItemData>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
    }

    private void LoadOperations()
    {
        using var file = FileAccess.Open("res://data/operations.json", FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        var raw = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        _ops = raw ?? new();
    }

    private void LoadCombines()
    {
        // 组合规则以硬编码方式加载（数据量小）
        foreach (var (a, b, r) in new[] {
            ("dough", "meat_raw", "dough_meat"),
            ("ale", "herb", "ale_herb"),
            ("grape", "herb", "grape_herb"),
            ("meat_raw", "ale", "meat_stew_raw"),
        })
        {
            _combine[(a, b)] = r;
            _combine[(b, a)] = r; // 对称
        }
    }

    // ── 查询 ──

    public ItemData GetItem(string key) =>
        Items.TryGetValue(key, out var item) ? item : null;

    /// 返回某物品的所有可用操作及产物
    public Dictionary<string, string> GetOperations(string key) =>
        _ops.TryGetValue(key, out var ops) ? ops : new();

    /// 是否有可用操作（有操作 = 可继续加工）
    public bool HasOperations(string key) => _ops.ContainsKey(key);

    /// price > 0 视为可售成品
    public bool IsProduct(string key) =>
        Items.TryGetValue(key, out var item) && item.Price > 0;

    /// 检查两物品是否可组合
    public string GetCombineResult(string a, string b)
    {
        if (string.IsNullOrEmpty(a) || string.IsNullOrEmpty(b)) return null;
        return _combine.TryGetValue((a, b), out var result) ? result : null;
    }
}
