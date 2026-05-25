using Godot;
using System.Collections.Generic;
using System.Text.Json;

public class SeasoningData
{
    public string Name { get; set; }
    public string Tag { get; set; }
    public float[] Color { get; set; }
}

public class SeasoningSystem
{
    public Dictionary<string, SeasoningData> Seasonings { get; private set; } = new();

    public void Load()
    {
        using var file = FileAccess.Open("res://data/seasonings.json", FileAccess.ModeFlags.Read);
        if (file == null) return;
        var json = file.GetAsText();
        Seasonings = JsonSerializer.Deserialize<Dictionary<string, SeasoningData>>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? new();
        GD.Print($"[Seasoning] 加载 {Seasonings.Count} 种香料");
    }

    public SeasoningData GetSeasoning(string key) =>
        Seasonings.TryGetValue(key, out var s) ? s : null;
}
