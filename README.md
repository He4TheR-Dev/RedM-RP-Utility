# RedM RP Utility

<p align="center">
  <img src="assets/hub-preview.png" alt="RedM RP Utility â€” interface principale" width="560"/>
</p>

**Stack:** C# Â· .NET 8 Â· WinForms

**Utilitaire Windows pour le vocal Roleplay RedM** â€” installe, configure et rÃ©pare **TeamSpeak 3 + SaltyChat**, applique un thÃ¨me Red Dead, et nettoie le cache RedM, le tout depuis une seule application.

---

## Ã€ quoi Ã§a sert ?

Sur RedM (GTA RP / RDR RP), le proximity chat passe souvent par **TeamSpeak + SaltyChat**.  
Lâ€™installation manuelle est longue : tÃ©lÃ©charger TeamSpeak, Ã©viter Overwolf, installer le plugin, rÃ©gler le micro, le casque, le Push-To-Talk, le thÃ¨me, etc.

**RedM RP Utility** automatise tout Ã§a :

| Besoin | Ce que fait le logiciel |
|---|---|
| Vocal RP prÃªt Ã  jouer | Installe TeamSpeak 3 **sans Overwolf** + SaltyChat + thÃ¨me |
| Config audio correcte | Assistant micro / casque / **Push-To-Talk** (pas le mode dÃ©tection de voix) |
| RedM qui rame / bugs cache | Nettoie les caches RedM **sans toucher** Ã  `game-storage` |
| Repartir de zÃ©ro | DÃ©sinstalle TeamSpeak, SaltyChat et Overwolf en un clic |
| Lancer TS rapidement | Bouton pour ouvrir TeamSpeak sâ€™il est installÃ© |

En rÃ©sumÃ© : **un hub simple pour prÃ©parer le vocal RP RedM**, sans galÃ©rer avec les installateurs et les rÃ©glages.

---

## FonctionnalitÃ©s

- **Installer / RÃ©parer** â€” TeamSpeak 3 + SaltyChat + thÃ¨me Red Dead
- **Nettoyer cache RedM** â€” Logs / Crashes / Data (conserve la sauvegarde `game-storage`)
- **DÃ©sinstaller tout** â€” TeamSpeak, SaltyChat, Overwolf (RedM nâ€™est pas touchÃ©)
- **Ouvrir TeamSpeak 3** â€” lance le client dÃ©tectÃ©
- Interface **borderless** style western / Red Dead
- Pas de fenÃªtre PowerShell visible pendant lâ€™installation

---

## Captures / aperÃ§u

<p align="center">
  <img src="assets/ts3-reddead-check.png" alt="TeamSpeak Red Dead theme" width="480"/>
</p>

---

## PrÃ©requis

- Windows **10 / 11** (64-bit)
- Droits utilisateur standard (pas besoin dâ€™admin dans le cas normal)
- RedM installÃ© si tu veux utiliser le nettoyage de cache

---

## Installation

### Option recommandÃ©e â€” Setup

1. TÃ©lÃ©charge la derniÃ¨re release : **[RedM-RP-Utility-Setup.exe](https://github.com/He4TheR-Dev/RedM-RP-Utility/releases/latest)**
2. Lance lâ€™installateur
3. Ouvre **RedM RP Utility** depuis le Bureau
4. Clique **Installer / RÃ©parer**
5. Choisis ton micro, ton casque et ta touche PTT
6. Attends la fin, puis ouvre TeamSpeak

### Option portable

1. Prends `RedMRpUtility.exe` **avec** le dossier `Assets`
2. Lance lâ€™exe  
   *(les redist / scripts doivent Ãªtre prÃ©sents comme aprÃ¨s une install Setup)*

---

## Utilisation

1. Lance **RedM RP Utility**
2. VÃ©rifie le statut en bas :
   - point vert â†’ TeamSpeak dÃ©tectÃ©
   - sinon â†’ utilise **Installer / RÃ©parer**
3. Utilise les cartes dâ€™action selon ton besoin

---

## DÃ©sinstallation

- **Retirer TeamSpeak / SaltyChat / Overwolf** â†’ bouton **DÃ©sinstaller tout** dans lâ€™app  
- **Retirer lâ€™utilitaire** â†’ ParamÃ¨tres Windows â†’ Applications â†’ *RedM RP Utility*

---

## Versions incluses

| Composant | Version |
|---|---|
| RedM RP Utility | 2.1.x |
| TeamSpeak 3 Client | 3.6.2 |
| SaltyChat | 4.1.0 |

---

## Structure du projet (source)

```
â”œâ”€â”€ hub/VocalRoleplay/     # App WinForms (.NET 8) â€” code C#
â”œâ”€â”€ installer/             # Inno Setup + scripts PowerShell + thÃ¨me
â”‚   â””â”€â”€ redist/            # SaltyChat, thÃ¨meâ€¦ (pas TeamSpeak3-Setup.exe â‰ˆ108 Mo)
â”œâ”€â”€ assets/                # Previews README
â”œâ”€â”€ LICENSE
â””â”€â”€ README.md
```

> Le setup public complet (avec TeamSpeak embarquÃ©) est sur **Releases**.  
> Pour rebuild local : place `TeamSpeak3-Setup.exe` dans `installer/redist/` (voir `installer/redist/README.md`).

### Build (dÃ©veloppement)

```bash
dotnet publish hub/VocalRoleplay/VocalRoleplay.csproj -c Release -r win-x64 --self-contained true -o hub/publish
# Puis compiler installer/setup.iss avec Inno Setup 6
```

---

## Avertissements

- Cet outil configure **ton** TeamSpeak / SaltyChat pour le roleplay. Il ne remplace pas les rÃ¨gles de ton serveur.
- Ferme TeamSpeak avant une install / rÃ©paration / dÃ©sinstallation si lâ€™app le demande.
- Le nettoyage RedM ne supprime **pas** `game-storage` (inventaire / progressions liÃ©es).

---

## Licence

**Copyright (c) 2026 HE4THER DEV (He4TheR-Dev)**

MIT â€” voir [LICENSE](LICENSE).

---

## CrÃ©dits

- TeamSpeak 3 â€” [TeamSpeak Systems](https://www.teamspeak.com/)
- SaltyChat â€” plugin vocal FiveM/RedM
- Interface, code & packaging â€” Copyright (c) 2026 [HE4THER DEV](https://github.com/He4TheR-Dev)
