# Boombot Coffee Run ☕🐾

A complete little Godot arcade game starring a fluffy Samoyed on a coffee-bean mission.
Collect **20 beans in 60 seconds**, avoid moving coral hazards, and keep your three lives.
All art and sound are generated in GDScript: no downloads, plugins, or external assets.

## Play

1. Install **Godot 4.6.3 Standard**.
2. Import `project.godot` in the Godot Project Manager.
3. Open the project and press **F5**.
4. Press **Enter** or **Space** at the title screen.

| Key | Action |
| --- | --- |
| WASD / Arrow keys | Move |
| P / Escape | Pause / resume |
| R | Restart immediately |
| Enter / Space | Start / play again |
| M | Toggle sound |

The game automatically pauses when it loses focus. Being hit grants 1.5 seconds of protection.
Best score is saved locally in Godot's `user://coffee_run.cfg`.
The arena scales with the window. Keyboard required; touch controls are not included.

## Project contents

- `main.tscn`: main scene.
- `scripts/game.gd`: gameplay, procedural artwork, UI and synthesized audio.
- `tests/test_game.gd`: dependency-free, seeded headless regression tests.

## Tests

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_game.gd
godot --headless --path . --quit-after 120
```

The test runner returns a nonzero exit code on assertion failures.
Use a disposable `XDG_DATA_HOME` for isolated test best-score files on Linux.
Tests cover title/start, spawn repeatability/safety, 60/120 FPS movement, normalized diagonals,
bounds, collection/respawn, hit invulnerability, game over, timeout, restart, pause, win and a full round.

## Verification

- Tested using **Godot 4.6.3.stable.official.7d41c59c4**.
- 21 deterministic assertions pass.
- Headless editor import and scene startup pass.
- Independent source review: no blocking issues found.
- Graphical/manual playtest was not performed: this build environment has no working display server.
- This is a source project, **not an exported executable**. Export templates are not installed here.
- Simulation caps unusually long frames at 0.1 seconds to prevent teleporting through hazards.
  Consequently the round lasts longer in wall-clock time during severe stalls (below 10 FPS).

## Export on your computer

In Godot: **Editor → Manage Export Templates**, install templates matching your editor version.
Then **Project → Export → Add** and choose your platform. No platform-specific assets are required.
Web export must be served over HTTP(S), not opened as a local HTML file.

## Branch workflow

Game changes are proposed on `feat/coffee-run`, with a draft pull request targeting `boombot`.
`main` contains only the repository bootstrap until you manually merge your chosen branches.
To play before merging, download/check out `feat/coffee-run` rather than `main`.
