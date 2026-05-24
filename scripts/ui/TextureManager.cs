using Godot;

/// <summary>
/// Centralized texture loader. Returns null when file is missing
/// so callers can fall back to programmatic StyleBoxFlat / ColorRect.
/// </summary>
public static class TextureManager
{
    /// Try to load a Texture2D. Returns null silently if the file doesn't exist.
    public static Texture2D TryLoad(string path)
    {
        if (ResourceLoader.Exists(path))
            return GD.Load<Texture2D>(path);
        return null;
    }

    /// Try to create a StyleBoxTexture from a fixed-size texture file.
    /// Returns null if the texture is missing.
    public static StyleBoxTexture TryLoadStyleBox(string path)
    {
        var tex = TryLoad(path);
        if (tex == null) return null;
        return new StyleBoxTexture
        {
            Texture = tex,
            RegionRect = new Rect2(0, 0, tex.GetWidth(), tex.GetHeight()),
        };
    }
}
