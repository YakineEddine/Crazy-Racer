# Style Guide — Crazy Racer

Source of truth for UI/visual work. Values below are the *actual current* project state (from a full-code audit), not placeholders — treat this as the baseline to preserve or deliberately improve, not to rediscover from scratch. Supersedes `04_UI_UX_SPEC.md`/`06_VFX_SPEC.md` if those still exist in the repo — those describe an unbuilt design, this describes what's actually shipped.

## 1. Color Palette (currently in use)

The project has no centralized palette — these are the colors already repeated across scenes/scripts. Reuse these before introducing anything new.

| Role | Color | Where used |
|---|---|---|
| Brand / accent (magenta-pink) | `Color(1, 0.18, 0.53)` | Button hover/pressed style, countdown/HUD accents, map1 wall color, joystick knob |
| Panel background (navy) | `Color(0.12, 0.14, 0.3)` | Button normal style |
| Menu background gradient | `Color(0.1, 0.06, 0.24)` → `Color(0.02, 0.02, 0.08)` | Main menu vertical gradient |
| Gold (titles/records/best) | `Color(1, 0.88, 0.3)` | Menu title, records label, countdown "1", results title, HUD local-player standings |
| Sky blue (subtitles) | `Color(0.7, 0.9, 1)` | Menu subtitle, HUD time text |
| Muted gray-blue (hints) | `Color(0.7, 0.7, 0.8)` | Menu hint text |
| Success green | `Color(0.3, 1, 0.4)` | Lobby "ready" dot, countdown "GO!" |
| Warning red | `Color(1, 0.4, 0.4)` / `Color(1, 0.2, 0.2)` | Countdown "3", hit-flash |
| Coin/collectible yellow | `Color(1, 0.85, 0.2)` / `Color(1, 0.9, 0.2)` | Coin HUD text, coin pickups, confetti |
| Item icon colors | reverse `(1,0.2,0.2)`, shrink `(0.4,0.6,1)`, chicken `(1,1,1)`, banana `(1,0.9,0.2)`, rocket `(0.3,0.9,1)` | Item icon button + HUD flash |
| Chaos event banner colors | gravity `(0.6,0.3,1)`, meteor `(1,0.4,0.1)`, collapse `(0.3,0.8,0.2)`, dino `(1,0.2,0.2)` | HUD chaos banner |

Rule: no new hex/RGB value for a role already covered above — reuse it. If consolidating, extract these into named `const` in a shared script (e.g. `scripts/ui/palette.gd`) rather than retyping `Color(1,0.88,0.3)` in 6+ files.

## 2. Typography — current state

- Display font: `assets/fonts/TitanOne-Regular.ttf` (**Titan One Regular**, SIL OFL 1.1, see `assets/fonts/OFL.txt`), wired as the theme's `default_font` in `assets/ui/theme.tres` — every `Button`/`Label` on all 5 UI scenes (plus `Label3D` nametags) inherits it automatically. Chunky rounded poster face for the party-kart tone; verified in-engine to resolve on menu, lobby, countdown, HUD, and results.
- Coverage: French diacritics (`é è ê à ç`), `«»`, `•`, digits/colon all present in the font (verified via cmap). Arrows (`↑↓←→`), `✓`, `♪`, and emoji are **not** in the font — they render through the font import's `allow_system_fallback=true` path (system fonts), exactly as emoji already did when everything used the default font. No regression, just a documented gap.
- The old empty `FontVariation font_main` sub-resource is removed — it was unassigned and did nothing.
- Sizes are still set per-widget in code via `add_theme_font_size_override`, not from the theme (theme only sets `default_font` + global `default_font_size=22`). Current sizes in use: menu title `54`, HUD position `30`, countdown number `160`, results title `40`, coin/lap HUD `17-24`, hints/labels `14-20`.
- `Label3D` nametags above vehicles use `font_size=96`, `outline_size=16`, `pixel_size=0.01`.
- Rule: don't set font per-Label in code — the theme default covers every screen.

## 3. UI Components — current state

`assets/ui/theme.tres` defines, for `Button` only (all corners 12px, margins 20/20/12/12):
- `styles/normal` → navy `StyleBoxFlat`
- `styles/hover` → magenta-pink `StyleBoxFlat`
- `styles/pressed` → deep magenta-pink `StyleBoxFlat` (`0.65, 0.12, 0.34` = hover darkened — distinct press feedback, same family)
- `styles/disabled` → muted navy-gray `StyleBoxFlat` (`0.22, 0.24, 0.36`) + `colors/font_disabled_color` gray-lavender (`0.6, 0.62, 0.7`) — `lobby_screen.gd`'s start button and `race_hud.gd`'s item button now read as inactive instead of engine-default
- `styles/focus` → transparent `StyleBoxFlat` with 3px magenta border — keyboard/gamepad focus ring (magenta-on-navy; over a magenta hover it yields to the hover fill, which already signals the button)
- `font_sizes/font_size = 22` for `Button`/`Label` (+ theme `default_font`/`default_font_size`, see §2)

Toggle buttons (format select, map select, ready) use `toggle_mode = true` — same normal/hover/pressed styling applies, so a "selected" toggle looks identical to a "hovered" one.

## 4. Layout patterns (as currently built)
- Every UI scene is a single `Control` root built entirely in `_ready()`/`_build()` — no child nodes saved in the `.tscn` files. Follow this pattern for new UI rather than hand-building nodes in the editor, to stay consistent with the rest of the codebase.
- HUD elements are anchor-positioned relative to screen corners (e.g. position/lap top-left, minimap/standings top-right, item button bottom-right, joystick bottom-left) — keep this corner-anchored layout for any new HUD element so it scales across the fixed 1280×720 `canvas_items`/`expand` stretch mode.

## 5. Effects (VFX) — current state
- One shader in the project: `shaders/gravity_flip.gdshader` (canvas_item, used for the HUD gravity-inversion overlay tint, `tint=vec4(0.55,0.3,1.0,0.25)`, subtle sine wobble).
- All other particle effects are runtime-only `GPUParticles3D`/`CPUParticles3D` via `VfxFactory` (per-kind colors: boost orange, reverse red, shrink blue, chicken white, rocket orange, meteor red-orange, collapse gray) — 48 particles/0.8s life on HIGH quality, 24/0.8s on LOW. `VfxFactory.particle_quality` is a static var hardcoded to `HIGH`; the LOW branch exists but is never reachable from any UI (no graphics-quality setting exists yet — see `GAMEPLAY_RULES.md` §4).
- Drift sparks: orange `(1.0,0.45,0.1)` at high charge, blue `(0.3,0.6,1.0)` at low charge, 0.25s life.
- Results screen confetti: `CPUParticles2D`, gold `(1,0.85,0.25)`, 160 particles, 2.5s life.
- Rule: any new effect should use `VfxFactory`'s existing pattern (one static burst function, color keyed by effect name) rather than a bespoke particle setup per call site.
