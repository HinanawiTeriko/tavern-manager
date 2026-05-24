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

    /// Try to load a StyleBoxTexture for a 9-patch capable texture.
    /// Returns null if the texture is missing.
    public static StyleBoxTexture TryLoad9Patch(string path,
        int marginLeft = 8, int marginTop = 8, int marginRight = 8, int marginBottom = 8)
    {
        var tex = TryLoad(path);
        if (tex == null) return null;
        return new StyleBoxTexture
        {
            Texture = tex,
            TextureScale = 1,
            RegionRect = new Rect2(0, 0, tex.GetWidth(), tex.GetHeight()),
            PatchMarginLeft = marginLeft,
            PatchMarginTop = marginTop,
            PatchMarginRight = marginRight,
            PatchMarginBottom = marginBottom,
            AxisStretchHorizontal = StyleBoxTexture.AxisStretchModeEnum.Tile,
            AxisStretchVertical = StyleBoxTexture.AxisStretchModeEnum.Tile,
        };
    }

    /// Try to load a StyleBoxTexture for a fixed-size (non-9-patch) texture.
    public static StyleBoxTexture TryLoadStyleBox(string path)
    {
        var tex = TryLoad(path);
        if (tex == null) return null;
        return new StyleBoxTexture
        {
            Texture = tex,
            TextureScale = 1,
            RegionRect = new Rect2(0, 0, tex.GetWidth(), tex.GetHeight()),
            PatchMarginLeft = 0,
            PatchMarginTop = 0,
            PatchMarginRight = 0,
            PatchMarginBottom = 0,
        };
    }
}
