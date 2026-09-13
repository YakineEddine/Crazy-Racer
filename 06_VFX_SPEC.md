# 06 — VFX Specification

All VFX use `GPUParticles3D` as the primary implementation, with a `CPUParticles3D` fallback variant for low-end Android (per mobile optimization target in the asset list). Each VFX is its own reusable `.tscn` in the relevant `assets/.../vfx/` folder — never authored inline in a map or vehicle scene.

## 1. Vehicle VFX

| Effect | Anchor | Trigger | Notes |
|---|---|---|---|
| Drift trail (per-wheel) | `DriftTrailAnchorL` / `DriftTrailAnchorR` on vehicle | Drift held | Color/intensity could scale with `boost_charge` value for player feedback |
| Boost trail | `BoostTrailAnchor` | Boost release | Short burst + brief continuous trail while boost impulse is active |
| Class-specific dust/mud/snow kickup | Wheel contact points | Continuous while moving, terrain-dependent | Swap particle texture/color per map surface (dirt, snow, wet street, farmland) |

## 2. Item VFX

| Item | VFX | SFX pairing |
|---|---|---|
| Reverse Gun | Projectile trail + on-hit "confusion swirl" icon above target's head | Fire SFX, hit SFX |
| Shrink Ray | Beam effect (target-to-shooter line) + shrink "poof" transform particle at the moment the model swaps | Beam hum, poof SFX |
| Chicken Storm | Screen-obscuring feather/chicken particle swarm in target's view | Clucking swarm SFX |
| Banana Super Boost | Launch spin particle on drop + slippery trail decal/particle strip that other vehicles can slide on | Boost whoosh, slip SFX on contact |
| Rocket → Penguin Transform | Rocket trail + impact explosion (comedic, non-violent — confetti-esque burst, not gore) + "poof into penguin" transform particle | Rocket whoosh, impact "boop", quack on transform-in |

**Tone constraint:** every impact/explosion VFX in this game must read as comedic/cartoonish (poofs, stars, confetti, squash-stretch) — never realistic damage, gore, or violence-coded imagery, consistent with the game's silly/festive tone.

## 3. Chaos Event VFX

| Event | VFX | Notes |
|---|---|---|
| Gravity Inversion | Full-screen or world-space shader effect signaling inverted gravity (e.g. subtle color grade shift + floating dust particles) + UI banner (see `04_UI_UX_SPEC.md`) | Shader in `shaders/gravity_flip.gdshader`; keep it readable, not disorienting to the point of being unplayable |
| Live Track Modification (bridge/highway collapse) | Break-apart particle burst at the collapsing segment + dust/debris settle | Paired with the mesh/collision swap described in `03_MAPS_AND_CHAOS_EVENTS.md` |
| Meteor/Obstacle Shower | Falling meteor trail per spawned obstacle + impact crater/dust burst on landing | Telegraph each meteor's landing spot briefly before impact (shadow reticle) so it reads as fair, not a surprise instant-hit |

## 4. Environment / Surface VFX

- Ice patch / slippery zone: subtle shimmer particle on the decal surface (Map 3)
- Thin-ice crack warning: crack-line particle/shader intensifies as more vehicles overlap the zone, per `03_MAPS_AND_CHAOS_EVENTS.md` §3.3
- Soft boundary contact (snowbank, hay bale, crop drag): small puff/dust particle on contact to visually communicate the slow-down, reinforcing that it's a "soft" nudge not a bug

## 5. UI-Paired VFX

- Chaos event banner entrance (see `04_UI_UX_SPEC.md`) — slide + subtle particle/glow accent, not just a static banner
- Hit-reaction screen flash — color keyed per item (see `04_UI_UX_SPEC.md` §5)
- Podium celebration — confetti burst (`GPUParticles2D` or 3D, whichever suits the podium camera framing) on Results screen load

## 6. Performance Notes

- Every VFX scene must ship with both a `GPUParticles3D` version and a lighter `CPUParticles3D` fallback; select at runtime based on a device-tier setting (stub this as a simple `Settings.particle_quality` enum consumed by a small VFX-spawning helper, not hardcoded per-effect branching).
- Object-pool short-lived one-shot VFX (impacts, poofs, hit reactions) rather than instancing/freeing per use — ties into the Object Pooling requirement in `01_CORE_SYSTEMS_LOGIC.md`.
- Cap simultaneously active chaos-event VFX (e.g. meteor shower) to a tested maximum concurrent particle count for mid/low-range Android — flag exact number after a device profiling pass.

## 7. Related Docs

- `02_VEHICLES_AND_ITEMS.md` — item effect data these VFX attach to
- `03_MAPS_AND_CHAOS_EVENTS.md` — event triggers and boundary/surface context
- `05_ANIMATIONS_SPEC.md` — animation beats paired with several of these effects
