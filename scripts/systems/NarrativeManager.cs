using Godot;
using System.Collections.Generic;

public class NarrativeManager
{
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
        if (DialogueManager.IsInstanceValid())
            ((GodotObject)DialogueManager.Instance).Call("set_variable", key, value);
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
}
