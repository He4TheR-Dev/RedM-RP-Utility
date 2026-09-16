using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace RedMRpUtility;

internal enum ActionIconKind
{
    Gear,
    Broom,
    Trash,
    Headset
}

internal sealed class ChromeButton : Control
{
    public enum ChromeKind { Minimize, Close }

    public ChromeKind Kind { get; set; }
    bool _hover;

    public ChromeButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
        Size = new Size(28, 28);
        Cursor = Cursors.Hand;
        BackColor = Color.Transparent;
    }

    protected override void OnMouseEnter(EventArgs e) { _hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; Invalidate(); base.OnMouseLeave(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        var accent = Kind == ChromeKind.Close
            ? Color.FromArgb(_hover ? 210 : 140, 168, 43, 34)
            : Color.FromArgb(_hover ? 220 : 150, 227, 169, 43);

        var fill = _hover
            ? Color.FromArgb(90, 18, 12, 8)
            : Color.FromArgb(55, 12, 9, 6);
        var border = Color.FromArgb(_hover ? 200 : 140, 150, 110, 60);

        using (var path = UiGeom.RoundRect(1, 1, Width - 3, Height - 3, 8))
        {
            using var b = new SolidBrush(fill);
            g.FillPath(b, path);
            using var p = new Pen(border, 1f);
            g.DrawPath(p, path);
        }

        using var pen = new Pen(accent, 1.6f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        if (Kind == ChromeKind.Minimize)
        {
            g.DrawLine(pen, 8, Height / 2f, Width - 9, Height / 2f);
        }
        else
        {
            g.DrawLine(pen, 9, 9, Width - 10, Height - 10);
            g.DrawLine(pen, Width - 10, 9, 9, Height - 10);
        }
    }
}

internal sealed class ActionCard : Control
{
    public string TitleText { get; set; } = "";
    public string SubtitleText { get; set; } = "";
    public Color Accent { get; set; } = Theme.Amber;
    public ActionIconKind IconKind { get; set; }

    bool _hover;
    bool _pressed;
    float _lift; // 0..3
    readonly System.Windows.Forms.Timer _anim;

    public ActionCard()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
        Cursor = Cursors.Hand;
        Height = 76;
        BackColor = Color.Transparent;
        _anim = new System.Windows.Forms.Timer { Interval = 16 };
        _anim.Tick += (_, _) =>
        {
            var target = _hover && !_pressed ? 3f : 0f;
            var next = _lift + (target - _lift) * 0.35f;
            if (Math.Abs(next - _lift) < 0.05f) next = target;
            if (Math.Abs(next - _lift) > 0.01f)
            {
                _lift = next;
                Invalidate();
            }
            else if (next == target && target == 0f)
                _anim.Stop();
        };
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _anim.Dispose();
        base.Dispose(disposing);
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        _hover = true;
        _anim.Start();
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        _hover = false;
        _pressed = false;
        _anim.Start();
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
        {
            _pressed = true;
            Invalidate();
        }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
        {
            _pressed = false;
            Invalidate();
        }
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        var scale = _pressed ? 0.985f : 1f;
        var lift = _pressed ? 0f : _lift;
        var cx = Width / 2f;
        var cy = Height / 2f;
        g.TranslateTransform(cx, cy - lift);
        g.ScaleTransform(scale, scale);
        g.TranslateTransform(-cx, -cy);

        var card = new Rectangle(2, 2, Width - 5, Height - 5);
        using var path = UiGeom.RoundRect(card.X, card.Y, card.Width, card.Height, 14);

        // Soft outer shadow
        using (var shadowPath = UiGeom.RoundRect(card.X + 1, card.Y + 3, card.Width, card.Height, 14))
        using (var shadow = new SolidBrush(Color.FromArgb(_hover ? 90 : 55, 0, 0, 0)))
            g.FillPath(shadow, shadowPath);

        // Glass / leather fill
        using (var fill = new SolidBrush(Color.FromArgb(_hover ? 195 : 166, 10, 7, 5)))
            g.FillPath(fill, path);

        // Top highlight
        using (var clip = new Region(path))
        {
            g.SetClip(clip, CombineMode.Replace);
            using var hi = new LinearGradientBrush(
                new Rectangle(card.X, card.Y, card.Width, 18),
                Color.FromArgb(_hover ? 55 : 35, 240, 210, 150),
                Color.FromArgb(0, 240, 210, 150),
                90f);
            g.FillRectangle(hi, card.X, card.Y, card.Width, 18);
            g.ResetClip();
        }

        // Inner edge
        using (var inner = new Pen(Color.FromArgb(40, 255, 230, 180), 1f))
        {
            using var innerPath = UiGeom.RoundRect(card.X + 1, card.Y + 1, card.Width - 2, card.Height - 2, 13);
            g.DrawPath(inner, innerPath);
        }

        var borderColor = _hover
            ? Color.FromArgb(230, Math.Min(255, Accent.R + 30), Math.Min(255, Accent.G + 30), Math.Min(255, Accent.B + 20))
            : Color.FromArgb(170, 140, 105, 55);
        using (var border = new Pen(borderColor, _hover ? 1.6f : 1.1f))
            g.DrawPath(border, path);

        // Accent stripe left
        using (var accentBrush = new LinearGradientBrush(
                   new Rectangle(card.X, card.Y + 10, 4, card.Height - 20),
                   Color.FromArgb(_hover ? 230 : 160, Accent),
                   Color.FromArgb(40, Accent),
                   90f))
        using (var accentPath = UiGeom.RoundRect(card.X + 3, card.Y + 12, 3, card.Height - 24, 2))
            g.FillPath(accentBrush, accentPath);

        // Icon medallion
        var iconBox = new Rectangle(card.X + 18, card.Y + (card.Height - 42) / 2, 42, 42);
        DrawMedallion(g, iconBox, Accent, _hover);
        DrawActionIcon(g, iconBox, IconKind, Accent, _hover);

        // Texts
        using var titleFont = new Font("Georgia", 12.5f, FontStyle.Bold);
        using var subFont = new Font("Segoe UI", 8.5f, FontStyle.Regular);
        using var titleBrush = new SolidBrush(_hover ? Theme.Cream : Color.FromArgb(235, 232, 216, 188));
        using var subBrush = new SolidBrush(Theme.Subtitle);

        var textX = iconBox.Right + 16;
        g.DrawString(TitleText, titleFont, titleBrush, textX, card.Y + 16);
        var subRect = new RectangleF(textX, card.Y + 40, card.Width - textX - 36, 26);
        g.DrawString(SubtitleText, subFont, subBrush, subRect);

        // Arrow
        var arrowX = card.Right - 28 + (_hover ? 3 : 0);
        var arrowY = card.Y + card.Height / 2f;
        using var arrowPen = new Pen(Color.FromArgb(_hover ? 220 : 120, Accent), 1.8f)
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round
        };
        g.DrawLine(arrowPen, arrowX, arrowY - 5, arrowX + 7, arrowY);
        g.DrawLine(arrowPen, arrowX + 7, arrowY, arrowX, arrowY + 5);
        g.DrawLine(arrowPen, arrowX - 2, arrowY, arrowX + 7, arrowY);
    }

    static void DrawMedallion(Graphics g, Rectangle box, Color accent, bool hover)
    {
        using (var shadow = new SolidBrush(Color.FromArgb(70, 0, 0, 0)))
            g.FillEllipse(shadow, box.X + 1, box.Y + 2, box.Width, box.Height);

        using (var fill = new LinearGradientBrush(box,
                   Color.FromArgb(255, 38, 28, 20),
                   Color.FromArgb(255, 16, 11, 8), 90f))
            g.FillEllipse(fill, box);

        using (var ring = new Pen(Color.FromArgb(hover ? 220 : 160, accent), hover ? 1.8f : 1.3f))
            g.DrawEllipse(ring, box);

        using (var glow = new SolidBrush(Color.FromArgb(hover ? 40 : 18, accent)))
            g.FillEllipse(glow, box.X + 6, box.Y + 6, box.Width - 12, box.Height - 12);
    }

    static void DrawActionIcon(Graphics g, Rectangle box, ActionIconKind kind, Color accent, bool hover)
    {
        var c = Color.FromArgb(hover ? 245 : 200, Math.Min(255, accent.R + 40), Math.Min(255, accent.G + 30), Math.Min(255, accent.B + 20));
        using var pen = new Pen(c, 1.7f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        using var brush = new SolidBrush(c);
        float cx = box.X + box.Width / 2f;
        float cy = box.Y + box.Height / 2f;

        switch (kind)
        {
            case ActionIconKind.Gear:
            {
                // Simple gear: outer circle + teeth stubs + hub
                for (int i = 0; i < 8; i++)
                {
                    double a = i * Math.PI / 4;
                    float x1 = cx + (float)Math.Cos(a) * 8;
                    float y1 = cy + (float)Math.Sin(a) * 8;
                    float x2 = cx + (float)Math.Cos(a) * 12;
                    float y2 = cy + (float)Math.Sin(a) * 12;
                    g.DrawLine(pen, x1, y1, x2, y2);
                }
                g.DrawEllipse(pen, cx - 8, cy - 8, 16, 16);
                g.FillEllipse(brush, cx - 3, cy - 3, 6, 6);
                break;
            }
            case ActionIconKind.Broom:
            {
                g.DrawLine(pen, cx - 2, cy - 11, cx + 6, cy + 8);
                g.DrawLine(pen, cx + 6, cy + 8, cx + 10, cy + 6);
                g.DrawLine(pen, cx - 9, cy + 4, cx - 1, cy + 11);
                g.DrawLine(pen, cx - 7, cy + 2, cx + 1, cy + 9);
                g.DrawLine(pen, cx - 5, cy + 1, cx + 3, cy + 8);
                break;
            }
            case ActionIconKind.Trash:
            {
                g.DrawLine(pen, cx - 8, cy - 6, cx + 8, cy - 6);
                g.DrawLine(pen, cx - 3, cy - 9, cx + 3, cy - 9);
                g.DrawRectangle(pen, cx - 7, cy - 4, 14, 14);
                g.DrawLine(pen, cx - 2, cy - 1, cx - 2, cy + 7);
                g.DrawLine(pen, cx + 2, cy - 1, cx + 2, cy + 7);
                break;
            }
            case ActionIconKind.Headset:
            {
                g.DrawArc(pen, cx - 10, cy - 10, 20, 18, 200, 140);
                g.FillRectangle(brush, cx - 12, cy - 2, 5, 10);
                g.FillRectangle(brush, cx + 7, cy - 2, 5, 10);
                g.DrawLine(pen, cx - 4, cy + 8, cx + 4, cy + 8);
                break;
            }
        }
    }
}

