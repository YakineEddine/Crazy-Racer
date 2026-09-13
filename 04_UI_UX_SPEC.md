# 04 — UI/UX Specification

Mobile-first (portrait or landscape — confirm orientation before building; racing games typically favor landscape, flagged as an open decision). All screens are `Control`-based scenes in `scenes/ui/`, swapped under one root `CanvasLayer` managed by `GameManager`.

## 1. Screen Inventory

| Screen | Scene path | Shown during phase |
|---|---|---|
| Main Menu | `scenes/ui/main_menu.tscn` | `MENU` |
| Lobby | `scenes/ui/lobby_screen.tscn` | `LOBBY` |
| Countdown Overlay | `scenes/ui/countdown_overlay.tscn` | `COUNTDOWN` |
| Race HUD | `scenes/ui/race_hud.tscn` | `RACING` |
| Results/Podium | `scenes/ui/results_screen.tscn` | `RESULTS` |

Transitions: `GameManager.phase_changed` signal drives which screen is visible; use a simple crossfade (`AnimationPlayer`, ~0.2–0.3s) between screens, not a hard cut.

## 2. Main Menu

**Elements:**
- Logo / title
- "Quick Play" button → enqueues in `MatchmakingService` with a format-select sub-panel
- "Private Room" button → shows Create (generates code) / Join (4-digit code entry field) toggle
- Settings icon → audio sliders, control scheme toggle (virtual joystick vs. tilt, if tilt is supported)
- Cosmetic locker entry point (vehicle/character/skin selection — feeds into Lobby customization panel)

## 3. Lobby Screen

**Layout:** room code prominent at top (large, tap-to-copy). Player slot list below — up to 16 rows, each showing: avatar/character icon, name, vehicle class icon, ready-state checkmark.

**Elements:**
- Format selector (host-only, disabled for non-host) — segmented control: 1v1 / Duo / Squad / FFA
- Per-player customization panel: vehicle class carousel (5 classes, swipeable), character carousel, skin picker
- "Ready" toggle button (per player) — bottom bar, host sees "Start Race" button which is disabled until `LobbyManager.can_start()` is true
- Leave Room button (top-left, confirm dialog)

**States to design for:** empty slots ("Waiting for player…" placeholder), host-left/promotion transition, room-full state (disables Join elsewhere).

## 4. Countdown Overlay

- Full-screen semi-transparent overlay on top of the loaded map/vehicles.
- Large numeral 3-2-1-GO countdown, scale-pulse animation per tick.
- Vehicle controls locked (input ignored) until "GO" — enforce this in `vehicle_controller.gd`, not just visually.

## 5. Race HUD

**Layout zones (landscape assumed):**
- **Top-left:** position indicator ("3/12") + lap counter ("Lap 2/3")
- **Top-right or top-center:** minimap — simplified top-down map icon with player dot + opponent dots (color-coded by team for Duo/Squad)
- **Bottom-left:** virtual steering joystick (thumb zone)
- **Bottom-right:** item-use button (large, thumb zone) — shows held item icon; empty/greyed when no item held
- **Center-top (transient):** Chaos Event banner — slides in on `chaos_event_triggered`, shows event name + icon, auto-dismisses after ~2s
- **Center-top (transient, higher priority than chaos banner):** hit-reaction flash when local player is hit by an item (screen-edge color flash matching the item, e.g. red pulse for Reverse Gun)

**Team HUD addition (Duo/Squad only):** small team-score strip along one edge showing current aggregated team standings, updates on `TeamManager.team_score_updated`.

**Design constraint:** one-thumb driving is a core requirement — steering joystick and item button must both be reachable without repositioning the driving hand; do not require two-handed input for core loop actions.

## 6. Results / Podium Screen

**Layout:**
- Top 3 finishers on a podium visual with celebration animation (see `05_ANIMATIONS_SPEC.md`)
- Full ranked list below podium (scrollable if >3, relevant for FFA up to 16)
- **Duo/Squad:** team score breakdown panel — shows each team's aggregated score and the per-member contribution (e.g. "Team Blue: 1st + 4th = 5")
- Bottom-placement humiliation animation plays inline next to that player's row (small looping preview) or as a shared moment if the local player placed last
- XP/currency payout summary with a simple count-up animation
- "Rematch" (same lobby) and "Return to Menu" buttons

## 7. Shared UI Conventions

- Build a single `Theme` resource (`assets/ui/theme.tres`) and apply it project-wide — no per-scene ad-hoc styling.
- Icons: `.svg` source, imported directly by Godot; keep a consistent icon grid size (e.g. 64×64 export baseline).
- All interactive elements sized for thumb targets on mobile (minimum ~48×48pt equivalent).
- Localization-ready: all user-facing strings referenced via a translation key, not hardcoded literals, even if only one language ships at launch (item names already have French parentheticals in the design — plan for at least EN/FR from the start).

## 8. Related Docs

- `05_ANIMATIONS_SPEC.md` — celebration/humiliation animations referenced on Results screen
- `01_CORE_SYSTEMS_LOGIC.md` — GameManager phase signals driving screen transitions
