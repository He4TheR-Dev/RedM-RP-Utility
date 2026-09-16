using System.Diagnostics;

namespace RedMRpUtility;

internal static class Theme
{
    public static readonly Color Bg = Color.FromArgb(10, 7, 5);
    public static readonly Color BgPanel = Color.FromArgb(20, 14, 10);
    public static readonly Color BgCard = Color.FromArgb(28, 18, 12);
    public static readonly Color BgCardHover = Color.FromArgb(40, 26, 16);
    public static readonly Color Gold = Color.FromArgb(227, 169, 43);
    public static readonly Color GoldDim = Color.FromArgb(160, 120, 50);
    public static readonly Color Amber = Color.FromArgb(227, 169, 43);
    public static readonly Color Rust = Color.FromArgb(197, 69, 37);
    public static readonly Color Crimson = Color.FromArgb(168, 43, 34);
    public static readonly Color Steel = Color.FromArgb(74, 145, 199);
    public static readonly Color Cream = Color.FromArgb(243, 230, 200);
    public static readonly Color Subtitle = Color.FromArgb(198, 164, 122);
    public static readonly Color Muted = Color.FromArgb(160, 135, 105);
    public static readonly Color Danger = Color.FromArgb(170, 55, 40);
    public static readonly Color Ok = Color.FromArgb(90, 160, 90);
    public static readonly Color Border = Color.FromArgb(110, 80, 45);
}

internal static class Paths
{
    public static string AppDataHub =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RedMRpUtility");

    public static string LogDir
    {
        get
        {
            Directory.CreateDirectory(AppDataHub);
            return AppDataHub;
        }
    }

    public static IEnumerable<string> Ts3Candidates()
    {
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "TeamSpeak 3 Client", "ts3client_win64.exe");
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "TeamSpeak 3 Client", "ts3client_win64.exe");
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            "TeamSpeak 3 Client", "ts3client_win64.exe");
    }

    public static string? FindTs3() => Ts3Candidates().FirstOrDefault(File.Exists);

    public static string? FindSetupExe(string? appDir = null)
    {
        const string name = "TeamSpeak-SaltyChat-Setup.exe";
        var roots = new List<string>();
        if (!string.IsNullOrWhiteSpace(appDir)) roots.Add(appDir);
        roots.Add(AppContext.BaseDirectory);
        roots.Add(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
        roots.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"));
        roots.Add(FullInstaller.AppRoot);
        roots.Add(Path.Combine(FullInstaller.AppRoot, "redist"));

        foreach (var root in roots.Where(Directory.Exists).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var direct = Path.Combine(root, name);
            if (File.Exists(direct)) return direct;
            try
            {
                var hit = Directory.EnumerateFiles(root, name, SearchOption.AllDirectories).Take(8).FirstOrDefault();
                if (hit != null) return hit;
            }
            catch { /* ignore ACL */ }
        }
        return null;
    }
}

internal static class RedMCleaner
{
    public sealed class Result
    {
        public bool FoundRoot { get; init; }
        public bool Cleaned { get; init; }
        public long BytesFreed { get; init; }
        public double MegabytesFreed => Math.Round(BytesFreed / (1024.0 * 1024.0), 1);
        public string Message { get; init; } = "";
    }

    public static Result Run(Action<string>? log = null)
    {
        void L(string m) { log?.Invoke(m); File.AppendAllText(Path.Combine(Paths.LogDir, "clean-redm.log"),
            $"{DateTime.Now:HH:mm:ss} {m}{Environment.NewLine}"); }

        L("==== clean-redm ====");
        KillRedM();
        Thread.Sleep(700);

        var roots = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RedM", "RedM.app"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RedM Application Data"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RedM", "Application Data"),
        };

        long before = 0, after = 0;
        var cleaned = false;
        var found = false;

        foreach (var root in roots.Where(Directory.Exists))
        {
            found = true;
            L($"RedM root {root}");
            before += DirSize(root);

            foreach (var name in new[] { "logs", "Logs", "crashes", "Crashes" })
            {
                var p = Path.Combine(root, name);
                if (!Directory.Exists(p)) continue;
                L($"Supprime {p}");
                TryDelete(p);
                cleaned = true;
            }

            var data = Directory.Exists(Path.Combine(root, "data")) ? Path.Combine(root, "data")
                : Directory.Exists(Path.Combine(root, "Data")) ? Path.Combine(root, "Data") : null;
            if (data == null)
            {
                after += DirSize(root);
                continue;
            }

            foreach (var entry in Directory.EnumerateFileSystemEntries(data))
            {
                var name = Path.GetFileName(entry);
                if (name.Equals("game-storage", StringComparison.OrdinalIgnoreCase))
                {
                    L($"Conserve {entry}");
                    continue;
                }
                L($"Supprime {entry}");
                TryDelete(entry);
                cleaned = true;
            }
            after += DirSize(root);
        }

        var freed = Math.Max(0, before - after);
        var result = new Result
        {
            FoundRoot = found,
            Cleaned = cleaned,
            BytesFreed = freed,
            Message = !found ? "RedM n'est pas installe sur ce PC."
                : !cleaned ? "Cache deja propre. game-storage intact."
                : $"Termine. Environ {Math.Round(freed / (1024.0 * 1024.0), 1)} Mo liberes. game-storage conserve."
        };
        L(result.Message);
        L("OK");
        return result;
    }

    static void KillRedM()
    {
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                var n = p.ProcessName;
                if (n.StartsWith("TeamSpeak-SaltyChat-Setup", StringComparison.OrdinalIgnoreCase)) continue;
                if (n.StartsWith("RedM", StringComparison.OrdinalIgnoreCase)
                    || n.StartsWith("CitizenFX", StringComparison.OrdinalIgnoreCase)
                    || n is "FiveM" or "GTAProcess" or "RageGame"
                    || (p.MainWindowTitle?.Contains("RedM", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    p.Kill(entireProcessTree: true);
                }
            }
            catch { }
            finally { p.Dispose(); }
        }
    }

    static long DirSize(string path)
    {
        try
        {
            return new DirectoryInfo(path).EnumerateFiles("*", SearchOption.AllDirectories).Sum(f => f.Length);
        }
        catch { return 0; }
    }

    static void TryDelete(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, true);
            else if (File.Exists(path)) File.Delete(path);
        }
        catch { }
    }
}
