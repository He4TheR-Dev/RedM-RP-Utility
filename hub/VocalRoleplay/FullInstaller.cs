using System.Diagnostics;
using System.Text;

namespace RedMRpUtility;

internal static class FullInstaller
{
    public sealed class InstallResult
    {
        public bool Ok { get; init; }
        public string Message { get; init; } = "";
    }

    public static string AppRoot => AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    public static string ToolsDir => Path.Combine(AppRoot, "tools");
    public static string RedistDir => Path.Combine(AppRoot, "redist");

    public static bool DependenciesPresent()
    {
        return File.Exists(Path.Combine(RedistDir, "TeamSpeak3-Setup.exe"))
               && File.Exists(Path.Combine(RedistDir, "SaltyChat.zip"))
               && File.Exists(Path.Combine(ToolsDir, "install-ts3.ps1"))
               && File.Exists(Path.Combine(ToolsDir, "payload.ps1"));
    }

    /// <param name="skipAudioUi">Si true, utilise audio-config.ini déjà généré (UI native C#).</param>
    public static InstallResult Run(IProgress<string>? progress = null, bool skipAudioUi = false)
    {
        void P(string m) => progress?.Report(m);

        if (!DependenciesPresent())
        {
            return new InstallResult
            {
                Ok = false,
                Message = "Dependances manquantes. Relance RedM-RP-Utility-Setup.exe."
            };
        }

        Directory.CreateDirectory(Paths.LogDir);
        var log = Path.Combine(Paths.LogDir, "install.log");
        var config = Path.Combine(Paths.LogDir, "audio-config.ini");
        var tsSetup = Path.Combine(RedistDir, "TeamSpeak3-Setup.exe");
        var plugin = Path.Combine(RedistDir, "SaltyChat.zip");
        var sqlite = Path.Combine(RedistDir, "sqlite-tools.zip");
        var theme = Path.Combine(RedistDir, "RedDeadTheme.zip");

        try
        {
            if (skipAudioUi)
            {
                if (!File.Exists(config))
                    return Fail(log, "Configuration audio manquante.");
                P("Configuration audio prete.");
            }
            else
            {
                P("Configuration micro / casque / PTT...");
                var audioScript = Path.Combine(ToolsDir, "audio-config.ps1");
                if (!File.Exists(audioScript))
                    return Fail(log, "Script audio-config.ps1 manquant.");
                var audioCode = RunPowerShell(audioScript, new Dictionary<string, string>
                {
                    ["OutFile"] = config
                }, sta: true);
                if (audioCode != 0 && !File.Exists(config))
                    return Fail(log, "Configuration audio annulee ou echouee.");
            }

            P("Installation de TeamSpeak 3 (sans Overwolf)...");
            var tsCode = RunPowerShell(Path.Combine(ToolsDir, "install-ts3.ps1"), new Dictionary<string, string>
            {
                ["SetupFile"] = tsSetup
            }, sta: true);
            if (tsCode != 0)
                return Fail(log, $"Echec installation TeamSpeak (code {tsCode}). Voir install.log.");

            if (Paths.FindTs3() == null)
                return Fail(log, "TeamSpeak 3 introuvable apres installation.");

            P("Installation SaltyChat, theme et prereglages...");
            var payloadArgs = new Dictionary<string, string>
            {
                ["PluginZip"] = plugin,
                ["SqliteZip"] = sqlite,
                ["ThemeZip"] = theme,
                ["LogPath"] = log
            };
            if (File.Exists(config))
                payloadArgs["ConfigFile"] = config;

            var payloadCode = RunPowerShell(Path.Combine(ToolsDir, "payload.ps1"), payloadArgs, sta: true);
            if (payloadCode != 0)
                return Fail(log, $"Echec SaltyChat / theme (code {payloadCode}). Voir install.log.");

            P("Termine.");
            File.AppendAllText(log, $"{DateTime.Now:HH:mm:ss} OK{Environment.NewLine}");
            return new InstallResult
            {
                Ok = true,
                Message = "Installation terminee : TeamSpeak 3, SaltyChat et theme Red Dead sont prets."
            };
        }
        catch (Exception ex)
        {
            File.AppendAllText(log, $"{DateTime.Now:HH:mm:ss} EXCEPTION {ex}{Environment.NewLine}");
            return new InstallResult { Ok = false, Message = "Erreur : " + ex.Message };
        }
    }

    static InstallResult Fail(string log, string message)
    {
        File.AppendAllText(log, $"{DateTime.Now:HH:mm:ss} FAIL {message}{Environment.NewLine}");
        return new InstallResult { Ok = false, Message = message };
    }

    /// <summary>
    /// Lance un script PowerShell sans fenetre console (les dialogues WinForms restent visibles).
    /// Prefere run-hidden.vbs (WindowStyle 0) pour eviter le flash barre des taches.
    /// </summary>
    static int RunPowerShell(string script, Dictionary<string, string> namedArgs, bool sta)
    {
        var psArgs = new List<string>
        {
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden"
        };
        if (sta) psArgs.Add("-STA");
        psArgs.Add("-File");
        psArgs.Add(script);
        foreach (var kv in namedArgs)
        {
            psArgs.Add("-" + kv.Key);
            psArgs.Add(kv.Value);
        }

        var hiddenVbs = Path.Combine(ToolsDir, "run-hidden.vbs");
        ProcessStartInfo psi;
        if (File.Exists(hiddenVbs))
        {
            var quoted = new StringBuilder();
            quoted.Append("//B //nologo \"").Append(hiddenVbs).Append("\" powershell.exe");
            foreach (var a in psArgs)
                quoted.Append(' ').Append(QuoteArg(a));

            psi = new ProcessStartInfo
            {
                FileName = "wscript.exe",
                Arguments = quoted.ToString(),
                WorkingDirectory = ToolsDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
        }
        else
        {
            psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = string.Join(" ", psArgs.Select(QuoteArg)),
                WorkingDirectory = ToolsDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
        }

        using var p = Process.Start(psi) ?? throw new InvalidOperationException("Impossible de lancer PowerShell.");
        p.WaitForExit();
        return p.ExitCode;
    }

    static string QuoteArg(string value)
    {
        if (string.IsNullOrEmpty(value)) return "\"\"";
        if (value.IndexOfAny(new[] { ' ', '\t', '"' }) < 0) return value;
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
