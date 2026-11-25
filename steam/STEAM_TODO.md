# Releasing Sand Rover on Steam

What's done in the project, and the steps that only you can do (they need
your Steamworks account). Work down the list.

## Already done in the game

- Full controller support (Xbox / PlayStation / Switch / Steam Deck), with
  prompts that switch between keyboard and controller automatically.
- Title menu (Continue / New Game / Options / Credits / Quit), pause menu,
  Options saved to `settings.cfg`, credits with the Godot licence notices.
- Borderless fullscreen by default, UI that scales to any screen (16:10 for
  Steam Deck), lighter defaults on a 1280 x 800 screen.
- Safe saving (write to a temp file, then swap), autosave on delivery, pause,
  quit, alt-tab and controller disconnect. Pauses when the window loses focus
  (Steam overlay, Steam Deck suspend).
- 15 achievements tracked in the game (`scripts/achievements.gd`), sent to
  Steam when Steam is running.
- Windows and Linux export presets; both export and run (tested on Linux).

## 1. Steamworks account (you)

1. Sign up at partner.steamgames.com, pay the app fee (US$100 per game,
   recoupable after US$1,000 of sales), and fill in the tax and bank forms.
2. Create the app. Note the **App ID** and the two **depot IDs** (Windows,
   Linux) under SteamPipe > Depots.

## 2. Steam features in the game

1. Install **GodotSteam** (GDExtension version) for Godot 4.7 from the Godot
   Asset Library (AssetLib tab, search "GodotSteam") or godotsteam.com. It
   includes the Steam API libraries: `steam_api64.dll` (Windows) and
   `libsteam_api.so` (Linux) must sit next to the exported game.
2. Nothing else to code: `scripts/steam_service.gd` finds GodotSteam
   automatically and `scripts/achievements.gd` already calls it.
3. To test outside Steam, copy `steam/steam_appid.txt.example` to
   `steam_appid.txt` next to the game (put YOUR App ID in it; 480 is Valve's
   test app). **Never ship it** (the depot scripts exclude it).

## 3. Achievements (partner site > Stats & Achievements)

Enter the 15 rows of `steam/achievements/achievements.csv`. The API names
must match exactly. Icons (256 x 256, achieved and locked) are in
`steam/achievements/icons/`; they're placeholders made from game shots, so
replace them with your own art if you like. Publish the changes.

## 4. Steam Cloud (partner site > Cloud > Auto-Cloud)

Byte quota 50 MB, files 200. Root paths:

| OS | Root | Subdirectory | Pattern |
|---|---|---|---|
| Windows | WinAppDataRoaming | `SandRover` | `save.json`, `achievements.json`, `settings.cfg`, `builds/*.json` |
| Linux | LinuxXdgDataHome | `SandRover` | same |

Don't sync `tile_cache/` (23 MB the game rebuilds by itself) or `logs/`.

## 5. Store page

- Text and tags: `steam/store/store_page.md`.
- Images: `steam/store/capsules/` has placeholders at every required size
  (made from game renders with plain title text by
  `steam/make_store_images.py`: re-run it after art changes). Valve reviews these: the logo must be
  readable on the small capsule. Replace them with a designed logo when you
  can; it's the single most important piece of marketing.
- Screenshots: `steam/store/screenshots/` (1920 x 1080). Steam needs at least
  5. Real gameplay shots are better: press **F12** in the game (saved to the
  `screenshots` folder next to your save), or use Steam's screenshot key.
- Fill in the content survey (mild fantasy violence: creatures knock the
  truck over) and the system requirements (below).

**System requirements (suggested; check on your own PCs):**

| | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit / Ubuntu 22.04 | Windows 11 |
| CPU | 4 cores, 2.5 GHz | 6 cores, 3.5 GHz |
| RAM | 4 GB | 8 GB |
| GPU | Vulkan 1.1: GTX 960 / RX 470 / Intel Iris Xe | GTX 1660 / RX 6600 |
| Storage | 500 MB | 500 MB |

## 6. Upload a build (SteamPipe)

1. In Godot: Project > Export > Export All (makes `build/windows` and
   `build/linux`). For the Windows icon and version info, get **rcedit**
   (github.com/electron/rcedit), set its path in Editor Settings > Export >
   Windows, and tick "Modify Resources" in the Windows preset.
2. Copy the GodotSteam libraries next to each executable.
3. Put your App ID and depot IDs into `steam/build/*.vdf`.
4. Run SteamCMD (from the Steamworks SDK):
   `steamcmd +login YOUR_LOGIN +run_app_build <path>/steam/build/app_build.vdf +quit`
5. On the partner site, set the build live on a beta branch first, install
   it through Steam, and play it. Then set it live on `default`.

## 7. Steam Deck

Request a Deck compatibility review once the build is up. Things the
reviewers check that are already handled: controller-only play everywhere
(workshop included), readable text at 1280 x 800, no launcher, pad prompts,
pauses on suspend. Check yourself: frame rate on the Deck at the default
(Medium, 80% resolution), and that the default controller layout is set to
"Gamepad" in Steamworks > Steam Input.

## 8. Before you press Release

- Play the whole story on the release build, with a controller.
- Put your name (and any bought assets' credits) in `scripts/credits_page.gd`.
- Bump `config/version` in `project.godot` and the Windows preset's file
  version for every update.
- Coming-soon page: Steam needs it live at least 2 weeks before release.
