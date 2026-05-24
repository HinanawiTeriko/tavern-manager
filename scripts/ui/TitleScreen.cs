using Godot;

public partial class TitleScreen : Node2D
{
	public override void _Ready()
	{
		// -- Ambience --
		var ambience = GetNode<TitleAmbience>("Ambience");
		ambience.StarColor = new Color(ThemeColors.AmberPrimary, 0.9f);
		ambience.DustColor = ThemeColors.AmberPrimary;

		// -- Title --
		var title = GetNode<Label>("UI/TitlePanel/TitleLabel");
		ThemeColors.StyleHeader(title, 48);
		title.AddThemeConstantOverride("outline_size", 4);
		title.AddThemeColorOverride("font_outline_color", new Color(0, 0, 0, 0.6f));

		// -- Title panel --
		var titlePanel = GetNode<Panel>("UI/TitlePanel");
		var panelStyle = new StyleBoxFlat
		{
			BgColor = new Color(ThemeColors.SurfaceMid, 0.7f),
			BorderWidthLeft = 2, BorderWidthTop = 2,
			BorderWidthRight = 2, BorderWidthBottom = 2,
			BorderColor = new Color(ThemeColors.AmberPrimary, 0.3f)
		};
		titlePanel.AddThemeStyleboxOverride("panel", panelStyle);

		// -- Subtitle --
		var subtitle = GetNode<Label>("UI/SubtitleLabel");
		subtitle.AddThemeColorOverride("font_color", ThemeColors.TextSubtitle);
		subtitle.AddThemeFontSizeOverride("font_size", 18);

		// -- Start button --
		var btn = GetNode<Button>("UI/StartButton");
		ThemeColors.StyleButton(btn, 22);
		btn.Pressed += OnStart;

		// -- Hint --
		var hint = GetNode<Label>("UI/HintLabel");
		hint.AddThemeColorOverride("font_color", new Color(ThemeColors.TextLight, 0.6f));
		hint.AddThemeFontSizeOverride("font_size", 14);

		// -- Version --
		var ver = GetNode<Label>("UI/VersionLabel");
		ver.AddThemeColorOverride("font_color", new Color(ThemeColors.TextSubtitle, 0.35f));
		ver.AddThemeFontSizeOverride("font_size", 11);

		// -- Decorative elements (load textures if available) --
		TryLoadDeco("Deco/CandleLeft", "res://assets/textures/ui/deco_candle_left.png");
		TryLoadDeco("Deco/CandleRight", "res://assets/textures/ui/deco_candle_right.png");
		TryLoadDeco("Deco/Mug", "res://assets/textures/ui/deco_mug.png");
		TryLoadDeco("Deco/Emblem", "res://assets/textures/ui/deco_emblem.png");

		// -- Title sign image --
		var titleSign = GetNodeOrNull<TextureRect>("UI/TitlePanel/TitleSign");
		if (titleSign != null)
		{
			var signTex = TextureManager.TryLoad("res://assets/textures/ui/title_sign.png");
			if (signTex != null) titleSign.Texture = signTex;
		}
	}

	private void TryLoadDeco(string nodePath, string texPath)
	{
		var node = GetNodeOrNull<Sprite2D>(nodePath);
		if (node != null)
		{
			var tex = TextureManager.TryLoad(texPath);
			if (tex != null) node.Texture = tex;
		}
	}

	private void OnStart()
	{
		GetTree().ChangeSceneToFile("res://scenes/ui/DayMap.tscn");
	}
}
