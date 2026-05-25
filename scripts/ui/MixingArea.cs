using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class MixingArea : Control
{
    // 内部物品列表
    private readonly List<string> _items = new();
    public IReadOnlyList<string> Contents => _items;

    // 信号：内容变化（物品增减/替换）
    public event Action ContentsChanged;

    // 信号：检测到异类物品 → 询问是否混合
    public event Action<string, string> CombineQuery;

    private GameManager _gm;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        MouseFilter = MouseFilterEnum.Stop;
    }

    public void AddItem(string key)
    {
        if (string.IsNullOrEmpty(key)) return;

        // 检查是否已有异类物品 → 发出混合询问
        var distinct = _items.Where(i => i != key).Distinct().ToList();
        if (distinct.Count > 0 && !_items.Contains(key))
        {
            CombineQuery?.Invoke(key, distinct[0]);
            return; // 等用户确认
        }

        _items.Add(key);
        RefreshDisplay();
    }

    /// 强制添加，跳过混合询问（用于"否"路径和内部操作）
    public void ForceAddItem(string key)
    {
        if (string.IsNullOrEmpty(key)) return;
        _items.Add(key);
        RefreshDisplay();
    }

    public void RemoveItem(string key)
    {
        var idx = _items.IndexOf(key);
        if (idx >= 0)
        {
            _items.RemoveAt(idx);
            RefreshDisplay();
        }
    }

    public void Clear()
    {
        _items.Clear();
        RefreshDisplay();
    }

    /// 消耗所有材料并替换为新物品
    public void ConsumeAndReplace(string newKey)
    {
        _items.Clear();
        _items.Add(newKey);
        RefreshDisplay();
    }

    /// 消耗指定材料列表并替换为新物品
    public void ConsumeAndReplace(string[] consumed, string newKey)
    {
        foreach (var c in consumed)
            _items.Remove(c);
        _items.Add(newKey);
        RefreshDisplay();
    }

    private void RefreshDisplay()
    {
        ContentsChanged?.Invoke();
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_items.Count == 0) return;

        var rect = GetRect();
        var margin = 8f;
        float itemW = (rect.Size.X - margin * (_items.Count + 1)) / Math.Max(1, _items.Count);
        itemW = Math.Min(itemW, 100f);

        for (int i = 0; i < _items.Count; i++)
        {
            var item = _gm.Craft.GetItem(_items[i]);
            var c = item != null ? new Color(item.Color[0], item.Color[1], item.Color[2]) : Colors.Gray;
            var x = margin + i * (itemW + margin);
            var y = rect.Size.Y * 0.25f;
            var h = rect.Size.Y * 0.5f;

            DrawRect(new Rect2(x, y, itemW, h), c);
            DrawRect(new Rect2(x, y, itemW, h), Colors.White, false);

            var name = item?.Name ?? _items[i];
            var font = ThemeDB.FallbackFont;
            if (font != null)
                DrawString(font, new Vector2(x + 2, y + 14), name,
                    HorizontalAlignment.Left, itemW - 4, 14);
        }
    }
}
