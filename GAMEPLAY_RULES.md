# Gameplay & Logic Rules — Crazy Racer

Source of truth for physics, controls, and flow — reflects the actual current implementation (Godot 4.7, `VehicleBody3D`-based). Use this as the baseline before tuning. Supersedes `01_CORE_SYSTEMS_LOGIC.md`/`02_VEHICLES_AND_ITEMS.md`/`03_MAPS_AND_CHAOS_EVENTS.md` if those still exist in the repo — those describe an unbuilt multiplayer/mobile design, this describes what's actually shipped.

## 1. Vehicle physics — current baseline

All 8 vehicles run the same script (`vehicle_controller.gd`), differentiated by `KartStats` `.tres` resources:

| Vehicle | Top speed | Accel | Turn radius | Mass | Boost pwr | Knockback | Special |
|---|---|---|---|---|---|---|---|
| Kart | 22.0 | 14.0 | 0.6 | 800 | 12.0 | 1.0 | — |
| Car | 26.0 | 14.0 | 0.45 | 1100 | 13.0 | 1.0 | — |
| Truck | 19.0 | 9.0 | 0.42 | 1900 | 11.0 | 0.4 | `is_plow_class` (immune to chicken/banana hits) |
| Motorcycle | 25.0 | 19.0 | 0.85 | 550 | 14.0 | **1.6** | 2× lean animation; only vehicle whose knockback (>1.3) triggers full spin-out; `tip_over_risk=1.0` (only class that can tip — see below) |
| Bicycle | 17.0 | 10.0 | 0.95 | 350 | 10.0 | 1.2 | `ignores_size_hazards` (immune to shrink/lightning; less offroad penalty) |
| Sport | 27.0 | 15.0 | 0.5 | 900 | 13.5 | 1.1 | — |
| Taxi | 23.0 | 15.0 | 0.6 | 1000 | 12.0 | 0.9 | — |
| SUV | 20.0 | 10.0 | 0.45 | 1700 | 11.5 | 0.6 | — |

Per-vehicle suspension/grip (`KartStats`, applied to every `VehicleWheel3D` in `vehicle_controller._ready`):

| Vehicle | Stiffness | Damping (comp/rel) | Friction (`wheel_friction_slip`) | Feel |
|---|---|---|---|---|
| Bicycle (350) | 32.0 | 2.4 / 2.4 | 8.0 | soft/bouncy, slides most |
| Motorcycle (550) | 38.0 | 2.8 / 2.8 | 8.5 | agile, lively |
| Kart (800, baseline) | 50.0 | 4.0 / 4.0 | 10.5 | reference feel, unchanged |
| Sport (900) | 52.0 | 4.2 / 4.2 | 10.8 | — |
| Taxi (1000) | 54.0 | 4.4 / 4.4 | 11.0 | — |
| Car (1100) | 56.0 | 4.6 / 4.6 | 11.2 | — |
| SUV (1700) | 66.0 | 5.4 / 5.4 | 12.5 | stiff/planted, slides least |
| Truck (1900) | 70.0 | 5.8 / 5.8 | 13.0 | stiffest, most planted |

Baseline note: the `.tscn` files still say `suspension_stiffness=50.0`, `damping 4.0/4.0`, `friction_slip=2.5` for all 8, but the friction key is ignored in Godot 4.7 (runtime property is `wheel_friction_slip`, actual default 10.5 — verified in-engine). The controller now overwrites all four per wheel from the `.tres` at spawn (same pattern as `stats.mass`), so the `.tscn` wheel values are fallback only.

