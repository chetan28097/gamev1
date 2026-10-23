# Echo-Pulse

*Sound is sight. Sound is a target.*

A top-down acoustic stealth game made with Godot 4.7. The world is black until you make a noise, and blind predators hunt whatever they hear.

## Play
1. Double-click **Echo-Pulse (Editor)** on the Desktop, or **Echo-Pulse (Play)** to go straight into the game.
2. Press **F5**.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Run (loud) / sneak (silent) | Shift / Ctrl | LB / L3 |
| Pulse: tap = ping, hold = deep pulse | Space | A |
| Throw rock | Right click (aims at cursor) | RB (aims with right stick) |
| Pause / restart | Esc / R | Start / Back |
| Debug view (walls, hunters, sound heatmap) | F3 | |

## Commands
`godot` is a small shim, `C:\Users\cheta\.local\bin\godot.cmd`, that runs `Godot_v4.7.2-stable_win64_console.exe`. Open a new terminal the first time you use it.
```
godot --headless --path . --import                                   # import assets
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn # run the tests
godot --path . res://tests/screenshots.tscn                          # render screenshots
godot --headless --path . res://tools/build_rooms.tscn [-- --force]  # ASCII layouts -> room scenes
godot --headless --path . -s tools/setup_project.gd                  # rewrite the input map
```

See [WHAT_I_DID.md](WHAT_I_DID.md) for how it's built, and [CREDITS.md](CREDITS.md) for asset credits.