internal sealed class StatusBar : Control
{
    public string StatusText { get; private set; } = "";
    public Color StatusColor { get; private set; } = Theme.Cream;
    public bool TsDetected { get; private set; }

    public StatusBar()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
        Height = 44;
        BackColor = Color.Transparent;
    }

    public void Set(string text, Color color, bool tsDetected)
    {
        StatusText = text;
        StatusColor = color;
        TsDetected = tsDetected;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        using var path = UiGeom.RoundRect(0, 0, Width - 1, Height - 1, 12);
        using (var fill = new SolidBrush(Color.FromArgb(150, 8, 6, 4)))
            g.FillPath(fill, path);

        using (var top = new Pen(Color.FromArgb(140, 150, 110, 55), 1f))
            g.DrawLine(top, 14, 1, Width - 15, 1);

        using (var border = new Pen(Color.FromArgb(110, 120, 90, 50), 1f))
            g.DrawPath(border, path);

        if (TsDetected)
        {
            using var dot = new SolidBrush(Theme.Ok);
            g.FillEllipse(dot, 16, Height / 2f - 4, 8, 8);
            using var ring = new Pen(Color.FromArgb(120, Theme.Ok), 1f);
            g.DrawEllipse(ring, 16, Height / 2f - 4, 8, 8);
        }
        else
        {
            using var fontI = new Font("Segoe UI Semibold", 10f, FontStyle.Bold);
            using var brushI = new SolidBrush(Color.FromArgb(200, 198, 164, 122));
            g.DrawString("ⓘ", fontI, brushI, 12, Height / 2f - 9);
        }

        using var font = new Font("Segoe UI", 9f, FontStyle.Regular);
        using var brush = new SolidBrush(StatusColor);
        var textRect = new RectangleF(36, 0, Width - 48, Height);
        using var sf = new StringFormat { LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter };
        g.DrawString(StatusText, font, brush, textRect, sf);
    }
}

