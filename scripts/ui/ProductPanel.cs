using Godot;
using System;
using System.Collections.Generic;

public partial class ProductPanel : Control
{
    private VBoxContainer _list;
    private GameManager _gm;
    private MixingArea _mixingArea;

    public override void _Ready()
    {
        _gm = GetNode<GameManager>("/root/GameManager");
        _mixingArea = GetNode<MixingArea>("../MixingArea");
        _list = new VBoxContainer();
        AddChild(_list);

        _mixingArea.ContentsChanged += Refresh;
    }

    public override void _ExitTree()
    {
        if (_mixingArea != null)
            _mixingArea.ContentsChanged -= Refresh;
    }

    private void Refresh()
    {
        foreach (var child in _list.GetChildren())
            child.QueueFree();

        var contents = _mixingArea.Contents;
        if (contents.Count == 0) return;

        var products = new HashSet<string>();

        // Operations from each item
        foreach (var key in contents)
        {
            foreach (var kvp in _gm.Craft.GetOperations(key))
                products.Add(kvp.Value);
        }

        // Combine results for distinct items
        var distinct = new HashSet<string>(contents);
        if (distinct.Count >= 2)
        {
            var arr = new List<string>(distinct);
            for (int i = 0; i < arr.Count; i++)
                for (int j = i + 1; j < arr.Count; j++)
                {
                    var combined = _gm.Craft.GetCombineResult(arr[i], arr[j]);
                    if (combined != null) products.Add(combined);
                }
        }

        foreach (var key in products)
        {
            var item = _gm.Craft.GetItem(key);
            if (item == null) continue;
            var btn = new Button
            {
                Text = item.Name,
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
            };
            ThemeColors.StyleSmallButton(btn, 12);
            btn.Pressed += () => OnProductSelected(key);
            _list.AddChild(btn);
        }
    }

    private void OnProductSelected(string key)
    {
        var contents = new List<string>(_mixingArea.Contents);
        if (contents.Count == 1 && contents[0] == key) return;

        // Try single-item operation
        foreach (var c in contents)
        {
            var ops = _gm.Craft.GetOperations(c);
            if (ops.ContainsValue(key))
            {
                _mixingArea.ConsumeAndReplace(new[] { c }, key);
                return;
            }
        }

        // Try combine
        if (contents.Count >= 2)
        {
            for (int i = 0; i < contents.Count; i++)
                for (int j = i + 1; j < contents.Count; j++)
                {
                    if (_gm.Craft.GetCombineResult(contents[i], contents[j]) == key)
                    {
                        _mixingArea.ConsumeAndReplace(
                            new[] { contents[i], contents[j] }, key);
                        return;
                    }
                }
        }
    }

    public event Action<string> ProductSelected;
}
