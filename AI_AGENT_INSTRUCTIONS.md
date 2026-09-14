# AI Agent Instructions — Crazy Racer (v1.1 update cycle)

Entry point for any AI agent working on this repo. Read this file first, then the companion docs it points to before editing anything. This file **replaces** the previous `AI_AGENT_INSTRUCTIONS.md` (which described the audited v1.0.2 baseline) — that baseline is still true unless a section below says otherwise.

Base facts: Godot 4.7, GL Compatibility renderer. Repo: `github.com/YakineEddine/Crazy-Racer`, tag `v1.0.2` is the last known-good state before this update cycle. Work in a branch; don't rewrite history on `main`.

## 0. Companion docs for this update (read the one relevant to your task)

| Doc | Covers |
|---|---|
| `UI_UX_INSTRUCTIONS.md` | Landing-page redesign (progressive/paged reveal), button/visual fixes, countdown 3‑2‑1, login/signup screens |
| `PHYSICS_MOVEMENT_INSTRUCTIONS.md` | Motorcycle instability/fall-over, animal-driver real limb/body locomotion, vehicle asset swap |
| `POWERUPS_INSTRUCTIONS.md` | Rules for touching the item pipeline while doing the above without regressing balance |
| `AGENT_MEMORY_THINKING.md` | How an AI agent should plan, record decisions, and hand off work across sessions on this repo |
| `MAP_ENVIRONMENT_INSTRUCTIONS.md` | Where to get real racing-track assets/kits, how to use them with `map_builder.gd` |
| `PROMPTS.md` | Ready-to-paste prompts for each of the above, in build order |

`GAMEPLAY_RULES.md` and `STYLE_GUIDE.md` are still the source of truth for current baseline values (they get updated in-place as work lands, not replaced). `PROJECT_AUDIT.md` is a point-in-time snapshot — re-generate it (or ask the agent to re-audit) after this update cycle lands, don't trust it as current once you've made changes.

The old numbered spec docs (`00_PROJECT_STRUCTURE.md`…`07_ASSET_LIST.md`, the GDD) are still gone and still not a reference — same rule as before.

## -1. 🚨 Known critical bug — RESOLVED (ne pas re-casser)

Unchanged from the previous instructions file — kept verbatim because it's still load-bearing:

**C'était :** conduite inversée (gauche → droite, haut → arrière), confirmé en play-test.
**C'est réparé et vérifié en jeu (Godot 4.7) :** haut = avant visuel (`-Z`), bas = marche arrière, gauche/droite corrects, via les actions nommées `steer_left`, `steer_right`, `throttle`, `brake` (voir `GAMEPLAY_RULES.md` §3).
**Ne re-inverse aucun signe.** Rappel du piège : le forward physique `VehicleBody3D` est `+Z`, le devant visuel/piste/caméra du projet est `-Z` — `vehicle_controller.gd` inverse aux deux endroits marqués en commentaire. Any physics work in this cycle (motorcycle fall-over, animal locomotion) must re-verify keyboard/WASD/gamepad/touch after the change, same four paths as before.

## 0-bis. Architecture facts the agent must respect (unchanged + new)

Everything in the old file still holds: 7 autoloads in fixed order, all 8 vehicles share `vehicle_controller.gd` driven by `KartStats` resources, `stats.mass` overwrites scene mass at runtime, single UI theme at `assets/ui/theme.tres`, `GameManager.MatchPhase` state machine, settings persisted only via `user://crazy_racer.cfg`, item effects hardcoded in `ItemSystem._apply_to`'s `match` block, counts (8 vehicles / 14 items / 4 maps) match the shipped game. Don't rediscover these — see `PROJECT_AUDIT.md` §0–§5 if you need the exact numbers.

New facts as of this update cycle:

- **Auth/account system: implemented (native client, no addon).** The community addon turned out to be Godot-3-only with OAuth stubbed out, so `scripts/auth/supabase_auth.gd` (class `SupaAuth`, plain REST + PKCE localhost callback) + phase `AUTH` + `auth_screen.tscn` (gate/signup/OTP/signin/forgot) implement `UI_UX_INSTRUCTIONS.md` §5 instead. Secrets live in untracked `supabase_config.json` (see `.example.json`); OAuth reuses a verified email to link into an existing password account, never creating a duplicate. No leaderboard yet (still local `user://crazy_racer.cfg`).
- **No leaderboard/ranking system exists yet.** TT records and GP wins are local-only (`user://crazy_racer.cfg`). A real leaderboard needs a backend table, which naturally follows from adding Supabase for auth (same project, `Database`/`Realtime` module). Update: table `race_results` + RLS designed (see task handoff) but not created — run the SQL dashboard-side first; client code (`BoardClient`, board screen, results hook) is already wired behind it.
- **The current 8 vehicles are procedurally built by `vehicle_mesh_builder.gd`** (chassis/seat/steering/spoiler primitives, tire+rim wheels, FBX shells only for Sport/Taxi/SUV). Several of these are being replaced with free downloaded CC0 vehicle models (not custom-authored — sourced from `poly.pizza`/Kenney/Quaternius, see `PHYSICS_MOVEMENT_INSTRUCTIONS.md` §"Vehicle asset swap"). This is a data/asset change (new `.glb` + mount them like the existing Sport/Taxi/SUV FBX path), **not** a rewrite of `vehicle_controller.gd`'s physics.
- **Motorcycle and animal-driver movement are currently generic.** All 8 vehicles share identical car-like handling except for the stat table (top speed/accel/turn radius/mass) — there is no lean-to-the-point-of-falling behavior for the Motorcycle class, and `driver_builder.gd`'s animal drivers are static meshes scaled onto the seat with no locomotion. See `PHYSICS_MOVEMENT_INSTRUCTIONS.md`.

## 1–6. (unchanged)

Sections "Consistency is the priority", "Scope discipline", "Physics & gameplay feel", "UI/UX", "Settings & controls", and "Before finishing any task" from the previous instructions file still apply as written — re-read them, they are not reproduced here to avoid drift between two copies. The one addition to "Before finishing any task": if your change touches auth, controls, camera, or vehicle assets, **also** confirm the game still boots straight into a normal quick-play race with no network/account dependency for local/offline testing (the login gate must never block the existing single-player loop from being testable without a live backend).
