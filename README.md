# Capy Tower Wars

A short portrait game about capybara soldiers and towers. Drag from one of your towers to another and a stream of soldiers walks the line. Swipe that line to cut it. Take every red tower to win.

It is a Godot 4.7 project (GDScript), built for a phone held upright. On a desktop, the mouse stands in for touch.

## Play it in Godot on a Mac

1. Install **Godot 4.7.2** (the standard build, not the .NET build) from [godotengine.org](https://godotengine.org/download/macos/). The project was made with 4.7.2. Another 4.7.x editor can open it; a different major version will ask to upgrade the project.
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** or the Play button. The window is a tall 540×960 preview of the 1080×1920 portrait game.
4. On the title screen, pick Easy, Normal, or Hard, then **Play**.
5. Drag from a blue tower onto any other tower. Soldiers start walking that line. Swipe across one of **your** lines (start the swipe on empty meadow, not on your tower) to cut it.
6. **Restart** is in the match. After a win or a loss, **Play again** reloads Mirror Meadow and **Menu** returns to the title.

The first level is **Mirror Meadow** (`data/levels/level_01.json`): two blue towers at the bottom, two red towers at the top, and three unclaimed towers between them. The layout is symmetrical. Blue starts closer to the side dens.

## Check that the level is winnable

A headless script checks the rules and plays Mirror Meadow with a simple scripted herd against the bot:

```bash
godot --headless --path . -s res://tools/simulate_level.gd
```

Use the same Godot 4.7 binary you edit with. Exit code 0 means every check passed, including a Normal win. The script also prints Easy and Hard. On the seeds it tries, that scripted herd wins all three in about half a minute. It is a probe, not the opponent you play against.

`tools/smoke_scene.gd` loads the title, starts a match, and runs a few seconds of frames. That only checks that the scene boots.

## Export an Android APK and run it in the emulator

The repo already contains an Android export preset named **Android**. It builds a portrait APK, package `com.capytowerwars.game`, with `arm64-v8a` (phones) and `x86_64` (the Android Studio emulator) enabled. Debug signing is left blank on purpose: a debug export uses Godot's built-in debug keystore.

Godot 4.7 exports Android from the prebuilt export templates. You do not need a Gradle build for this prototype.

### One-time setup on a Mac

1. Install **Temurin JDK 17** from [adoptium.net](https://adoptium.net/temurin/releases/?variant=openjdk17&version=17&os=any&arch=any).
2. Install [Android Studio](https://developer.android.com/studio/) and, in the SDK Manager, install:
   - Android SDK Platform 35
   - Android SDK Platform-Tools 35 or newer
   - Android SDK Build-Tools 35.0.1
   - NDK 28.1.13356709
   - CMake 3.10.2.4988404
   - Android SDK Command-line Tools
3. In Godot, open **Editor → Manage Export Templates** and install the templates that match your editor version (4.7.2 templates for the 4.7.2 editor).
4. Open **Godot → Editor Settings → Export → Android** and set:
   - **Java SDK Path** to the JDK 17 home
   - **Android SDK Path** to `~/Library/Android/sdk` (the folder that contains `platform-tools/adb`)

### Export the APK

1. **Project → Export…**
2. Select the **Android** preset.
3. Leave **Export With Debug** checked for emulator installs.
4. Export to `build/CapyTowerWars.apk` (or any path you like).

### Run it in the Android Studio emulator

1. Android Studio → **Device Manager** → **Create Device**.
2. Pick a phone, for example Pixel 6.
3. Pick a system image for API 35. Use an **arm64** image or an **x86_64** image. Both ABIs are in the preset. Finish and start the emulator.
4. Wait until the emulator is fully booted, then install the APK:

```bash
~/Library/Android/sdk/platform-tools/adb install -r build/CapyTowerWars.apk
```

5. Open **Capy Tower Wars** in the emulator's app list.

If a debug export says the package is already installed with a different signature, uninstall the old copy from the emulator and install again. If Godot lists the running emulator under Remote Deploy, the Play button in the export dialog can install it for you as well.

iOS is not set up. The project is already portrait (`display/window/handheld/orientation`) and touch-driven, which is the part an iOS export would reuse later.

## Rules the match actually uses

These are the owner's rules, plus the choices made where the rules did not specify a number.

- Each outgoing link sends **one soldier per second** (`SEND_INTERVAL = 1.0`). The first soldier steps off as soon as the link is made, then one follows every second. Sending does **not** lower the source count.
- Soldiers walk at 200 pixels per second on the playfield, so a longer line takes longer and shows more of them.
- Player and enemy towers gain **+1 soldier every 2 seconds**, and only while they have **no** outgoing link. The growth timer pauses; it is not thrown away. Neutral towers never grow. Nothing grows past its max (60 for a normal outpost).
- Enemy growth is scaled by the difficulty growth multiplier.
- A friendly soldier adds 1. An enemy soldier subtracts 1. At 0 the tower flips to the attacker and the count stays 0 (that soldier is spent). The flipped tower loses its outgoing links. Links that were aimed at it stay, so an attack turns into support.
- Link limits: below 10 soldiers, 1 link (level 1); 10 or more, 2 links (level 2); 30 or more, 3 links (level 3); count caps at 60. If the count falls under a threshold, the **newest** extra links are cut. Level is the row of stars under the tower (gold means that slot is in use) and a gold ring at level 3.
- At exactly 60, the tower shows a MAX badge. A friendly arrival does not raise the count. It is sent onward, round-robin, along that tower's outgoing links. A full tower with nowhere to send absorbs the soldier. At most 8 soldiers are in flight on one link.
- Two of your own towers can be linked in only one direction. Dragging the other way removes the old link and creates the new one. Soldiers already walking the old way keep going and reinforce the destination. The red herd follows the same rule with its own towers. Soldiers of opposite owners still cancel one for one when both directions are open.
- You may link to an enemy tower, a neutral tower, or your own tower. You cannot link a tower to itself, duplicate a link, or cross a bramble. A swipe cuts only **your** lines. The bot cuts its own. Soldiers already on a cut line are removed.
- You win when red owns no towers, even if some are still unclaimed. You lose when you own none. If both would hit zero together, it is a loss.
- The bot waits one reaction interval, then picks a weak nearby target. It prefers your towers, then neutrals, then a weak ally. It obeys the same link cap. Sometimes it picks a random legal link instead (its mistake chance).

Difficulty, from the title screen (Normal is the default):

| | Reaction | Mistake chance | Enemy growth |
| --- | --- | --- | --- |
| Easy | 3.2 s | 40% | ×0.75 |
| Normal | 2.0 s | 15% | ×1.0 |
| Hard | 1.15 s | 5% | ×1.30 |

There is no settings menu yet. `GameSettings` already stores `difficulty`, `music_enabled`, and `sound_enabled` for that menu. `AudioHooks` plays a sound or the music loop when the matching file exists and the toggle is on, and does nothing when the file is missing.

## Adding a level, a tower type, or new art

- Levels are JSON files in `data/levels/`. Coordinates are 0–1 across the portrait field (`x` left to right, `y` top to bottom). Point `GameSettings.level_path` at another file when you add a level select. Each tower has `id`, `type`, `x`, `y`, `owner` (`player`, `enemy`, `neutral`, `world`), and `count`.
- Tower behaviour lives in `data/tower_types.json`. Mirror Meadow only uses `outpost`. These types are already wired so a later level can drop them in without a rules rewrite:
  - `factory` (Burrow Works) follows the outpost rules and grows twice as fast while it is not sending.
  - `artillery` (Seed Lobber) does not send soldiers. Every few seconds it spends one crew to damage the nearest capturable tower in range. Crew still grows, because it has no outgoing link.
  - `blockade` (Bramble) cannot be captured and blocks any link that would cross it.
  - `hazard` (Mud Pit) removes a soldier that walks into it.
- A level may also list `blockades` and `hazards` as circles: `{ "x", "y", "radius" }`.
- A behaviour that flags cannot express goes in `scripts/sim/abilities.gd`.
- Art is only in `assets/sprites/`. Replace a PNG and keep the file name; the match code does not need to change. Towers are stacked from `tower_face.png` and `tower_top.png` (one floor, drawn with a slight top-down tilt). `tools/make_placeholders.py` redraws the current placeholders (needs Pillow). The font is Nunito ExtraBold under the SIL Open Font License (`assets/fonts/OFL.txt`).

Expected audio, when you have it:

- `assets/audio/music.ogg`
- `assets/audio/ui.ogg`, `connect.ogg`, `cut.ogg`, `capture.ogg`, `win.ogg`, `lose.ogg`
