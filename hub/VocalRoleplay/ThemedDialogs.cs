using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace RedMRpUtility;

internal static class ThemeAssets
{
    static Image? _source;
    static readonly object Gate = new();

    public static Image? BackgroundSource
    {
        get
        {
            lock (Gate)
            {
                if (_source != null) return _source;
                _source = LoadBackground();
                return _source;
            }
        }
    }

    static Image? LoadBackground()
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "background_redm.png");
            if (File.Exists(path))
                return Image.FromFile(path);
        }
        catch { }

        try
        {
            using var stream = typeof(ThemeAssets).Assembly.GetManifestResourceStream("RedMRpUtility.Assets.background_redm.png");
            if (stream != null)
            {
                using var temp = Image.FromStream(stream);
                return new Bitmap(temp);
            }
        }
        catch { }

        return null;
    }

    public static Image BuildCoverBackdrop(Size client, float overlayAlpha = 0.18f, Rectangle? dimPanel = null)
    {
        var bmp = new Bitmap(Math.Max(1, client.Width), Math.Max(1, client.Height), PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        var src = BackgroundSource;
        if (src != null)
            g.DrawImage(src, CoverRect(client, src.Size));
        else
        {
            using var fallback = new LinearGradientBrush(new Rectangle(Point.Empty, client),
                Color.FromArgb(20, 12, 8), Color.FromArgb(8, 5, 3), 90f);
            g.FillRectangle(fallback, 0, 0, client.Width, client.Height);
        }

        var a = (int)Math.Clamp(overlayAlpha * 255, 0, 255);
        using (var overlay = new SolidBrush(Color.FromArgb(a, 0, 0, 0)))
            g.FillRectangle(overlay, 0, 0, client.Width, client.Height);

        if (dimPanel is { } panel && panel.Width > 0 && panel.Height > 0)
        {
            using var path = UiGeom.RoundRect(panel.X, panel.Y, panel.Width, panel.Height, 16);
            using var brush = new SolidBrush(Color.FromArgb(55, 6, 4, 3));
            g.FillPath(brush, path);
        }

        return bmp;
    }

    public static Rectangle CoverRect(Size client, Size image)
    {
        if (image.Width <= 0 || image.Height <= 0) return new Rectangle(Point.Empty, client);
        var scale = Math.Max(client.Width / (float)image.Width, client.Height / (float)image.Height);
        var w = (int)Math.Ceiling(image.Width * scale);
        var h = (int)Math.Ceiling(image.Height * scale);
        var x = (client.Width - w) / 2;
        var y = (client.Height - h) / 2 - (int)(h * 0.02f);
        return new Rectangle(x, y, w, h);
    }
}

/// <summary>Borderless themed window shell shared by confirm / audio / progress dialogs.</summary>
internal class ThemedForm : Form
{
    Image? _backdrop;
    readonly bool _showClose;
    ChromeButton? _btnClose;
    const int Corner = 16;
    protected const int ChromeInset = 18;
    protected const int HeaderTop = 22;

    /// <summary>Painted title (avoids Label clipping under rounded Region).</summary>
    protected string HeaderTitle { get; set; } = "";

    protected ThemedForm(Size clientSize, bool showClose = true)
    {
        AutoScaleMode = AutoScaleMode.Dpi;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterParent;
        ShowInTaskbar = false;
        MaximizeBox = false;
        MinimizeBox = false;
        KeyPreview = true;
        DoubleBuffered = true;
        BackColor = Color.FromArgb(10, 7, 5);
        Padding = new Padding(0);
        ClientSize = clientSize;
        _showClose = showClose;

        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);

        try
        {
            var ico = Path.Combine(AppContext.BaseDirectory, "Assets", "app.ico");
            if (File.Exists(ico)) Icon = new Icon(ico);
        }
        catch { }

        RebuildBackdrop();
        ApplyRegion();
        BuildChrome();

