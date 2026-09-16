using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32;

namespace RedMRpUtility;

internal sealed class AudioDeviceItem
{
    public string Title { get; init; } = "";
    public string Adapter { get; init; } = "";
    public string Status { get; init; } = "";
    public string Name { get; init; } = "";
    public string Id { get; init; } = "";
    public string SortKey { get; init; } = "3";
    public bool IsDefault { get; init; }
}

internal sealed class DeviceListBox : ListBox
{
    public DeviceListBox()
    {
        DrawMode = DrawMode.OwnerDrawFixed;
        ItemHeight = 48;
        IntegralHeight = false;
        BorderStyle = BorderStyle.None;
        BackColor = Color.FromArgb(28, 18, 12);
        ForeColor = Theme.Cream;
        Font = new Font("Segoe UI", 9.5f);
    }

    protected override void OnDrawItem(DrawItemEventArgs e)
    {
        if (e.Index < 0 || e.Index >= Items.Count) return;
        var item = (AudioDeviceItem)Items[e.Index];
        var selected = (e.State & DrawItemState.Selected) != 0;
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        var bg = selected ? Color.FromArgb(70, 44, 22) : Color.FromArgb(32, 20, 12);
        using (var b = new SolidBrush(bg))
            g.FillRectangle(b, e.Bounds);

        if (selected)
        {
            using var accent = new SolidBrush(Theme.Amber);
            g.FillRectangle(accent, e.Bounds.X, e.Bounds.Y + 6, 3, e.Bounds.Height - 12);
        }

        using var titleFont = new Font("Segoe UI", 10f, FontStyle.Bold);
        using var subFont = new Font("Segoe UI", 8.25f);
        var titleRect = new Rectangle(e.Bounds.X + 12, e.Bounds.Y + 6, e.Bounds.Width - 20, 20);
        var subRect = new Rectangle(e.Bounds.X + 12, e.Bounds.Y + 26, e.Bounds.Width - 20, 18);
        TextRenderer.DrawText(g, item.Title, titleFont, titleRect, Theme.Cream, TextFormatFlags.EndEllipsis);
        var subColor = selected ? Theme.Amber : Theme.Muted;
        TextRenderer.DrawText(g, $"{item.Adapter}  |  {item.Status}", subFont, subRect, subColor, TextFormatFlags.EndEllipsis);
    }
}

internal sealed class AudioConfigForm : ThemedForm
{
    readonly DeviceListBox _mics = new();
    readonly DeviceListBox _spks = new();
    readonly Button _btnPtt;
    readonly Label _lblPtt;
    readonly Button _btnOk;
    readonly string _outFile;

    int _pttVk;
    string _pttName = "";
    string _pttKind = "Keyboard";
    bool _waiting;