internal static class UiGeom
{
    public static GraphicsPath RoundRect(int x, int y, int w, int h, int r)
    {
        var gp = new GraphicsPath();
        if (w <= 0 || h <= 0) { gp.AddRectangle(new Rectangle(x, y, Math.Max(w, 0), Math.Max(h, 0))); return gp; }
        r = Math.Min(r, Math.Min(w, h) / 2);
        var d = r * 2;
        gp.AddArc(x, y, d, d, 180, 90);
        gp.AddArc(x + w - d, y, d, d, 270, 90);
        gp.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        gp.AddArc(x, y + h - d, d, d, 90, 90);
        gp.CloseFigure();
        return gp;
    }
}

internal sealed class MainForm : Form
{
    readonly StatusBar _status = new();
    readonly ActionCard _btnInstall = new();
    readonly ActionCard _btnClean = new();
    readonly ActionCard _btnUninstall = new();
    readonly ActionCard _btnOpen = new();
    readonly ChromeButton _btnMin = new() { Kind = ChromeButton.ChromeKind.Minimize };
    readonly ChromeButton _btnClose = new() { Kind = ChromeButton.ChromeKind.Close };
    readonly Panel _dragZone = new();

    Image? _backdrop;
    bool _busy;
    bool _tsDetected;
    float _bootLine; // 0..1 startup accent line
    readonly System.Windows.Forms.Timer _bootAnim = new() { Interval = 16 };

