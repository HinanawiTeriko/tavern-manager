using Godot;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

public class RecipeData
{
    public string Key { get; set; }
    public string Name { get; set; }
    public string[] Materials { get; set; }
    public int Price { get; set; }
    public string[] Gestures { get; set; }
    public string Icon { get; set; }
}

public class MaterialData
{
    public string Name { get; set; }
    public float[] Color { get; set; }
}

public class RecipeFile
{
    public RecipeData[] Recipes { get; set; }
    public Dictionary<string, MaterialData> Materials { get; set; }
}

public class CraftSystem
{
    public Dictionary<string, RecipeData> Recipes { get; private set; } = new();
    public Dictionary<string, MaterialData> Materials { get; private set; } = new();
    public string[] RecipeKeys { get; private set; }

    public string Slot1 { get; set; }
    public string Slot2 { get; set; }
    public string CraftedKey { get; set; }

    public bool GestureDragDone { get; set; }
    public bool GestureShakeDone { get; set; }
    public bool GestureHeatDone { get; set; }
    public bool GestureStirDone { get; set; }

    public void LoadRecipes()
    {
        using var file = FileAccess.Open("res://data/recipes.json", FileAccess.ModeFlags.Read);
        var json = file.GetAsText();
        var data = JsonSerializer.Deserialize<RecipeFile>(json);

        foreach (var r in data.Recipes)
            Recipes[r.Key] = r;
        Materials = data.Materials;
        RecipeKeys = Recipes.Keys.ToArray();
        GD.Print($"[Craft] 加载 {Recipes.Count} 个配方, {Materials.Count} 种材料");
    }

    public bool TryMatch(string mat1, string mat2, out string recipeKey)
    {
        recipeKey = null;
        var input = new List<string>();
        if (!string.IsNullOrEmpty(mat1)) input.Add(mat1);
        if (!string.IsNullOrEmpty(mat2)) input.Add(mat2);
        input.Sort();

        foreach (var (key, recipe) in Recipes)
        {
            var required = new List<string>(recipe.Materials);
            required.Sort();
            if (input.SequenceEqual(required))
            {
                recipeKey = key;
                return true;
            }
        }
        return false;
    }

    public bool AllGesturesDone(string recipeKey)
    {
        if (!Recipes.TryGetValue(recipeKey, out var recipe)) return false;
        foreach (var g in recipe.Gestures)
        {
            switch (g)
            {
                case "drag": if (!GestureDragDone) return false; break;
                case "shake": if (!GestureShakeDone) return false; break;
                case "heat": if (!GestureHeatDone) return false; break;
                case "stir": if (!GestureStirDone) return false; break;
            }
        }
        return true;
    }

    public void ResetGestures()
    {
        GestureDragDone = false;
        GestureShakeDone = false;
        GestureHeatDone = false;
        GestureStirDone = false;
    }

    public void ClearCraftSlots()
    {
        Slot1 = null;
        Slot2 = null;
        CraftedKey = null;
        ResetGestures();
    }

    public RecipeData GetRecipe(string key) =>
        Recipes.TryGetValue(key, out var r) ? r : null;

    public Color MaterialColor(string key)
    {
        if (Materials.TryGetValue(key, out var m))
        {
            var c = m.Color;
            return new Color(c[0], c[1], c[2]);
        }
        return Colors.Gray;
    }
}