- `acceleration` is a force factor (×60 in code, negated so `+1` throttle drives the `-Z` visual front), `top_speed` is an m/s cap, `turning_radius` multiplies into `max_steer = 0.55 × turning_radius × handling` (unchanged; steering applied negated for the same `-Z` reason).
- `KartStats.drift_boost_curve` is now read: `_drift_boost_mult(charge)` samples it at release charge and scales the tier durations `0.6/1.2/1.9s` by `0.85 + 0.30 × sample` (0.85–1.15). Thresholds (`0.35/0.7/0.99`), charge rate (`+0.45/s`), and `max_steer` are unchanged. Sequencing fix: the release block now reads `_was_drift` from the previous frame (it was overwritten by `_apply_lean()` in the same frame, so release boosts could never fire).
- `KartStats.collision_shape_scale` is now read: the `CollisionShape3D` `BoxShape3D.size` is set from it (duplicated per instance). Values are used as absolute extents (a pure multiplier would exceed the 4.0 spawn-grid spacing, e.g. truck scene 3.8 × tres 2.3 = 8.74).
- Drift: charges at `+0.45/s` to a `1.0` cap (same rate for all vehicles); release tiers give base boost duration `0.6s` (≥0.35 charge), `1.2s` (≥0.7), `1.9s` (≥0.99), each scaled by the curve multiplier above.
- Tip-over moto (PROPOSED values, needs playtesting — not final): `KartStats.tip_over_risk` gates it (`1.0` moto, `0.0` everyone else). Instability builds `+0.8/s` while `|steer| × speed/top_speed > 0.55` (≈1.25 s of limit cornering to tip), decays `−1.2/s` below it; at 1.0 the bike eats its own >1.3-knockback full spin (`_hit_wobble`, same path as shells) + 4.0 s cooldown with no re-trigger. Telegraph: orange sparks past 0.7 build (existing 2× lean already steepens with the same steer input). Stacking cap: a single shared wobble tween (new hits restart instead of overlapping) + tip suppressed while a wobble tween runs. `max_steer`, drift charge/thresholds, boost durations untouched.
- Steering special cases already implemented: penguin driver `×0.55` handling, shrink status `×0.8` handling, chicken-hit adds a `sin(t/90)×0.6` steering wobble, banana/slip adds `steer×1.8 + sin(t/120)×0.5`.
- Offroad slowdown: `×0.62` normally, `×0.8` for `ignores_size_hazards` (Bicycle).

## 2. Camera — current baseline
- `GameManager._attach_chase_camera()` creates a `Camera3D` (`ChaseCam`, `fov = 70.0`) on a `CamRig` (`Node3D`) keeping the same resting offset as before: local `(0, 3.2, 6.5)`, rotated `(-14°, 0, 0)`.
- The rig is `top_level = true` and eased every `_process` toward that resting pose: position lerp (`CAM_POS_SMOOTH = 6.0`), yaw-only `lerp_angle` (`CAM_YAW_SMOOTH = 5.0`), pitch fixed at `-14°`, roll `0`. It no longer inherits collisions, drift snap, wobble, or shrink scale (scale stays `1` when the vehicle shrinks) instantly.
- No FOV changes tied to speed/boost currently exist.

## 3. Controls — current baseline
- 7 custom input actions in `project.godot`: `drift` (Space, Joypad button 7), `item_use` (E, Joypad button 2), `steer_left` (Left, A, D-pad Left, left-stick X-), `steer_right` (Right, D, D-pad Right, left-stick X+), `throttle` (Up, W, D-pad Up, left-stick Y-), `brake` (Down, S, D-pad Down, left-stick Y+), `pause` (Escape, gamepad Start/button 6). WASD uses physical keycodes (position-based, layout-independent).
- Throttle/steer read `steer_left`/`steer_right`/`throttle`/`brake` in `vehicle_controller.gd` with the same argument order as the old `ui_*` calls (`get_axis("steer_right", "steer_left")` = left +1), so steering signs, the reverse-item flip, and touch/bot sharing are unchanged — a future rebind UI can now bind these named actions.
- `KEY_SPACE` is also checked directly in `vehicle_controller.gd` in addition to the `drift` action (redundant dual-handling).
- Touch controls exist: `touch_joystick.gd` (single-thumb steering) plus `touch_throttle`/`touch_drift` vars, wired in `race_hud.gd`. An "AUTO: ON/OFF" toggle controls auto-acceleration.
- Gamepad: D-pad + left stick drive the same `steer_*`/`throttle`/`brake` actions as the keyboard (identical code path); buttons 2/7 kept for item/drift, button 6 (Start) pauses.