    const int WindowW = 560;
    const int WindowH = 680;
    const int CornerRadius = 16;

    public MainForm()
    {
        Text = "RedM RP Utility";
        FormBorderStyle = FormBorderStyle.None;
        MaximizeBox = false;
        MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(WindowW, WindowH);
        BackColor = Color.FromArgb(10, 7, 5);
        Font = new Font("Segoe UI", 9f);
        DoubleBuffered = true;
        ShowInTaskbar = true;
        KeyPreview = true;

        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);

        try
        {
            var icoPath = Path.Combine(AppContext.BaseDirectory, "Assets", "app.ico");
            if (!File.Exists(icoPath))
                icoPath = Path.Combine(AppContext.BaseDirectory, "app.ico");
            if (File.Exists(icoPath))
            {
                // Load best-match large icon (taskbar / Alt-Tab); ICO contains all sizes
                Icon = new Icon(icoPath, 256, 256);
            }
            else
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
        }
        catch { }

        LoadBackground();
        RebuildBackdrop();
        BuildUi();
        ApplyRoundedRegion();
        RefreshStatus();

        _bootAnim.Tick += (_, _) =>
        {
            _bootLine = Math.Min(1f, _bootLine + 0.045f);
            Invalidate(new Rectangle(40, 92, Width - 80, 4));
            if (_bootLine >= 1f) _bootAnim.Stop();
        };
        Shown += (_, _) => _bootAnim.Start();
    }

    void LoadBackground()
    {
        // Touch shared cache so first paint is ready
        _ = ThemeAssets.BackgroundSource;
    }

    void RebuildBackdrop()
    {
        if (ClientSize.Width <= 0 || ClientSize.Height <= 0) return;
        var old = _backdrop;
        _backdrop = ThemeAssets.BuildCoverBackdrop(ClientSize, 0.165f, new Rectangle(36, 112, Width - 72, 430));
        BackgroundImage = _backdrop;
        BackgroundImageLayout = ImageLayout.None;
        old?.Dispose();
    }

    void BuildUi()
    {
        // Drag zone (top header area)
        _dragZone.Location = new Point(0, 0);
        _dragZone.Size = new Size(WindowW - 80, 108);
        _dragZone.BackColor = Color.Transparent;
        _dragZone.MouseDown += DragZone_MouseDown;
        Controls.Add(_dragZone);

        _btnMin.Location = new Point(WindowW - 78, 16);
        _btnClose.Location = new Point(WindowW - 44, 16);
        _btnMin.Size = new Size(28, 28);
        _btnClose.Size = new Size(28, 28);
        _btnMin.Click += (_, _) => WindowState = FormWindowState.Minimized;
        _btnClose.Click += (_, _) => Close();
        Controls.Add(_btnMin);
        Controls.Add(_btnClose);
        _btnMin.BringToFront();
        _btnClose.BringToFront();
        _dragZone.SendToBack();

        ConfigureCard(_btnInstall, "Installer / Réparer",
            "TeamSpeak 3 + SaltyChat + thème — tout inclus",
            Theme.Amber, ActionIconKind.Gear);
        ConfigureCard(_btnClean, "Nettoyer cache RedM",
            "Vide Logs, Crashes et Data — conserve game-storage",
            Theme.Rust, ActionIconKind.Broom);
        ConfigureCard(_btnUninstall, "Désinstaller tout",
            "Retire TeamSpeak, SaltyChat et Overwolf",
            Theme.Crimson, ActionIconKind.Trash);
        ConfigureCard(_btnOpen, "Ouvrir TeamSpeak 3",
            "Lance le client s'il est installé",
            Theme.Steel, ActionIconKind.Headset);

        const int cardX = 48;
        const int cardW = WindowW - 96;
        var y = 128;
        const int gap = 18;
        foreach (var c in new[] { _btnInstall, _btnClean, _btnUninstall, _btnOpen })
        {
            c.Location = new Point(cardX, y);
            c.Width = cardW;
            Controls.Add(c);
            y += c.Height + gap;
        }

        _btnInstall.Click += async (_, _) => await RunSafeAsync(InstallAsync);
        _btnClean.Click += async (_, _) => await RunSafeAsync(CleanAsync);
        _btnUninstall.Click += async (_, _) => await RunSafeAsync(UninstallAsync);
        _btnOpen.Click += async (_, _) => await RunSafeAsync(OpenTsAsync);

        _status.Location = new Point(cardX, WindowH - 68);
        _status.Width = cardW;
        Controls.Add(_status);
    }

    static void ConfigureCard(ActionCard card, string title, string sub, Color accent, ActionIconKind icon)
    {
        card.TitleText = title;
        card.SubtitleText = sub;
        card.Accent = accent;
        card.IconKind = icon;
    }

    void DragZone_MouseDown(object? sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        ReleaseCapture();
        _ = SendMessage(Handle, 0xA1, 0x2, 0); // WM_NCLBUTTONDOWN, HTCAPTION
    }

    void ApplyRoundedRegion()
    {
        using var path = UiGeom.RoundRect(0, 0, Width, Height, CornerRadius);
        Region?.Dispose();
        Region = new Region(path);
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (WindowState != FormWindowState.Minimized)
        {
            ApplyRoundedRegion();
            RebuildBackdrop();
        }
    }

    void SetStatus(string text, Color? color = null)
    {
        if (InvokeRequired) { BeginInvoke(() => SetStatus(text, color)); return; }
        _status.Set(text, color ?? Theme.Muted, _tsDetected);
    }

    void RefreshStatus()
    {
        var ts = Paths.FindTs3();
        _tsDetected = ts != null;
        if (_tsDetected)
            SetStatus("TeamSpeak 3 détecté", Theme.Cream);
        else
            SetStatus("TeamSpeak 3 non détecté — utilise Installer / Réparer.", Theme.Cream);
    }

    void SetBusy(bool busy)
    {
        _busy = busy;
        foreach (Control c in Controls)
            if (c is ActionCard ac) ac.Enabled = !busy;
        UseWaitCursor = busy;
    }

    async Task RunSafeAsync(Func<Task> action)
    {
        if (_busy) return;
        SetBusy(true);
        try { await action(); }
        catch (Exception ex) { SetStatus("Erreur : " + ex.Message, Theme.Danger); }
        finally { SetBusy(false); RefreshStatus(); }
    }

    Task InstallAsync()
    {
        if (!FullInstaller.DependenciesPresent())
        {
            SetStatus("Dépendances manquantes. Installe RedM-RP-Utility-Setup.exe d'abord.", Theme.Danger);
            return Task.CompletedTask;
        }

        if (ConfirmDialog.Show(this,
                "Installer / Réparer",
                "Installer ou réparer TeamSpeak 3 + SaltyChat + thème Red Dead ?\n\nTu vas choisir micro, casque et Push-To-Talk.",
                "Continuer", "Annuler") != DialogResult.Yes)
        {
            SetStatus("Installation annulée.", Theme.Muted);
            return Task.CompletedTask;
        }

        Directory.CreateDirectory(Paths.LogDir);
        var config = Path.Combine(Paths.LogDir, "audio-config.ini");
        using (var audio = new AudioConfigForm(config))
        {
            if (audio.ShowDialog(this) != DialogResult.OK || !File.Exists(config))
            {
                SetStatus("Configuration audio annulée.", Theme.Muted);
                return Task.CompletedTask;
            }
        }

        var progressUi = new InstallProgressForm();
        progressUi.Show(this);
        progressUi.SetProgress("Démarrage...", 5);

        var progress = new Progress<string>(m =>
        {
            SetStatus(m, Theme.Gold);
            var pct = m.Contains("TeamSpeak", StringComparison.OrdinalIgnoreCase) ? 35
                : m.Contains("SaltyChat", StringComparison.OrdinalIgnoreCase) ? 70
                : m.Contains("Termine", StringComparison.OrdinalIgnoreCase) || m.Contains("Terminé", StringComparison.OrdinalIgnoreCase) ? 100
                : m.Contains("audio", StringComparison.OrdinalIgnoreCase) ? 15
                : 50;
            progressUi.SetProgress(m, pct);
        });

        return Task.Run(() =>
        {
            var result = FullInstaller.Run(progress, skipAudioUi: true);
            BeginInvoke(() =>
            {
                try { progressUi.Close(); progressUi.Dispose(); } catch { }
                SetStatus(result.Message, result.Ok ? Theme.Cream : Theme.Danger);
            });
        });
    }

    Task CleanAsync()
    {
        SetStatus("Nettoyage du cache RedM...", Theme.Gold);
        return Task.Run(() =>
        {
            var r = RedMCleaner.Run();
            BeginInvoke(() => SetStatus(r.Message, r.Cleaned || !r.FoundRoot ? Theme.Cream : Theme.Ok));
        });
    }

    Task UninstallAsync()
    {
        if (ConfirmDialog.Show(this,
                "Désinstaller tout",
                "Désinstaller TeamSpeak 3, SaltyChat et Overwolf ?\n\nRedM et game-storage ne sont pas touchés.",
                "Désinstaller", "Annuler", danger: true) != DialogResult.Yes)
        {
            SetStatus("Désinstallation annulée.", Theme.Muted);
            return Task.CompletedTask;
        }

        SetStatus("Désinstallation en cours...", Theme.Gold);
        return Task.Run(() =>
        {
            var msg = Uninstaller.Run();
            BeginInvoke(() => SetStatus(msg, Theme.Cream));
        });
    }

    Task OpenTsAsync()
    {
        var exe = Paths.FindTs3();
        if (exe == null)
        {
            SetStatus("TeamSpeak 3 introuvable. Lance Installer / Réparer.", Theme.Danger);
            return Task.CompletedTask;
        }
        Process.Start(new ProcessStartInfo(exe) { UseShellExecute = true });
        SetStatus("TeamSpeak 3 lancé.", Theme.Cream);
        return Task.CompletedTask;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        // Header title (drawn above BackgroundImage)
        using (var titleFont = new Font("Georgia", 26f, FontStyle.Bold))
        using (var glow = new SolidBrush(Color.FromArgb(45, 227, 169, 43)))
        using (var title = new SolidBrush(Theme.Cream))
        using (var accent = new SolidBrush(Color.FromArgb(220, 160, 45, 35)))
        {
            const string brand = "RedM RP Utility";
            var size = g.MeasureString(brand, titleFont);
            var tx = (Width - size.Width) / 2f;
            const float ty = 28f;
            g.DrawString(brand, titleFont, glow, tx + 1, ty + 1);
            g.DrawString(brand, titleFont, title, tx, ty);
            var rp = g.MeasureString("RedM ", titleFont);
            g.FillRectangle(accent, tx + rp.Width, ty + size.Height - 6, 28, 2);
        }

        using (var subFont = new Font("Segoe UI", 9f, FontStyle.Regular))
        using (var subBrush = new SolidBrush(Theme.Subtitle))
        {
            const string sub = "TeamSpeak  •  SaltyChat  •  Cache RedM";
            var size = g.MeasureString(sub, subFont);
            g.DrawString(sub, subFont, subBrush, (Width - size.Width) / 2f, 68);
        }

        var lineW = (Width - 120) * _bootLine;
        if (lineW > 1)
        {
            var lx = (Width - lineW) / 2f;
            using var line = new LinearGradientBrush(
                new RectangleF(lx, 94, (float)lineW, 2),
                Color.FromArgb(0, 227, 169, 43),
                Color.FromArgb(210, 227, 169, 43),
                0f);
            g.FillRectangle(line, lx, 96, (float)lineW, 1.5f);
        }

        using (var rimPath = UiGeom.RoundRect(1, 1, Width - 3, Height - 3, CornerRadius - 1))
        using (var rim = new Pen(Color.FromArgb(160, 110, 80, 40), 1.4f))
            g.DrawPath(rim, rimPath);
        using (var rim2 = new Pen(Color.FromArgb(80, 40, 28, 16), 2.2f))
        using (var rimPath2 = UiGeom.RoundRect(0, 0, Width - 1, Height - 1, CornerRadius))
            g.DrawPath(rim2, rimPath2);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _bootAnim.Dispose();
        BackgroundImage = null;
        _backdrop?.Dispose();
        base.OnFormClosed(e);
    }

    [DllImport("user32.dll")]
    static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);
}
