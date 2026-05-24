using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using DialogueManagerRuntime;

// ── NPC 数据模型 ──

public class NpcSceneData
{
    public int Day { get; set; }
    public string Dialogue { get; set; }
    public string Order { get; set; }
    public string Trigger { get; set; }
    public string[] Variables { get; set; }
}

public class NpcData
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public int AffectionStart { get; set; }
    public NpcSceneData[] Scenes { get; set; }
    public Dictionary<string, string> Endings { get; set; }
}

public class NpcFile
{
    public NpcData[] Npcs { get; set; }
}

public class NarrativeManager
{
    // ── NPC 数据 ──
    public List<NpcData> AllNpcs { get; private set; } = new();
    // 叙事变量池（供 .dialogue 文件读取）
    private Dictionary<string, object> _vars = new();

    // 关键道具
    public HashSet<string> KeyItems { get; } = new();

    // NPC 好感度 (npc_id → value)
    public Dictionary<string, int> Affection { get; } = new();

    // NPC 结局标记 (npc_id → ending_key)
    public Dictionary<string, string> Endings { get; } = new();

    // 今日应到访的重要 NPC
    public string TodayImportantNpc { get; set; }

    // 今日是否已在白天触发过 NPC 偶遇
    public bool DayEncounterTriggered { get; set; }

    public void SetVar(string key, object value)
    {
        _vars[key] = value;
        var instance = DialogueManager.Instance;
        if (instance != null && GodotObject.IsInstanceValid(instance))
            instance.Call("set_variable", key, Variant.From(value));
    }

    public object GetVar(string key) =>
        _vars.TryGetValue(key, out var v) ? v : null;

    public bool HasKeyItem(string itemId) => KeyItems.Contains(itemId);

    public void AddKeyItem(string itemId)
    {
        KeyItems.Add(itemId);
        SetVar($"has_{itemId}", true);
    }

    public void SetAffection(string npcId, int value)
    {
        Affection[npcId] = value;
        SetVar($"aff_{npcId}", value);
    }

    public int GetAffection(string npcId) =>
        Affection.TryGetValue(npcId, out var v) ? v : 0;

    public void SetEnding(string npcId, string ending)
    {
        Endings[npcId] = ending;
        GD.Print($"[Narrative] {npcId} 结局 → {ending}");
    }

    // ── NPC 数据加载 ──

    public void LoadNpcData()
    {
        try
        {
            using var file = FileAccess.Open("res://data/npcs.json", FileAccess.ModeFlags.Read);
            if (file == null) return;
            var json = file.GetAsText();
            var data = JsonSerializer.Deserialize<NpcFile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (data?.Npcs != null)
            {
                AllNpcs = new List<NpcData>(data.Npcs);
                foreach (var npc in AllNpcs)
                    SetAffection(npc.Id, npc.AffectionStart);
                GD.Print($"[Narrative] 加载 {AllNpcs.Count} 个 NPC");
            }
        }
        catch (System.Exception e)
        {
            GD.PrintErr($"[Narrative] 加载 NPC 数据失败: {e.Message}");
        }
    }

    public NpcData GetTodayScene(int day)
    {
        foreach (var npc in AllNpcs)
        {
            var scene = npc.Scenes.FirstOrDefault(s => s.Day == day);
            if (scene != null)
            {
                if (scene.Trigger == "auto") return npc;
                if (scene.Trigger.StartsWith("affection"))
                {
                    var parts = scene.Trigger.Split(">=");
                    if (parts.Length == 2 && int.TryParse(parts[1].Trim(), out var threshold))
                        if (GetAffection(npc.Id) >= threshold) return npc;
                }
            }
        }
        return null;
    }
}
