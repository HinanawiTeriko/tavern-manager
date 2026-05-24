using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

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

    // 对话变量池 — Godot Dictionary 直接作为 extra_game_state 传给 Dialogue Manager
    // DM 的 set/if 表达式会直接读写此 Dictionary
    public Godot.Collections.Dictionary DialogueVars { get; private set; } = new();

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
        DialogueVars[key] = Variant.From(value);
    }

    public object GetVar(string key) =>
        DialogueVars.TryGetValue(key, out var v) ? v.Obj : null;

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
        DialogueVars.TryGetValue($"aff_{npcId}", out var v) ? v.AsInt32() : 0;

    public void SetEnding(string npcId, string ending)
    {
        Endings[npcId] = ending;
        GD.Print($"[Narrative] {npcId} 结局 → {ending}");
    }

    // ── NPC 数据加载 ──

    public void LoadNpcData()
    {
        // 预初始化所有对话变量，避免 DM 因变量未找到而断言失败
        // （即使用到的 NPC 尚未加载，这些占位值也能保证 DM 的 set/if 不崩溃）
        DialogueVars["has_sleep_powder"] = Variant.From(false);
        DialogueVars["ryan_drugged"] = Variant.From(false);
        DialogueVars["ryan_ending"] = Variant.From("");
        DialogueVars["aff_ryan"] = Variant.From(0);
        DialogueVars["aff_mira"] = Variant.From(5);

        try
        {
            using var file = FileAccess.Open("res://data/npcs.json", FileAccess.ModeFlags.Read);
            if (file == null)
            {
                GD.Print("[Narrative] npcs.json 未找到，使用默认变量");
                return;
            }
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

    public List<NpcData> GetTodayScenes(int day)
    {
        var result = new List<NpcData>();
        foreach (var npc in AllNpcs)
        {
            var scene = npc.Scenes.FirstOrDefault(s => s.Day == day);
            if (scene != null)
            {
                if (scene.Trigger == "auto")
                {
                    result.Add(npc);
                }
                else if (scene.Trigger.StartsWith("affection"))
                {
                    var parts = scene.Trigger.Split(">=");
                    if (parts.Length == 2 && int.TryParse(parts[1].Trim(), out var threshold))
                        if (GetAffection(npc.Id) >= threshold) result.Add(npc);
                }
            }
        }
        return result;
    }

    /// Get fate entries for NPCs whose ending was sealed today.
    public List<(string NpcName, string NpcTitle, string FateText)> GetTodayNpcFates(int day)
    {
        var result = new List<(string NpcName, string NpcTitle, string FateText)>();

        foreach (var npc in AllNpcs)
        {
            var scene = npc.Scenes.FirstOrDefault(s => s.Day == day);
            if (scene == null) continue;

            var endingVar = $"{npc.Id}_ending";
            if (DialogueVars.TryGetValue(endingVar, out var endingVal))
            {
                var endingKey = endingVal.AsString();
                if (!string.IsNullOrEmpty(endingKey) && npc.Endings != null
                    && npc.Endings.TryGetValue(endingKey, out var fateText))
                {
                    result.Add((npc.Name, npc.Title, fateText));
                }
            }
        }

        return result;
    }
}
