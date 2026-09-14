# UI/UX Instructions — Crazy Racer v1.1

Baseline for this work: `STYLE_GUIDE.md` (palette, font, theme, component states) and `PROJECT_AUDIT.md` §7. All 6 current UI screens are single `Control` roots built entirely in code inside `_ready()`/`_build()` — **keep that pattern**, don't switch to hand-built `.tscn` scenes for new screens; it would break the project's consistency rule.

All new UI text stays in French, matching every existing screen (`COURSE`, `GRAND PRIX`, `CONTRE-LA-MONTRE`, etc.), unless a screen is explicitly meant to be language-agnostic (e.g. an OAuth provider's own consent screen, which the agent doesn't control).

## 1. Landing page (main menu) — progressive, page-per-page reveal

Current state (see the attached screenshot / `main_menu.gd`): title, subtitle, format toggles, circuit toggles, 3 mode buttons, private-salon row, records line, controls hint, and music toggle are **all visible at once** in one dense screen.

Target: split this into a small sequence of steps the player moves through, instead of one wall of buttons.

- Step 1 — **Title / brand**: `CRAZY RACER` + subtitle + primary call to action (`JOUER`) + secondary (`SE CONNECTER` / account entry point, see §3) + settings/music icon. Nothing else.
- Step 2 — **Mode select**: COURSE / GRAND PRIX / CONTRE‑LA‑MONTRE as the three big choices (this is the decision that determines what's asked next).
- Step 3 — **Format + circuit** (only for modes that need them — TT skips format): 1V1/DUO/SQUAD/FFA, then map choice. Keep these as toggle-button rows, styled per `STYLE_GUIDE.md` §3, just on their own step instead of sharing the screen with everything else.
- Step 4 — **Lobby entry**: private salon create/join (code field), records for the chosen mode/map, then the existing `lobby_screen.tscn` takes over.
- Persistent across all steps: back button (top-left), step indicator (dots or a thin progress bar — reuse the gold accent color for the active step), music toggle (top-right, same as today).

Implementation approach: this is still one `Control` root and one script (`main_menu.gd`) — build each "step" as a `Control`/`VBoxContainer` populated in a `_build_step(n)` function, `queue_free()`/hide the previous step's children and rebuild the next, with a short `modulate:a` fade (reuse the existing 0.25s fade pattern already used for UI transitions in `GameManager`) so steps don't hard-cut. Don't introduce a second UI framework or a state machine class for this — a single `current_step: int` var + a `match` block is consistent with the codebase's existing style (`const` lookup dictionaries, `match` blocks per `AI_AGENT_INSTRUCTIONS.md` §1).

## 2. Buttons & visual design fixes

From the audit (`PROJECT_AUDIT.md` §7.5, `STYLE_GUIDE.md` §3): the theme already defines normal/hover/pressed/disabled/focus states properly (this was a past fix). What's still rough, to address in this pass:

- Toggle buttons (format/map/ready) look identical when "selected" vs merely "hovered" (both use the hover style) — add a distinct **selected** visual: don't add a new global Button style (that would affect every button); instead apply a targeted `add_theme_stylebox_override("normal", ...)` on the toggled-on button instance, or a thin gold border/checkmark overlay, consistent with how `race_hud.gd` already does per-instance overrides for its item button states.
- 150+ inline `Color(...)` literals across UI scripts (`PROJECT_AUDIT.md` §7.4) — when you touch a screen for this redesign, pull its repeated colors into `scripts/ui/palette.gd` constants (create this file if it doesn't exist) rather than retyping literals; don't do a repo-wide sweep in the same change, just the screens you're already editing.
- No hex colors exist anywhere (confirmed) — keep using `Color(r,g,b,a)` construction, don't switch format.
- Respect the fixed `1280×720` `canvas_items`/`expand` stretch mode (`STYLE_GUIDE.md` §4) — anchor new elements to corners/center, don't hardcode pixel positions that only work at one aspect ratio.

## 3. In-game controller/HUD view during play

"Controllers view over the screen" = the touch joystick + drift/item buttons (`touch_joystick.gd`, wired in `race_hud.gd`) and the general HUD layout during `RACING`. Fix targets:

- Touch controls are corner-anchored today (joystick bottom-left, item button bottom-right) per `STYLE_GUIDE.md` §4 — keep that, but audit actual on-screen size vs. the 1280×720 canvas: touch elements sized for a phone viewport can visually dominate a desktop window. Scale touch-control size relative to viewport (e.g. a fraction of `min(viewport.x, viewport.y)`), and hide touch controls entirely when the last input device was keyboard/gamepad (the game already tracks "bascule auto/manuel selon le dernier périphérique touché" per `LIREMOI-JOUER.md` §3 — reuse that same detection to also toggle touch-control **visibility**, not just the AUTO/manual accel mode).
- Keep HUD elements (position/lap top-left, minimap/standings top-right) clear of the chase-camera's action area — nudge margins in from the true screen edge (e.g. 24–32px) rather than flush against it, since flush-edge HUD gets clipped on some aspect ratios under `expand` stretch mode.

## 4. Countdown (3‑2‑1)

Note for whoever scoped this: a countdown already exists — `countdown_overlay.tscn`/`.gd`, fixed `3.5s`, shows `3‑2‑1‑GO` plus the rocket-start hint (hold throttle during countdown = turbo start), per `GAMEPLAY_RULES.md` §5 and `PROJECT_AUDIT.md` §7.1. This pass is a **polish/verify**, not a from-scratch build:

- Confirm it's visually prominent against the new HUD/controller layout from §3 (it should sit above touch controls in z-order, unaffected by their new visibility toggle).
- Reuse the existing color set: gold `(1,0.88,0.3)` for "1", red-ish `(1,0.4,0.4)` for "3", green `(0.3,1,0.4)` for "GO!" (`STYLE_GUIDE.md` §1) — don't invent new countdown colors.
- If you want extra juice (scale-punch on each number, screen-shake-free), add it inside `countdown_overlay.gd`'s existing per-number tween, don't add a new node type.

## 5. Login / account creation

New phase, gates entry to online-only features (leaderboard submission, saved cloud profile) but **must not** block local/offline quick-play (`AI_AGENT_INSTRUCTIONS.md` "Before finishing any task"). Backend: see `AGENT_MEMORY_THINKING.md` / `MAP_ENVIRONMENT_INSTRUCTIONS.md` cross-refs — recommended stack is **Supabase Auth** via the community `godot-engine.supabase` addon (handles email/password, email OTP/verification codes, and Google/Discord OAuth in one API surface, so the client never touches raw credentials or tokens directly).

Screens to add (same code-built `Control` pattern as everything else):

1. **Entry gate**: `SE CONNECTER` / `CRÉER UN COMPTE` / `CONTINUER SANS COMPTE` (guest → local-only, current behavior).
2. **Sign up**: email + password fields, `S'INSCRIRE` button → triggers Supabase `sign_up`, then routes to step 3.
3. **Email verification**: 6-digit code field (Supabase email OTP), `VALIDER` + `RENVOYER LE CODE` (respect provider rate limits, disable resend for ~60s with a visible countdown, reusing this doc's countdown-number style).
4. **Sign in**: email + password, plus two social buttons — `Continuer avec Discord` / `Continuer avec Google` (OAuth via the same addon). Style social buttons as their own `StyleBoxFlat` variant (brand-neutral navy panel is fine — don't paste raw brand-color buttons that clash with the game's magenta/navy palette; a small provider icon + the existing button font is enough).
5. **Forgot password**: standard reset-via-email flow (Supabase built-in).

Error/loading states: reuse the disabled-button pattern already in the theme (`STYLE_GUIDE.md` §3 `styles/disabled`) while a request is in flight, and a small inline red `(1,0.4,0.4)` text line under the form for errors — don't use popups/dialogs, nothing in this codebase uses them today.

## 6. Leaderboard / ranking display

Applies to results screen and to a new dedicated leaderboard screen (accessible from the landing page once logged in).

Formatting rules (exact):

```
🥇 Player #ranked_1
🥈 Player #ranked_2
🥉 Player #ranked_3
4. Player #ranked_4
5. Player #ranked_5
6. Player #ranked_6
7. Player #ranked_7
8. Player #ranked_8
9. Player #ranked_9
10. Player #ranked_10
```

- Always render exactly the top 10 in this format (medal emoji for 1–3, `N.` prefix for 4–10).
- If the current logged-in user is **not** in the top 10, append one more line below the list, separated by a small gap, in the same `N. Player #rank` format but using the user's own rank number (e.g. `47. Player #ranked_47`) — visually distinguished (e.g. gold-outlined row or the "local player" highlight color already used in HUD standings, `STYLE_GUIDE.md` gold role) so it reads as "your position" rather than a fake 11th place.
- If the user **is** in the top 10, don't duplicate their row below.

Team mode (2 or 4 per team): replace the single player name with the **team name** if one was set; otherwise join the member names with `|`, e.g. `Player1|Player2` (DUO) or `Player1|Player2|Player3|Player4` (SQUAD). Everything else about the row (medal/number prefix, rank) is unchanged.

Data source: this needs the same backend as auth (Supabase `Database`, a `leaderboard`/`profiles` table keyed by user id) — see `AGENT_MEMORY_THINKING.md` for how to scope that as its own task rather than bolting it onto the UI change.