    public AudioConfigForm(string outFile)
        : base(new Size(740, 720))
    {
        _outFile = outFile;
        Text = "Configuration audio";
        HeaderTitle = "Micro, casque et Push-To-Talk";
        TopMost = true;
        RebuildBackdrop(new Rectangle(28, 88, Width - 56, Height - 140));

        Controls.Add(MakeSub("Choisis le même détail que Windows : nom + matériel + statut.", 40, 68, Width - 100, 24));

        var micLabel = SectionLabel("Microphone", 40, 104);
        var spkLabel = SectionLabel("Casque / sortie", 40, 318);
        var pttLabel = SectionLabel("Push-To-Talk", 40, 532);

        var micItems = AudioDevices.Get(capture: true);
        var spkItems = AudioDevices.Get(capture: false);
        foreach (var i in micItems) _mics.Items.Add(i);
        foreach (var i in spkItems) _spks.Items.Add(i);

        _mics.Location = new Point(40, 132);
        _mics.Size = new Size(Width - 80, 164);
        _spks.Location = new Point(40, 346);
        _spks.Size = new Size(Width - 80, 164);
        SelectPreferred(_mics, micItems, new[] { @"A50.*Chat", @"A50.*Mic", @"Microphone.*A50", @"A50 X" });
        SelectPreferred(_spks, spkItems, new[] { @"A50.*Voice", @"Casque pour t.+phone.*A50", @"A50.*Game" });

        _btnPtt = new Button
        {
            Location = new Point(40, 560),
            Size = new Size(Width - 80, 42),
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Georgia", 10f, FontStyle.Bold),
            ForeColor = Theme.Amber,
            BackColor = Color.FromArgb(55, 28, 18, 12),
            Text = "Cliquer ici, puis appuyer sur la touche Push-To-Talk",
            Cursor = Cursors.Hand
        };
        _btnPtt.FlatAppearance.BorderColor = Color.FromArgb(180, Theme.Amber);

        _lblPtt = new Label
        {
            Location = new Point(40, 610),
            Size = new Size(Width - 80, 24),
            Font = new Font("Segoe UI", 9.5f),
            ForeColor = Theme.Muted,
            BackColor = Color.Transparent,
            Text = "Aucune touche assignée"
        };

        _btnOk = MakeAccentButton("Continuer", Theme.Amber, Width - 300, Height - 68, 128, 42);
        var btnCancel = MakeGhostButton("Annuler", Width - 160, Height - 68, 120, 42);
        _btnOk.Enabled = false;

        _mics.SelectedIndexChanged += (_, _) => UpdateOk();
        _spks.SelectedIndexChanged += (_, _) => UpdateOk();
        _btnPtt.Click += (_, _) =>
        {
            _waiting = true;
            _btnPtt.Text = "En attente… appuie sur une touche ou un bouton souris";
            Cursor = Cursors.Cross;
            _btnPtt.Focus();
        };
        _btnOk.Click += (_, _) => SaveAndClose();
        btnCancel.Click += (_, _) => { DialogResult = DialogResult.Cancel; Close(); };

        KeyDown += OnKeyDownPtt;
        MouseDown += OnMousePtt;
        foreach (Control c in new Control[] { _mics, _spks, _btnPtt, _lblPtt, _btnOk, btnCancel })
            c.MouseDown += OnMousePtt;

        Controls.AddRange(new Control[] { micLabel, _mics, spkLabel, _spks, pttLabel, _btnPtt, _lblPtt, _btnOk, btnCancel });
        AcceptButton = _btnOk;
        CancelButton = btnCancel;
        foreach (Control c in Controls) c.BringToFront();
        if (Controls.OfType<ChromeButton>().FirstOrDefault() is { } close)
            close.BringToFront();
    }

    static Label SectionLabel(string text, int x, int y) => new()
    {
        Text = text,
        Location = new Point(x, y),
        AutoSize = true,
        Font = new Font("Georgia", 10f, FontStyle.Bold),
        ForeColor = Theme.Amber,
        BackColor = Color.Transparent
    };

    static void SelectPreferred(ListBox box, IReadOnlyList<AudioDeviceItem> items, string[] patterns)
    {
        foreach (var pattern in patterns)
        {
            for (var i = 0; i < items.Count; i++)
            {
                var hay = $"{items[i].Title} {items[i].Adapter} {items[i].Name}";
                if (System.Text.RegularExpressions.Regex.IsMatch(hay, pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase))
                {
                    box.SelectedIndex = i;
                    return;
                }
            }
        }
        if (box.Items.Count > 0) box.SelectedIndex = 0;
    }

    void UpdateOk() => _btnOk.Enabled = _mics.SelectedIndex >= 0 && _spks.SelectedIndex >= 0 && _pttVk > 0;

    void SetPtt(int vk, string name, string kind)
    {
        _pttVk = vk;
        _pttName = name;
        _pttKind = kind;
        _waiting = false;
        _lblPtt.Text = "Touche : " + name;
        _lblPtt.ForeColor = Theme.Amber;
        _btnPtt.Text = "Changer la touche Push-To-Talk";
        Cursor = Cursors.Default;
        UpdateOk();
    }

    void OnKeyDownPtt(object? sender, KeyEventArgs e)
    {
        if (!_waiting) return;
        if (e.KeyCode == Keys.Escape)
        {
            _waiting = false;
            _btnPtt.Text = "Cliquer ici, puis appuyer sur la touche Push-To-Talk";
            Cursor = Cursors.Default;
            return;
        }
        SetPtt((int)e.KeyCode, e.KeyCode.ToString(), "Keyboard");
        e.Handled = true;
    }

    void OnMousePtt(object? sender, MouseEventArgs e)
    {
        if (!_waiting) return;
        switch (e.Button)
        {
            case MouseButtons.Left: SetPtt(1, "Souris gauche", "MouseButton1"); break;
            case MouseButtons.Right: SetPtt(2, "Souris droite", "MouseButton2"); break;
            case MouseButtons.Middle: SetPtt(4, "Souris molette", "MouseButton3"); break;
            case MouseButtons.XButton1: SetPtt(5, "Souris latérale 4", "MouseButton4"); break;
            case MouseButtons.XButton2: SetPtt(6, "Souris latérale 5", "MouseButton5"); break;
        }
    }

