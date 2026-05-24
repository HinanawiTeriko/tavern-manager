using Godot;
using System;
using System.Collections.Generic;

/// <summary>
/// Pixel-art ambient animation for TitleScreen:
/// twinkling stars (upper-left) + dust motes floating in a light beam (mid-lower).
/// Renders via _Draw() with hard-edged rects — no smooth gradients.
/// </summary>
public partial class TitleAmbience : Node2D
{
    // ── Stars ──
    [Export] public Rect2 StarRegion = new(20, 20, 380, 200);
    [Export] public int StarCount = 10;
    [Export] public Color StarColor = Colors.White;
    [Export] public float StarBaseSize = 3f;

    private struct Star
    {
        public Vector2 Pos;
        public float Phase;      // 0..2pi
        public float Speed;      // rad/s
        public float SizeMul;    // 0.7..1.4
    }
    private Star[] _stars;

    // ── Dust ──
    [Export] public Rect2 DustRegion = new(380, 280, 560, 280);
    [Export] public int DustCount = 30;
    [Export] public Color DustColor = new(1.0f, 0.82f, 0.55f); // warm amber
    [Export] public float DustBaseSize = 2f;

    private struct Mote
    {
        public Vector2 Pos;
        public Vector2 Vel;
        public float Life;
        public float MaxLife;
        public float Size;
        public float Alpha;
    }
    private Mote[] _motes;

    private Random _rng = new();
    private float _time;

    public override void _Ready()
    {
        ZIndex = -50; // behind UI, above background

        // Init stars
        _stars = new Star[StarCount];
        for (int i = 0; i < StarCount; i++)
        {
            _stars[i] = new Star
            {
                Pos = new Vector2(
                    StarRegion.Position.X + (float)_rng.NextDouble() * StarRegion.Size.X,
                    StarRegion.Position.Y + (float)_rng.NextDouble() * StarRegion.Size.Y
                ),
                Phase = (float)(_rng.NextDouble() * Math.PI * 2),
                Speed = 0.8f + (float)_rng.NextDouble() * 2.5f,
                SizeMul = 0.6f + (float)_rng.NextDouble() * 0.9f
            };
        }

        // Init dust motes
        _motes = new Mote[DustCount];
        for (int i = 0; i < DustCount; i++)
        {
            _motes[i] = SpawnMote(initial: true);
        }
    }

    private Mote SpawnMote(bool initial)
    {
        var m = new Mote
        {
            Pos = new Vector2(
                DustRegion.Position.X + (float)_rng.NextDouble() * DustRegion.Size.X,
                DustRegion.Position.Y + (float)_rng.NextDouble() * DustRegion.Size.Y
            ),
            Vel = new Vector2(
                -8f + (float)_rng.NextDouble() * 16f,
                -10f - (float)_rng.NextDouble() * 15f
            ),
            MaxLife = 3f + (float)_rng.NextDouble() * 6f,
            Size = 1f + (float)_rng.NextDouble() * 2.5f,
            Alpha = 0.3f + (float)_rng.NextDouble() * 0.7f
        };
        if (initial)
            m.Life = (float)_rng.NextDouble() * m.MaxLife;
        else
            m.Life = m.MaxLife;
        return m;
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;
        _time += dt;

        // Update stars
        for (int i = 0; i < _stars.Length; i++)
        {
            _stars[i].Phase += _stars[i].Speed * dt;
            if (_stars[i].Phase > Math.PI * 2)
                _stars[i].Phase -= (float)(Math.PI * 2);
        }

        // Update dust
        for (int i = 0; i < _motes.Length; i++)
        {
            _motes[i].Life -= dt;
            _motes[i].Pos += _motes[i].Vel * dt;
            // gentle horizontal wobble
            _motes[i].Vel.X += (-4f + (float)_rng.NextDouble() * 8f) * dt;

            if (_motes[i].Life <= 0 ||
                !DustRegion.HasPoint(_motes[i].Pos))
            {
                _motes[i] = SpawnMote(initial: false);
            }
        }

        QueueRedraw();
    }

    public override void _Draw()
    {
        // ── Draw stars: discrete 3-level brightness ──
        for (int i = 0; i < _stars.Length; i++)
        {
            float raw = (Mathf.Sin(_stars[i].Phase) + 1f) / 2f; // 0..1

            // Quantize to 4 discrete levels for pixel feel
            float brightness;
            if (raw < 0.15f) brightness = 0f;       // off
            else if (raw < 0.4f) brightness = 0.25f; // dim
            else if (raw < 0.75f) brightness = 0.6f; // medium
            else brightness = 1.0f;                   // bright

            if (brightness < 0.01f) continue;

            float size = StarBaseSize * _stars[i].SizeMul;
            Color c = new(StarColor, brightness);

            // Draw as small cross for bright stars, dot for dim ones
            if (brightness >= 0.6f)
            {
                // 3×3 pixel cross
                DrawRect(new Rect2(_stars[i].Pos.X - size * 0.5f, _stars[i].Pos.Y - size * 1.5f, size, size * 3f), c);
                DrawRect(new Rect2(_stars[i].Pos.X - size * 1.5f, _stars[i].Pos.Y - size * 0.5f, size * 3f, size), c);
            }
            else
            {
                // simple dot
                DrawRect(new Rect2(_stars[i].Pos.X - size * 0.5f, _stars[i].Pos.Y - size * 0.5f, size, size), c);
            }
        }

        // ── Draw dust: small hard-edged dots ──
        for (int i = 0; i < _motes.Length; i++)
        {
            float lifeRatio = _motes[i].Life / _motes[i].MaxLife;
            float alpha = _motes[i].Alpha * Mathf.Min(lifeRatio * 1.5f, 1f);
            float size = _motes[i].Size;
            Color c = new(DustColor, alpha);

            DrawRect(new Rect2(
                _motes[i].Pos.X - size * 0.5f,
                _motes[i].Pos.Y - size * 0.5f,
                size, size
            ), c);
        }
    }
}