        // Drag from empty chrome area (not via overlapping Panel over title)
        MouseDown += ThemedForm_MouseDown;
    }

    void ThemedForm_MouseDown(object? sender, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        // Only drag from the header strip
        if (e.Y > 56) return;
        if (_btnClose != null && _btnClose.Bounds.Contains(e.Location)) return;
        ReleaseCapture();
        _ = SendMessage(Handle, 0xA1, 0x2, 0);
    }

    void BuildChrome()
    {
        if (!_showClose) return;
        _btnClose = new ChromeButton
        {
            Kind = ChromeButton.ChromeKind.Close,
            Location = new Point(Width - ChromeInset - 30, ChromeInset),
            Size = new Size(30, 30)
        };
        _btnClose.Click += (_, _) =>
        {
            DialogResult = DialogResult.Cancel;
            Close();
        };
        Controls.Add(_btnClose);
        _btnClose.BringToFront();
    }

    protected void RebuildBackdrop(Rectangle? dimPanel = null)
    {
        var old = _backdrop;
        _backdrop = ThemeAssets.BuildCoverBackdrop(ClientSize, 0.20f, dimPanel);
        BackgroundImage = _backdrop;
        BackgroundImageLayout = ImageLayout.None;
        old?.Dispose();
    }

    void ApplyRegion()
    {
        // Expand region by 1px so antialiased rim/text near edges aren't clipped
        using var path = UiGeom.RoundRect(0, 0, Width, Height, Corner);
        Region?.Dispose();
        Region = new Region(path);
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (WindowState == FormWindowState.Minimized) return;
        ApplyRegion();
        if (_btnClose != null)
            _btnClose.Location = new Point(Width - ChromeInset - _btnClose.Width, ChromeInset);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        if (!string.IsNullOrEmpty(HeaderTitle))
        {
            using var titleFont = new Font("Georgia", 15.5f, FontStyle.Bold);
            using var glow = new SolidBrush(Color.FromArgb(40, 227, 169, 43));
            using var brush = new SolidBrush(Theme.Cream);
            const float tx = 36f;
            float ty = HeaderTop;
            // Keep title clear of the close button
            var maxW = Width - (_showClose ? 80 : 48);
            var layout = new RectangleF(tx, ty, maxW, 40);
            g.DrawString(HeaderTitle, titleFont, glow, layout.X + 1, layout.Y + 1);
            g.DrawString(HeaderTitle, titleFont, brush, layout);
        }

        using var rim = new Pen(Color.FromArgb(160, 110, 80, 40), 1.4f);
        using var path = UiGeom.RoundRect(1, 1, Width - 3, Height - 3, Corner - 1);
        g.DrawPath(rim, path);
        using var rim2 = new Pen(Color.FromArgb(90, 40, 28, 16), 2f);
        using var path2 = UiGeom.RoundRect(0, 0, Width - 1, Height - 1, Corner);
        g.DrawPath(rim2, path2);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        BackgroundImage = null;
        _backdrop?.Dispose();
        base.OnFormClosed(e);
    }

    protected static Label MakeSub(string text, int x, int y, int w, int h = 36)
    {
        return new Label
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            Font = new Font("Segoe UI", 9.5f),
            ForeColor = Theme.Subtitle,
            BackColor = Color.Transparent,
            AutoSize = false
        };
    }

    protected static Button MakeAccentButton(string text, Color accent, int x, int y, int w = 130, int h = 40)
    {
        var b = new Button
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Georgia", 10f, FontStyle.Bold),
            ForeColor = Color.FromArgb(20, 12, 6),
            BackColor = accent,
            Cursor = Cursors.Hand,
            Padding = new Padding(4)
        };
        b.FlatAppearance.BorderColor = Color.FromArgb(180, accent);
        b.FlatAppearance.MouseOverBackColor = Color.FromArgb(
            Math.Min(255, accent.R + 20), Math.Min(255, accent.G + 20), Math.Min(255, accent.B + 10));
        return b;
    }

    protected static Button MakeGhostButton(string text, int x, int y, int w = 110, int h = 40)
    {
        var b = new Button
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            ForeColor = Theme.Cream,
            BackColor = Color.FromArgb(60, 20, 14, 10),
            Cursor = Cursors.Hand,
            Padding = new Padding(4)
        };
        b.FlatAppearance.BorderColor = Color.FromArgb(160, 140, 100, 55);
        b.FlatAppearance.MouseOverBackColor = Color.FromArgb(90, 40, 28, 18);
        return b;
    }

    [DllImport("user32.dll")]
    static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);
}

