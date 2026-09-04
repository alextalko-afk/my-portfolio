# Aim Range

A CS-style single-player 3D shooter built in **Godot 4.3** (GDScript).
Native desktop build (Windows/Linux/macOS) — no browser involved.

You're dropped into an arena against two AI squads — **Terrorists** (tan)
and **Spec Ops** (dark navy) — who patrol, take cover, spot you, and shoot
back. Five weapons, source-style movement, a learnable per-weapon recoil
pattern, and a health/respawn loop. It is not a full CS2 replica (no
economy, bomb, or multiplayer) — see *Scope* below.

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
| Aim down sights / scope | Right mouse (hold, sniper only) |
| Reload | R |
| Switch weapon | 1 Rifle · 2 Pistol · 3 SMG · 4 Sniper · 5 Knife |
| Start a scored 60s run | T |
| Release mouse cursor | Esc |

## What's implemented

- **Movement**: Quake/Source-style accelerate+friction on the ground, plus
  air strafing with a capped wish-speed (the classic bunny-hop trick), so
  momentum carries between jumps instead of movement just being "walk speed
  in any direction."
- **Five weapons** — Rifle, Pistol, SMG, Sniper, Knife — each with its own
  fire rate, damage, and a deterministic recoil pattern (same spray every
  time, so it's learnable — generated procedurally per weapon, not copied
  from any real game). Accuracy bloom opens up while moving/spraying and
  recovers when you stop. The sniper has a real ADS zoom (FOV 90°→25°) with
  near-pinpoint accuracy while scoped; the knife is a short-range instant
  swing with no ammo.
- **Enemies, not paper targets**: Terrorist and Spec Ops soldiers built as
  small procedural rigs (separate head/body hitboxes — headshots always
  kill, body shots chip a 100 HP pool). They idle, patrol fixed routes, or
  hold a guard position; once they get line of sight on you within range
  they turn, open fire with distance-based accuracy, and use the arena's
  cover the same way you do. Killed enemies topple over and respawn a few
  seconds later at a random point in their pool.
- **You can die**: 100 HP, a damage vignette and hit-zone-scaled screen
  shake feedback, a short "ELIMINATED" pause, then respawn at your start
  point with full health (streak resets, score doesn't).
- **Animation, all procedural**: leg/arm walk cycle while patrolling, an
  aim-raise when an enemy goes hostile, a flinch on non-lethal hits, a
  tumble-and-sink death tween, and a scale-in on spawn/respawn — plus on
  the player side, weapon idle sway/bob, a recoil kick, a reload dip, a
  rise-up animation when you switch weapons, screen shake scaled per
  weapon (the sniper kicks hard) and on taking damage, and a camera dip
  when you land a fall. No hand-authored AnimationPlayer tracks;
  everything is driven by script.
- **Visuals**: a real sky + sun/fill lighting pair, SSAO and SSIL contact
  shadows/bounce light, filmic tonemapping and a touch of bloom (Forward+
  only — see note below), and every surface (floor, walls, props, camo
  uniforms, gun metal) carries procedurally generated noise/camo texture
  instead of a flat color. Muzzle flashes throw sparks, bullets that miss
  scorch and spark the wall they hit, hits draw blood, and dead enemies
  kick up a dust puff.
- **Scoring**: live stats (score, hit/shot accuracy, streak) plus an
  optional 60-second timed run (`T`) for a scored sprint. A hit marker and
  distinct headshot sound confirm hits.
- **Everything is built from primitives/code** — level geometry, enemy
  rigs, weapon viewmodels, HUD, and every texture (noise fields, camo,
  scorch marks, muzzle glow) are all generated at runtime, so there are no
  external art assets to manage. The 13 `.wav` sound effects (gunshots per
  weapon, reload, hit markers, melee whoosh/impact, pain, body-fall) are
  procedurally synthesized (see "Generated audio" below) rather than
  recorded/sourced.

> **Renderer note**: SSAO/SSIL only run on the **Forward+** rendering
> method (Godot's desktop default, which this project is configured for).
> If your machine falls back to the Compatibility/Mobile renderer,
> everything else still works — you just lose those two contact-shadow
> effects, silently, with no error.

## Scope (what's deliberately not here)

Multiplayer, bomb-defusal rounds, and buy menus were out of scope for this
pass. Enemy "accuracy" is a simple distance-based hit-chance roll (not a
literal raycast against your hitbox) — line of sight to you is still a real
raycast against the level geometry, so cover genuinely blocks their shots.
The movement/weapon/enemy/scoring systems are decoupled enough
(`scripts/player`, `scripts/world`, `scripts/ui`) that round-based modes,
more factions, or objective types could be layered on later.

## Project structure

```
project.godot
scenes/            -- thin scene roots; almost everything is built in code
  main_menu.tscn
  range.tscn        (root script: scripts/world/range_builder.gd)
  player.tscn
  hud.tscn
scripts/
  autoload/         -- Settings (sensitivity/volume), GameState (stats, health, run timer)
  player/           -- player.gd (movement/camera/death), weapon.gd (fire/recoil/reload/ADS/melee)
  world/            -- range_builder.gd (level + squad placement), enemy.gd (rig/AI/animation)
  ui/                -- hud.gd, crosshair.gd, hitmarker.gd, main_menu.gd
  weapon_stats.gd    -- weapon tuning data (Resource)
  weapon_presets.gd  -- rifle/pistol/smg/sniper/knife factory functions
  world/proc_gfx.gd  -- procedural textures (noise, camo, decals) + particle/decal spawners
audio/              -- procedurally generated .wav sound effects
```

### Generated audio

`audio/*.wav` were synthesized with a small offline Python script (noise
bursts + envelopes for gunshots/impacts, sine blips for hit markers,
filtered noise sweeps for the knife whoosh) — placeholders with the right
punch/timing rather than final sound design. Swap them for your own `.wav`
files (keep the filenames, or update the paths in `weapon_presets.gd` and
`scripts/world/enemy.gd`) whenever you want a real audio pass.
