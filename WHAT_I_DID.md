# What I did and why: Echo-Pulse

These are top-level notes on how Echo-Pulse is built, in the order it happened. Each part says what was built, why, and which Godot ideas it uses, compared with how NEON (the Phaser game) did the same thing.

**Status:** milestones M0–M2 are done. The core loop, three Chapter 1 rooms, the UI, audio and tests all work. M3–M6 are next (see the end).

---

## The game in one paragraph
The screen is pitch black. **SPACE** sends out a sound ring. Walls light up where it touches them, then fade after about 1.5 s. Blind **Stalkers** can't see you at all, only hear you. When a sound reaches one, it sprints to **where the sound was made**, not to where you are now. So the core move is: pulse, then move away. Rocks are decoys: a rock landing makes a loud noise somewhere else.

**Controls:**
- WASD: move
- Shift: run (loud)
- Ctrl: sneak (silent)
- SPACE: tap to ping, hold to deep pulse
- Right click: throw a rock
- Esc: pause
- R: restart
- F3: debug view

---

## M0: Setup
- Installed **Godot 4.7.2** with winget. The exe lives under `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine...\`. Use the `_console.exe` version for terminal commands.
- Downloaded these CC0 assets:
  - **Kenney** audio packs: Impact, Sci-Fi, Interface and Digital, 366 sounds in total.
  - Two OFL Google fonts: *Share Tech Mono* for the HUD and *Oxanium* for titles.
- I skipped Freesound because its API needs a key. The ambience it would have supplied (drone, water drips) is **synthesized in code** instead.
- The **renderer is set to "Compatibility"** (OpenGL) so the same project exports to the web later.
- **Input Map:** written by a small script (`tools/setup_project.gd`) so its format in `project.godot` is exactly right. You can still edit it in *Project Settings → Input Map*. Keyboard and gamepad are both mapped.

> **Phaser vs Godot:** NEON had no project file. Config lived in code (`src/config.ts`). In Godot, `project.godot` holds settings, the input map, physics layer names and **autoloads**.

## M1: Feel prototype (dark room, pulse, echoes)
- **Player** (`scenes/player/`): a `CharacterBody2D` in floating mode (top-down) that moves with `move_and_slide()`.
  - Its tuning values are `@export`ed, so you can tweak speeds, pulse radius and loudness live in the **Inspector**.
  - **Tap vs hold:** a tap fires a small ping. Holding for 0.8 s gives a deep pulse that reaches 620 px and **bounces once** off walls.
  - Pressing SPACE during the cooldown is **buffered**. A test caught that it used to be ignored.
- **EchoRenderer** (`core/echo_renderer.gd`), the core visual:
  - A pulse casts 200 rays (360 for a deep pulse) once.
  - Each wall hit is stored with the time the ring will *reach* it (distance ÷ 720 px/s), so the room lights up as the wave travels outward.
  - Each hit becomes a short line drawn **along the wall**: cyan for walls, green for the exit, amber for rubble.
  - Everything is drawn in **two draw calls** (a soft glow and a sharp core) with additive blending.
- **Map memory:** walls don't vanish completely. They linger as a faint ghost for about 20 s, so you build a mental map. *Purist* mode (menu or pause) turns this off.
- **Post-FX shader** (`shaders/post.gdshader`): chromatic aberration kicked by pulses, a vignette, a red edge that throbs with the heartbeat, scanlines and grain.

> **Phaser vs Godot:** NEON drew art into canvases once at boot. Here, nodes draw themselves every frame in `_draw()`, and shaders are written in Godot's GLSL-like shading language.

## M2: Vertical slice (enemies, sound model, rooms, UI)
- **SoundBus autoload: one door for every noise.** `SoundBus.emit_noise(pos, loudness, kind, source, reveal)` handles pulses, footsteps, rocks and anything added later.
  - It works out who hears a sound by **how far the sound has to travel**, not straight-line distance.
  - **Propagation grid** (`core/propagation_grid.gd`): the room becomes 32 px cells and a *Dijkstra flood fill* runs out from the noise. Sound flows around corners and through doorways. Each wall cell costs as much as 10 open cells, so thin walls leak a little and thick walls block.
  - Hunters react **when the visible ring reaches them**, so what you see matches what they hear.
- **Stalker** (`scenes/enemies/stalker/`): a simple enum state machine.
  - It moves through four states: IDLE (shuffles and growls), ALERTED (sprints to the sound), SEARCH (sniffs around for 3.5 s), and RETURN to its post.
  - It's never drawn. You *hear* it: positional growls, footsteps, and tiny red echo blips.
  - **Pathfinding** uses an `AStarGrid2D` on the same grid.
  - I chose `AStarGrid2D` over `NavigationAgent2D` from the plan, because one grid now serves both sound and movement.
- **Rocks:** they arc to the mouse cursor (or the right stick), stop at walls, and on landing make a loud noise with its own small reveal.
- **Fair darkness:**
  - A **heartbeat** speeds up as a hunter gets closer.
  - The exit **hums** (positional audio) so you can find it by ear.
  - Your own footsteps show a faint ring of how far they carry: walk 48 px, run 190 px, sneak none.
- **Death kill-cam:** the hunters freeze, the whole room flashes into view as a blueprint, and the killer shows in red. Then "SIGNAL LOST" and a respawn. Your map memory **survives death**, so every death teaches you something.
- **Room clear:** the full map is revealed, your route is redrawn as a glowing trail, and you get stats and a rank: **S/A/B/C** from time vs par, detections and deaths. Best results are saved to `user://save.cfg`.
- **Rooms are built from ASCII.**
  - `tools/build_rooms.gd` turns text layouts (`tools/room_layouts/*.txt`) into **real Godot scenes**: a painted `TileMapLayer` for Floor and Walls, plus placed scene instances (player, exit, stalkers, rubble, radio hints).
  - After that they're normal scenes. Open one in the editor and repaint it with the TileMap tools.
  - The builder **refuses layouts where the exit or a pickup is unreachable**, and won't overwrite rooms you've edited unless you pass `--force`.