    void SaveAndClose()
    {
        if (_mics.SelectedIndex < 0 || _spks.SelectedIndex < 0 || _pttVk <= 0) return;
        var mic = (AudioDeviceItem)_mics.SelectedItem!;
        var spk = (AudioDeviceItem)_spks.SelectedItem!;
        var ini = new StringBuilder();
        ini.AppendLine($"MicName={mic.Name}");
        ini.AppendLine($"MicId={mic.Id}");
        ini.AppendLine($"SpkName={spk.Name}");
        ini.AppendLine($"SpkId={spk.Id}");
        ini.AppendLine($"PttVk={_pttVk}");
        ini.AppendLine($"PttName={_pttName}");
        ini.AppendLine($"PttKind={_pttKind}");
        Directory.CreateDirectory(Path.GetDirectoryName(_outFile)!);
        File.WriteAllText(_outFile, ini.ToString(), new UTF8Encoding(false));
        DialogResult = DialogResult.OK;
        Close();
    }
}

internal static class AudioDevices
{
    public static List<AudioDeviceItem> Get(bool capture)
    {
        var flow = capture ? "Capture" : "Render";
        var list = new List<AudioDeviceItem>
        {
            new()
            {
                Title = "Par défaut (Windows)",
                Adapter = "Utilise le périphérique par défaut du système",
                Status = "Recommandé si tu ne sais pas",
                Name = "Par défaut (Windows)",
                Id = "",
                SortKey = "0",
                IsDefault = true
            }
        };

        string? defConsole = null, defComm = null;
        try
        {
            defConsole = NativeAudio.GetDefaultId(capture, 0);
            defComm = NativeAudio.GetDefaultId(capture, 2);
        }
        catch { }

        try
        {
            using var flowKey = Registry.LocalMachine.OpenSubKey($@"SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\{flow}");
            if (flowKey == null) return list;

            foreach (var guid in flowKey.GetSubKeyNames())
            {
                using var devKey = flowKey.OpenSubKey(guid);
                if (devKey == null) continue;
                var state = Convert.ToInt32(devKey.GetValue("DeviceState") ?? 0);
                if ((state & 1) != 1) continue;
                using var props = devKey.OpenSubKey("Properties");
                if (props == null) continue;

                var title = PropsString(props, "{a45c254e-df1c-4efd-8020-67d146a850e0},2");
                var adapter = PropsString(props, "{b3f8fa53-0004-438e-9003-51a46e139bfc},6") ?? "Périphérique audio";
                if (string.IsNullOrWhiteSpace(title)) continue;

                var wasapi = capture ? $"{{0.0.1.00000000}}.{guid}" : $"{{0.0.0.00000000}}.{guid}";
                var isDef = defConsole != null && defConsole.Contains(guid, StringComparison.OrdinalIgnoreCase);
                var isComm = defComm != null && defComm.Contains(guid, StringComparison.OrdinalIgnoreCase);
                var statusParts = new List<string>();
                if (isDef) statusParts.Add("Appareil par défaut");
                if (isComm) statusParts.Add("Appareil de communication par défaut");
                if (statusParts.Count == 0) statusParts.Add("Actif");

                list.Add(new AudioDeviceItem
                {
                    Title = title,
                    Adapter = adapter,
                    Status = string.Join(" | ", statusParts),
                    Name = $"{title} ({adapter})",
                    Id = wasapi,
                    SortKey = isDef ? "1" : isComm ? "2" : "3"
                });
            }
        }
        catch { }

        var first = list[0];
        var rest = list.Skip(1).OrderBy(x => x.SortKey).ThenBy(x => x.Title).ThenBy(x => x.Adapter).ToList();
        return new List<AudioDeviceItem> { first }.Concat(rest).ToList();
    }

    static string? PropsString(RegistryKey props, string name)
    {
        try
        {
            var v = props.GetValue(name);
            return v is string s && s.Trim().Length > 0 ? s : null;
        }
        catch { return null; }
    }
}

internal static class NativeAudio
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorCom { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        void NotImpl1();
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, out IntPtr ppInterface);
        [PreserveSig] int OpenPropertyStore(int stgmAccess, out IntPtr ppProperties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
    }

    public static string? GetDefaultId(bool capture, int role)
    {
        try
        {
            var en = (IMMDeviceEnumerator)(object)new MMDeviceEnumeratorCom();
            var hr = en.GetDefaultAudioEndpoint(capture ? 1 : 0, role, out var dev);
            if (hr != 0 || dev == null) return null;
            hr = dev.GetId(out var id);
            return hr == 0 ? id : null;
        }
        catch { return null; }
    }
}
