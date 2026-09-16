# RedM RP Utility

<p align="center">
  <img src="assets/hub-preview.png" alt="RedM RP Utility main UI" width="560"/>
</p>

**Stack:** C# · .NET 8 · WinForms

**Windows utility for RedM roleplay voice chat** — installs, configures, and repairs **TeamSpeak 3 + SaltyChat**, applies a Red Dead theme, and cleans the RedM cache, all from one app.

---

## What is it for?

On RedM, proximity chat often goes through **TeamSpeak + SaltyChat**.  
Manual setup is slow: download TeamSpeak, avoid Overwolf, install the plugin, set mic / headset / Push-To-Talk, theme, and more.

**RedM RP Utility** automates that:

| Need | What the software does |
|---|---|
| RP voice ready to play | Installs TeamSpeak 3 **without Overwolf** + SaltyChat + theme |
| Correct audio config | Mic / headset / **Push-To-Talk** wizard (not voice activation) |
| RedM lag / cache bugs | Cleans RedM caches **without touching** `game-storage` |
| Fresh start | Uninstalls TeamSpeak, SaltyChat, and Overwolf in one click |
| Quick launch | Button to open TeamSpeak if installed |

In short: **a simple hub to prepare RedM RP voice**, without fighting installers and settings.

---

## Features

- **Install / Repair** — TeamSpeak 3 + SaltyChat + Red Dead theme
- **Clean RedM cache** — Logs / Crashes / Data (keeps `game-storage`)
- **Uninstall all** — TeamSpeak, SaltyChat, Overwolf (RedM is left alone)
- **Open TeamSpeak 3** — launches the detected client
- **Borderless** western / Red Dead style UI
- No visible PowerShell window during install

---

## Screenshots

<p align="center">
  <img src="assets/ts3-reddead-check.png" alt="TeamSpeak Red Dead theme" width="480"/>
</p>

---

## Requirements

- Windows **10 / 11** (64-bit)
- Standard user rights (admin usually not required)
- RedM installed if you want cache cleaning

---

## Installation

### Recommended — Setup

1. Download the latest release: **[RedM-RP-Utility-Setup.exe](https://github.com/He4TheR-Dev/RedM-RP-Utility/releases/latest)**
2. Run the installer
3. Open **RedM RP Utility** from the Desktop
4. Click **Install / Repair**
5. Choose your mic, headset, and PTT key
6. Wait until it finishes, then open TeamSpeak

### Portable option

1. Take `RedMRpUtility.exe` **with** the `Assets` folder
2. Run the exe  
   *(redistributables / scripts must be present as after a Setup install)*

---

## Usage

1. Launch **RedM RP Utility**
2. Check the status bar:
   - green dot → TeamSpeak detected
   - otherwise → use **Install / Repair**
3. Use the action cards as needed

---

## Uninstall

- **Remove TeamSpeak / SaltyChat / Overwolf** → **Uninstall all** button in the app  
- **Remove the utility** → Windows Settings → Apps → *RedM RP Utility*

---

## Included versions

| Component | Version |
|---|---|
| RedM RP Utility | 2.1.x |
| TeamSpeak 3 Client | 3.6.2 |
| SaltyChat | 4.1.0 |

---

## Project structure (source)

```
├── hub/VocalRoleplay/     # WinForms app (.NET 8) — C# code
├── installer/             # Inno Setup + PowerShell scripts + theme
│   └── redist/            # SaltyChat, theme… (not TeamSpeak3-Setup.exe ≈108 MB)
├── assets/                # README previews
├── LICENSE
└── README.md
```

> The full public setup (with TeamSpeak embedded) is on **Releases**.  
> For a local rebuild: place `TeamSpeak3-Setup.exe` in `installer/redist/` (see `installer/redist/README.md`).

### Development build

```bash
dotnet publish hub/VocalRoleplay/VocalRoleplay.csproj -c Release -r win-x64 --self-contained true -o hub/publish
# Then compile installer/setup.iss with Inno Setup 6
```

---

## Warnings

- This tool configures **your** TeamSpeak / SaltyChat for roleplay. It does not replace your server rules.
- Close TeamSpeak before install / repair / uninstall if the app asks you to.
- RedM cleanup does **not** delete `game-storage` (inventory / related progress).

---

## License

**Copyright (c) 2026 HE4THER DEV (He4TheR-Dev)**

MIT — see [LICENSE](LICENSE).

---

## Credits

- TeamSpeak 3 — [TeamSpeak Systems](https://www.teamspeak.com/)
- SaltyChat — FiveM/RedM voice plugin
- UI, code & packaging — Copyright (c) 2026 [HE4THER DEV](https://github.com/He4TheR-Dev)
