#define MyAppName "RedM RP Utility"
#define MyAppVersion "2.1.1"
#define MyAppPublisher "RedM RP Utility"

[Setup]
AppId={{8C3E6B21-9A44-4F2C-9D7A-B1E5C8A0F314}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\RedMRpUtility
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
WizardStyle=modern dark
WizardSizePercent=120
SetupIconFile=setup-icon.ico
UninstallDisplayIcon={app}\app.ico
WizardImageFile=wizard-side.png
WizardSmallImageFile=wizard-small.png
WizardBackColor=#140C08
WizardImageBackColor=#140C08
WizardSmallImageBackColor=#140C08
Compression=lzma2
SolidCompression=no
OutputDir=..
OutputBaseFilename=RedM-RP-Utility-Setup
SetupLogging=yes
Uninstallable=yes
CloseApplications=no
RestartIfNeededByRun=no
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[LangOptions]
DialogFontName=Georgia
DialogFontSize=10
WelcomeFontName=Georgia
WelcomeFontSize=16

[Messages]
SetupWindowTitle=RedM RP Utility
WelcomeLabel1=RedM RP Utility
WelcomeLabel2=Cet assistant installe l'application et toutes les dependances (TeamSpeak 3, SaltyChat, theme, outils).%n%nEnsuite, tout se fait depuis l'app : installer, nettoyer le cache RedM, desinstaller ou ouvrir TeamSpeak.
FinishedHeadingLabel=Installation terminee
FinishedLabelNoIcons=RedM RP Utility est pret.%n%nOuvre l'app sur le Bureau pour installer TeamSpeak + SaltyChat, vider le cache RedM, ou tout desinstaller.

[Files]
Source: "..\hub\publish\RedMRpUtility.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\hub\publish\Assets\*"; DestDir: "{app}\Assets"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "redist\TeamSpeak3-Setup.exe"; DestDir: "{app}\redist"; Flags: ignoreversion
Source: "redist\SaltyChat.zip"; DestDir: "{app}\redist"; Flags: ignoreversion
Source: "redist\sqlite-tools.zip"; DestDir: "{app}\redist"; Flags: ignoreversion
Source: "redist\RedDeadTheme.zip"; DestDir: "{app}\redist"; Flags: ignoreversion
Source: "install-ts3.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "payload.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "audio-config.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "preflight.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "clean-redm.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "ui-auto.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "run-hidden.vbs"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "installed.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userdesktop}\RedM RP Utility"; Filename: "{app}\RedMRpUtility.exe"; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Comment: "Installer TeamSpeak, nettoyer cache RedM, desinstaller"
Name: "{userstartmenu}\RedM RP Utility"; Filename: "{app}\RedMRpUtility.exe"; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Comment: "Installer TeamSpeak, nettoyer cache RedM, desinstaller"

[Run]
Filename: "{app}\RedMRpUtility.exe"; Description: "Ouvrir RedM RP Utility"; Flags: nowait postinstall skipifsilent