## 4. Settings & persistence — current baseline
- Single save file: `user://crazy_racer.cfg` (Godot `ConfigFile`), owned by `GameManager`.
- Currently saved: `tt/<map_id> = {total, best}` (time-trial records, 4 maps), `carriere/gp_wins` (int), and `settings/{music, volume, quality}` (music bool default true, volume 0..1 default 1.0 = bus 0 dB, quality `high`/`low` default `high` → `VfxFactory.particle_quality`, LOW = `CPUParticles3D` path).
- The pause menu (`pause_menu.tscn`) is the settings screen: music toggle, volume slider (live-apply, saved on release), graphics-quality toggle. The main-menu music button and `KEY_M` route through the same `GameManager` setters, so they persist too. Nothing else persists (control bindings reset every launch).
- No other settings screen exists — no controls-remap menu in any `.tscn`.

## 5. Game flow — current baseline
Phases (`GameManager.MatchPhase`): `MENU → LOBBY → COUNTDOWN → RACING ⇄ PAUSED → RESULTS` + `AUTH` (appended last, value 6), each mapped 1:1 to a UI scene (`main_menu`, `lobby_screen`, `countdown_overlay`, `race_hud`, `results_screen`, `pause_menu`, `auth_screen`).

- Pause (RACING only, Esc/Start/HUD button): `get_tree().paused = true` freezes physics, timers, chaos and controls; `race_timer` only advances in `RACING` so it freezes and resumes cleanly. Resume rebuilds the HUD; quit-to-menu unpauses via `_cleanup_race`.
- Classement en ligne (phase `BOARD`, écran `leaderboard_screen.tscn`) : top 10 par map des comptes liés + rang perso hors top 10 (`BoardClient`, SQL `race_results` + RLS à faire tourner côté dashboard). Chaque course finie se soumet une fois (`results_submitted`, remis à zéro par `start_countdown`) ; invités : rang seul sur l'écran de résultats, jamais de top public.
- Compte (phase `AUTH`, écran `auth_screen.tscn`, client natif `scripts/auth/supabase_auth.gd`) : gate / inscription + OTP email 6 chiffres / connexion (+ Google/Discord via navigateur + callback localhost PKCE) / mot de passe oublié. Config hors repo (`supabase_config.json` ignoré, voir `.example.json`) ; sans config, l'écran l'affiche et l'invité continue hors-ligne. Session en mémoire seule. OAuth lie au compte mot de passe existant (emails vérifiés, jamais de doublon créé côté client).
- Countdown is fixed `3.5s`, race timeout is `600s` (10 min) auto-finish.
- Results screen has 4 branches: single race podium, GP (grand prix) round, GP champion, and time-trial — all in one script (`results_screen.gd`).
- Chaos events (`ChaosEventSystem`): first event fires after `12–18s` (code comment: "sooner, for the demo"), subsequent ones every `25–45s`; only one active at a time; weighted per map via `MapData.weighted_events`. Only enabled outside time-trial mode.

## 6. Consistency across vehicle/character types
- Vehicle type (Kart/Car/Truck/etc.) and driver character (human/animal, 11 options) are independent selections — any character can pilot any vehicle. Keep this decoupling when adding new vehicles or characters; don't hardcode a character-vehicle pairing.
- `CharacterData.voice_pitch` (11 values, 0.7–1.8) drives audio via `audio_manager.gd`: the engine-loop pitch is multiplied by the local driver's pitch (clamped 0.5–2.0), and the vocal one-shots (`chicken`, `hit`, `star`) are pitched the same way — character choice is audible. Unknown/missing character falls back to 1.0 (cached per id).
- Locomotion pilote (PROPOSED values, needs playtesting — not final): farm FBX with a gait clip (cow/horse/zebra → `Armature|Run`; pig/sheep/llama/pug have Idle+Jump only → stay Idle) play it scaled `0.5→1.6` by speed/top_speed; all drivers lean `±0.15` max (`0.02` per m/s², back on throttle / forward on brake) and yaw `0.35` per steer unit into the turn, on an inner `Reactive` node (celebration/humiliation tweens + shrink/penguin scale stay on the outer root, shrink rebuild inherits lean gracefully at mini scale).
