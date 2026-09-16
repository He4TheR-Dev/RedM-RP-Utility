using System.Diagnostics;

namespace RedMRpUtility;

internal static class Uninstaller
{
    public static string Run()
    {
        var log = Path.Combine(Paths.LogDir, "uninstall.log");
        void L(string m) => File.AppendAllText(log, $"{DateTime.Now:HH:mm:ss} {m}{Environment.NewLine}");

        L("==== uninstall ====");
        KillMatching(p =>
        {
            var n = p.ProcessName;
            if (n.StartsWith("RedMRpUtility", StringComparison.OrdinalIgnoreCase)) return false;
            if (n.StartsWith("VocalRoleplay", StringComparison.OrdinalIgnoreCase)) return false;
            if (n.StartsWith("TeamSpeak-SaltyChat-Setup", StringComparison.OrdinalIgnoreCase)) return false;
            return n.StartsWith("ts3client", StringComparison.OrdinalIgnoreCase)
                   || n.Equals("TeamSpeak", StringComparison.OrdinalIgnoreCase)
                   || n.StartsWith("Overwolf", StringComparison.OrdinalIgnoreCase)
                   || n.StartsWith("OWInstaller", StringComparison.OrdinalIgnoreCase)
                   || n.StartsWith("package_inst", StringComparison.OrdinalIgnoreCase);
        });

        var uninstallers = new[]
        {
            Path.Combine(Paths.AppDataHub, "unins000.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "TeamSpeakSaltyChatSetup", "unins000.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs", "TeamSpeak 3 Client", "uninstall.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "TeamSpeak 3 Client", "uninstall.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
                "TeamSpeak 3 Client", "uninstall.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Overwolf", "OWUninstaller.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Overwolf", "OWUninstaller.exe"),
        };

        foreach (var u in uninstallers.Where(File.Exists))
        {
            L($"Desinstall {u}");
            try
            {
                var args = u.Contains("unins000", StringComparison.OrdinalIgnoreCase) ? "/SILENT /NORESTART" : "/S";
                using var proc = Process.Start(new ProcessStartInfo(u, args)
                {
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                });
                proc?.WaitForExit(120_000);
            }
            catch (Exception ex) { L($"echec: {ex.Message}"); }
        }

        KillMatching(p =>
        {
            var n = p.ProcessName;
            if (n.StartsWith("RedMRpUtility", StringComparison.OrdinalIgnoreCase)) return false;
            if (n.StartsWith("VocalRoleplay", StringComparison.OrdinalIgnoreCase)) return false;
            return n.StartsWith("ts3client", StringComparison.OrdinalIgnoreCase)
                   || n.Equals("TeamSpeak", StringComparison.OrdinalIgnoreCase)
                   || n.StartsWith("Overwolf", StringComparison.OrdinalIgnoreCase)
                   || n.StartsWith("OWInstaller", StringComparison.OrdinalIgnoreCase);
        });
        Thread.Sleep(600);

        var wipe = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TS3Client"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "TeamSpeak 3 Client"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Overwolf"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Overwolf"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "TeamSpeak 3 Client"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "TeamSpeak 3 Client"),
        };

        foreach (var p in wipe.Where(Directory.Exists))
        {
            L($"Supprime {p}");
            try { Directory.Delete(p, true); } catch { }
        }

        try
        {
            var desk = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            foreach (var lnk in Directory.EnumerateFiles(desk, "TeamSpeak*.lnk"))
            {
                var fn = Path.GetFileName(lnk);
                if (fn.Contains("SaltyChat-Setup", StringComparison.OrdinalIgnoreCase)) continue;
                if (fn.Contains("Vocal Roleplay", StringComparison.OrdinalIgnoreCase)) continue;
                if (fn.Contains("RedM RP Utility", StringComparison.OrdinalIgnoreCase)) continue;
                File.Delete(lnk);
            }
        }
        catch { }

        L("OK");
        return "Desinstallation terminee. RedM n'a pas ete touche.";
    }

    static void KillMatching(Func<Process, bool> match)
    {
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                if (match(p)) p.Kill(entireProcessTree: true);
            }
            catch { }
            finally { p.Dispose(); }
        }
    }
}
