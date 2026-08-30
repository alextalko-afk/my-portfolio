# Aim Range

A CS-style 3D aim trainer built in **Godot 4.3** (GDScript). Single-player,
native desktop build (Windows/Linux/macOS) — no browser involved.

Focus of this first version: how the gunplay *feels* — source-style movement
momentum, a learnable per-weapon recoil pattern, accuracy bloom, hit
feedback — on a shooting range with static and moving pop-up targets.
It is not a CS2 clone (no economy, bomb, or multiplayer) — see *Scope* below.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) (the standard
   "Godot Engine" build, not .NET — the project uses GDScript only).
2. Open Godot, "Import", select this folder's `project.godot`.
3. Press **F5** (or the Play button). The first open will take a few extra
   seconds while Godot imports the `.wav` files — normal, one-time.
4. From the main menu, click **PLAY**.

To ship a standalone executable: `Project > Export`, add a preset for your
platform (Godot will prompt to download export templates matching your
editor version), then Export Project.

## Controls

| Action | Key |
|---|---|
| Move | WASD |
| Jump | Space |
| Crouch (hold) | Ctrl |
| Walk slower (hold) | Shift |
| Fire | Left mouse |
| Reload | R |
| Switch weapon | 1 (rifle) / 2 (pistol) |
| Start a scored 60s run | T |
| Release mouse cursor | Esc |

## What's implemented

- **Movement**: Quake/Source-style accelerate+friction on the ground, plus
  air strafing with a capped wish-speed (the classic bunny-hop trick), so
  momentum carries between jumps instead of movement just being "walk speed
  in any direction."
- **Two hitscan weapons** (rifle, pistol), each with its own fire rate, a
  deterministic recoil pattern (same spray every time, so it's learnable —
  generated procedurally per weapon, not copied from any real game), and an
  accuracy cone that opens up while moving/spraying and recovers when you
  stop, mirroring how CS-likes discourage run-and-gun.
- **Targets**: pop on any hit and respawn a moment later at a random point
  from their spawn pool. Separate head/body hitboxes score differently.
  Static targets (red) and side-to-side patrol targets (blue).
  A hit marker and distinct headshot sound confirm hits.
  Live stats (score, hit/shot accuracy, streak) plus an optional 60-second
  timed run (`T`) for a scored sprint.
- **Everything is built from primitives/code** — level geometry, the
  weapon viewmodels, targets, and HUD are all generated at runtime from
  boxes/capsules/spheres and `Control._draw()`, so there are no external
  art assets to manage. The 7 `.wav` sound effects (gunshots, reload,
  hit markers, empty click) are procedurally synthesized (see the "Generated
  audio" note below) rather than recorded/sourced.

## Scope (what's deliberately not here)

Multiplayer, bomb-defusal rounds, and buy menus were out of scope for this
pass — the brief was specifically an aim-training range, not a full CS2
replica. The movement/weapon/target/scoring systems are decoupled enough
(`scripts/player`, `scripts/world`, `scripts/ui`) that a round-based game
mode could be layered on later without reworking the core feel.

## Project structure

```
project.godot
scenes/            -- thin scene roots; almost everything is built in code
  main_menu.tscn
  range.tscn        (root script: scripts/world/range_builder.gd)
  player.tscn
  hud.tscn
scripts/
  autoload/         -- Settings (sensitivity/volume), GameState (live stats, run timer)
  player/           -- player.gd (movement/camera), weapon.gd (fire/recoil/reload)
  world/            -- range_builder.gd (level), target.gd, target_moving.gd
  ui/                -- hud.gd, crosshair.gd, hitmarker.gd, main_menu.gd
  weapon_stats.gd    -- weapon tuning data (Resource)
  weapon_presets.gd  -- rifle/pistol factory functions
audio/              -- procedurally generated .wav sound effects
```

### Generated audio

`audio/*.wav` were synthesized with a small offline Python script (noise
bursts + envelopes for gunshots/clicks, sine blips for hit markers) —
placeholders with the right punch/timing rather than final sound design.
Swap them for your own `.wav` files (keep the filenames, or update the
paths in `weapon_presets.gd` and `scripts/ui`) whenever you want a real
audio pass.