- **Three Chapter 1 rooms**, each teaching one idea:
  - **1-1 WAKE:** pulse to navigate, with no enemies.
  - **1-2 LISTEN:** one Stalker in a pillared hall. Pulse, then move away.
  - **1-3 DECOY:** the Stalker sits by the exit, so you throw a rock to lure it away.
- **UI:**
  - The main menu has a procedural sonar-sweep shader background, room select with best ranks, and the map memory toggle.
  - The HUD shows the room, time, deaths, rocks and a pulse charge meter.
  - Dr. Varn's radio messages type out on screen.
  - There's a pause menu and a room-clear screen.
  - Everything works with keyboard and gamepad.
- **Audio** (`autoload/audio.gd`):
  - Four buses (SFX, Enemy, Ambience, UI), with a damp **cave reverb** on world sounds.
  - Pooled positional players.
  - The sonar ping, deep pulse, heartbeat, drips and an 8 s seamless drone loop are **synthesized** at startup.

> **Phaser vs Godot:**
> - **Scenes and instancing:** NEON's level was one big data file. Here, the player, the exit and enemies are each a reusable **scene** dropped into room scenes.
> - **Signals:** an `Events` autoload works as a global signal hub (`player_died`, `room_cleared`, `radio`…). Systems react without knowing about each other.
> - **Groups:** `"listeners"`, `"enemies"` and `"player"` replace manual lists.

---

## Bugs the tests found (and the fixes)
1. **Rays snagging on tile seams.** Rays hitting where two wall tiles meet reported sideways normals. The fix snaps the hit to the real exposed face.
2. **Close walls looked dotted.** Near the player, many hits fell into one dedup cell and only the first was kept. Each fragment is now at least as long as that cell.
3. **SPACE during the cooldown was ignored.** It's now buffered.
4. **Thin walls let a deep pulse through.** This one is intended: thin walls leak. The fix was raising wall muffling to 10×, and the test room now uses a properly thick wall.
5. **The tileset was being copied into every room file,** and the instances saved every property. Fixed in the builder, so edits to `player.tscn` now flow into all rooms.

## How it was checked
- **32 headless tests:** `godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn`. They check that:
  - sound goes around corners but not through thick walls
  - pulses light walls outward and nothing behind walls, then fade
  - hunters go to the sound's origin and not the diver, and arrive and search
  - rocks re-target hunters
  - sprint is loud, walk is quiet, sneak is silent
  - tap and hold pulses work
  - contact kills, and the exit clears the room
  - the save file round-trips
  - in every campaign room the exit is reachable, and no hunter can hear a ping from the spawn point
- **Screenshots** of key moments, rendered by `tests/screenshots.tscn` into `tests/screenshots/`. These are how I tuned the echo look.

## Still worth checking by hand
- **How it feels:** pulse timing, Stalker speed (250 px/s vs your 225 px/s sprint), and how hard 1-2 and 1-3 are. Tests can't judge fun or fear.
- **The mix:** the Stalker sounds are Kenney samples pitched down, and the drone level is a guess. Please listen with headphones.
- **Gamepad aiming** for rocks. It's mapped, but I couldn't test it here.

---

## Where to edit
| I want to… | Edit |
|---|---|
| Change speeds, pulse size or loudness | Select the Player in a room and use the Inspector, or `scenes/player/player.gd` |
| Make Stalkers hear better or run faster | `scenes/enemies/stalker/stalker.gd` (`hearing`, `chase_speed`…) |
| Change how much walls muffle sound | `WALL_MUFFLE` in `core/propagation_grid.gd` |
| Change how long walls stay lit | `BRIGHT_TIME`, `FADE_TIME`, `GHOST_*` in `core/echo_renderer.gd` |
| Add a room | Write `tools/room_layouts/ch1_04.txt`, run the builder, add it to `ROOMS` in `autoload/game.gd` |
| Repaint a room | Open `scenes/rooms/ch1_0X.tscn` and select the **Walls** or **Floor** TileMapLayer (walls are hidden in-game but visible in the editor) |
| Swap a sound | `BANK` and `MIX` in `autoload/audio.gd` |
| Change the dialogue | The `hintN:` lines in the layout file, or the RadioHint node's `text` in the editor |

## Next milestones (from the plan)
- **M3 Systems:** flares, floor surfaces (metal is loud, carpet is silent, water ripples), masking machines, doors and keys, audio logs. Finishes Chapter 1.
- **M4 Content:** Howler, Swarmlings, the noisemaker, then Chapters 2 and 3, the Brute and breath-holding.
- **M5 Polish:** the Mimic finale, a settings screen (accessibility, colourblind palettes, rebinding), chapter cards, credits.
- **M6 Ship:** Windows and Web exports, and an itch.io page.