internal sealed class ConfirmDialog : ThemedForm
{
    public ConfirmDialog(string title, string body, string yesText, string noText, bool danger)
        : base(new Size(520, 320))
    {
        Text = title;
        HeaderTitle = title;
        RebuildBackdrop(new Rectangle(32, 78, Width - 64, 150));

        var bodyLabel = MakeSub(body, 40, 78, Width - 80, 120);
        Controls.Add(bodyLabel);

        var yes = MakeAccentButton(yesText, danger ? Theme.Crimson : Theme.Amber, Width - 292, Height - 70, 128, 42);
        var no = MakeGhostButton(noText, Width - 152, Height - 70, 120, 42);
        yes.Click += (_, _) => { DialogResult = DialogResult.Yes; Close(); };
        no.Click += (_, _) => { DialogResult = DialogResult.No; Close(); };
        AcceptButton = yes;
        CancelButton = no;
        Controls.Add(yes);
        Controls.Add(no);
        yes.BringToFront();
        no.BringToFront();
        if (Controls.OfType<ChromeButton>().FirstOrDefault() is { } close)
            close.BringToFront();
    }

    public static DialogResult Show(IWin32Window owner, string title, string body, string yesText = "Oui", string noText = "Non", bool danger = false)
    {
        using var dlg = new ConfirmDialog(title, body, yesText, noText, danger);
        return dlg.ShowDialog(owner);
    }
}

internal sealed class InstallProgressForm : ThemedForm
{
    readonly Label _step;
    readonly Label _detail;
    readonly Panel _barTrack;
    readonly Panel _barFill;
    int _pct;

    public InstallProgressForm()
        : base(new Size(540, 260), showClose: false)
    {
        Text = "Installation";
        HeaderTitle = "Installation en cours";
        RebuildBackdrop(new Rectangle(32, 78, Width - 64, 130));

        _step = new Label
        {
            Text = "Préparation...",
            Location = new Point(44, 96),
            Size = new Size(Width - 88, 30),
            Font = new Font("Georgia", 11f, FontStyle.Bold),
            ForeColor = Theme.Amber,
            BackColor = Color.Transparent
        };
        _detail = new Label
        {
            Text = "TeamSpeak 3  •  SaltyChat  •  Thème Red Dead",
            Location = new Point(44, 130),
            Size = new Size(Width - 88, 24),
            Font = new Font("Segoe UI", 9f),
            ForeColor = Theme.Subtitle,
            BackColor = Color.Transparent
        };

        _barTrack = new Panel
        {
            Location = new Point(44, 180),
            Size = new Size(Width - 88, 12),
            BackColor = Color.FromArgb(80, 20, 14, 10)
        };
        _barFill = new Panel
        {
            Location = new Point(0, 0),
            Size = new Size(8, 12),
            BackColor = Theme.Amber
        };
        _barTrack.Controls.Add(_barFill);

        Controls.Add(_step);
        Controls.Add(_detail);
        Controls.Add(_barTrack);
        _step.BringToFront();
        _detail.BringToFront();
        _barTrack.BringToFront();
    }

    public void SetProgress(string step, int percent)
    {
        if (IsDisposed) return;
        if (InvokeRequired) { BeginInvoke(() => SetProgress(step, percent)); return; }
        _step.Text = step;
        _pct = Math.Clamp(percent, 0, 100);
        _barFill.Width = Math.Max(8, (int)(_barTrack.Width * (_pct / 100.0)));
    }
}
