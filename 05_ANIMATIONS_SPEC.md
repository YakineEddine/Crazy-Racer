# 05 — Animations Specification

All character/vehicle animations use Godot `AnimationPlayer` (clips embedded in `.glb` imports or authored in an `AnimationLibrary`). Keep loops short (3–5s) per the mobile target in the asset list.

## 1. Vehicle Animations (per class)

| Clip | Trigger | Loop? | Notes |
|---|---|---|---|
| `wheel_spin` | Continuous while moving | Yes | Driven by speed, not a fixed-rate loop — scale playback speed to current velocity |
| `drift_lean` | Drift held | No (blend in/out) | Karts/Cars: slight body lean; Motorcycles/Bicycles: full lean-rig tilt into the turn |
| `boost_squash_stretch` | Boost release | No, one-shot | Brief squash-stretch on the chassis mesh for comedic punch |
| `item_hit_reaction` | Vehicle struck by item | No, one-shot | Small knockback wobble; Motorcycle plays an exaggerated spin-out variant (higher `knockback_multiplier`) |
| `truck_plow_impact` | Truck class hits small hazard/kart | No, one-shot | Very minor wobble only — the point is the *other* object reacts, not the truck |

Motorcycles and Bicycles need a **lean-rig** distinct from the standard 4-wheel rig — build this as a shared skeleton variant so both classes reuse one lean-rig, not two.

## 2. Character Animations (per character: human, crocodile, penguin, chicken)

Shared skeleton across characters wherever possible (explicit GDD requirement — do not rig each character independently if avoidable).

| Clip | Trigger | Loop? |
|---|---|---|
| `idle_driving` | Default racing state | Yes |
| `celebration` | Top-3 finish, podium screen | Yes (podium loop) |
| `humiliation` | Bottom placement, or hit by a signature item | Yes (short loop) |
| `hit_reaction` | Any item hit | No, one-shot |
| `voice_bark_gesture` | Paired with voice line playback (win/lose/hit/getting-hit) | No, one-shot |

**Penguin-specific:** the Penguin character model doubles as the Rocket item's transform target. When a driver is hit by Rocket, swap their character model to the Penguin rig for exactly 7 seconds, playing a **penguin waddle** loop instead of their normal `idle_driving`, with a quack SFX on the transform-in moment (see `06_VFX_SPEC.md` and item table in `02_VEHICLES_AND_ITEMS.md`). Revert to original character model + `idle_driving` when the timer ends — no fade needed, but a quick pop/scale-in on both transitions sells the gag.

**Chicken-specific:** `flap_panic` clip doubles as the base motion reused (scaled up, multiple instances) for the Chicken Storm item's swarm VFX — do not author a second animation for the swarm; reuse this clip on the pooled swarm instances.

## 3. Humiliation & Celebration — Presentation Rules

- Humiliation triggers on: (a) finishing in bottom placement(s) — define threshold, e.g. bottom 2 in FFA, or (b) being hit by a signature item (Rocket→Penguin is the flagship case).
- Celebration triggers on: top-3 podium finish, plus a lighter in-race taunt gesture available as an emote (stretch scope, not launch-blocking).
- Every chaos-event trigger gets a **shared reaction beat**: all players simultaneously play a short "surprised" gesture + synced voice bark, regardless of placement — implement as a broadcast animation trigger from `ChaosEventSystem.chaos_event_triggered`, not per-player logic.

## 4. Animation-System Integration Notes

- Vehicle and character animations run on separate `AnimationPlayer` nodes (vehicle chassis vs. driver character) since character model can hot-swap (Penguin transform) independently of the vehicle it's sitting in.
- Use `AnimationTree` with a simple state machine only where blending is needed (drift lean in/out, idle→hit-reaction); one-shot comedic beats (squash-stretch, humiliation trigger) can be driven directly via `AnimationPlayer.play()` calls from the relevant system script rather than a full tree.
- All animation triggers that affect gameplay-visible state (Penguin transform, hit reactions) must originate from server-authoritative signals per `01_CORE_SYSTEMS_LOGIC.md` — animation playback itself is client-local/cosmetic, but *when* it plays is server-driven.

## 5. Related Docs

- `02_VEHICLES_AND_ITEMS.md` — item effects that trigger these animations
- `06_VFX_SPEC.md` — VFX paired with each animation beat
- `07_ASSET_LIST.md` §Characters/Vehicles — model/rig asset requirements
