#define MyAppName "Nettoyer Cache RedM"
#define MyAppVersion "1.0.0"

[Setup]
AppId={{B7E2C914-5F31-4A8E-9C2D-1E6A0F8B4D73}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={localappdata}\TeamSpeakSaltyChatSetup
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
WizardStyle=modern dark
SetupIconFile=clean-redm.ico
UninstallDisplayIcon={app}\clean-redm.ico
Compression=lzma2
SolidCompression=no
OutputDir=..
OutputBaseFilename=Nettoyer-Cache-RedM
SetupLogging=yes
Uninstallable=yes
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Messages]
SetupWindowTitle=Nettoyer Cache RedM
WelcomeLabel1=Cache RedM
WelcomeLabel2=Cet outil installe un raccourci pour vider Logs, Crashes et Data RedM en un clic.%n%nLe dossier game-storage n'est jamais touche. Pas besoin de reinstaller TeamSpeak.

[Files]
Source: "clean-redm.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "clean-redm-ui.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch-clean-redm.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "clean-redm.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userdesktop}\Nettoyer Cache RedM"; Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\launch-clean-redm.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\clean-redm.ico"; Comment: "Vide le cache RedM (conserve game-storage)"
Name: "{userstartmenu}\Nettoyer Cache RedM"; Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\launch-clean-redm.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\clean-redm.ico"; Comment: "Vide le cache RedM (conserve game-storage)"

[Run]
Filename: "{sys}\wscript.exe"; Parameters: "//nologo ""{app}\launch-clean-redm.vbs"""; Description: "Lancer le nettoyeur maintenant"; Flags: nowait postinstall skipifsilent
