# Agent Memory & Thinking Instructions — Crazy Racer v1.1

This doc is about *process*, not gameplay/visuals — how any AI coding agent (Claude Code, OpenCode, Cursor, etc.) working on this repo should scope tasks, keep its own state straight across sessions, and leave a trail the next agent (or the human) can trust. It complements `AI_AGENT_INSTRUCTIONS.md`, which is about the codebase itself.

## 1. This update cycle is six separate tasks, not one

Do not attempt the landing-page redesign, the auth system, the vehicle asset swap, the motorcycle/animal physics, and the leaderboard in a single sitting or a single commit. Each has its own companion doc and its own prompt in `PROMPTS.md`. Work one at a time, in this order (each is easier once the previous one exists):

1. **Vehicle asset swap** — lowest risk, no new systems, mostly data + one existing pipeline extended.
2. **Motorcycle instability + animal locomotion** — physics-only, no new dependencies.
3. **Landing page / UI redesign + countdown/controller-view polish** — UI-only, no backend needed yet.
4. **Auth (Supabase)** — first task that introduces an external dependency; do this before the leaderboard, since the leaderboard needs a logged-in user id.
5. **Leaderboard display** — depends on 4.
6. **Map/environment asset integration** (if/when tackled — see `MAP_ENVIRONMENT_INSTRUCTIONS.md`) — independent of the rest, can be slotted in anywhere.

Before starting any one of these, re-state (to yourself, in a comment or a short PLAN.md, or out loud to the user) which single task you're doing and what "done" looks like for it. Don't let scope creep from one task's companion doc bleed into another task's diff.

## 2. Before writing code: re-read, don't re-derive

`PROJECT_AUDIT.md` is a literal, verified snapshot of the codebase at the time it was generated — treat every specific number, path, and behavior in it as ground truth *for that snapshot*, not as something to re-verify from first principles or guess at. But it goes stale the moment code changes. Practical rule:

- If you're about to state a fact about the current codebase (a mass value, a color, a file path, whether something is dead code) — check whether `PROJECT_AUDIT.md` / `GAMEPLAY_RULES.md` / `STYLE_GUIDE.md` already answers it before grepping the code yourself. They usually do, and re-deriving it independently risks a subtly different (wrong) number making it into a change.
- If your change makes any of those three docs inaccurate (new vehicle stat field, new color, new persisted setting, new autoload), **update the doc in the same change** — this is already the rule in `AI_AGENT_INSTRUCTIONS.md` §6, restated here because it's the single most common way agent-driven repos rot: code and docs drift apart until neither is trustworthy.
- Once this whole update cycle is done, re-run/re-generate `PROJECT_AUDIT.md` (or ask an agent to redo the literal-inspection pass that produced it) so it reflects the new baseline — don't hand-patch it piecemeal, regenerate it wholesale the same way it was originally produced.

## 3. Leave a decision trail, not just a diff

For any non-obvious choice (which backend, which lean-angle formula, why a stat got a particular default), leave a one-paragraph rationale either in the commit message or as a short comment near the code — not because the codebase needs comments everywhere, but because the next agent (possibly you, in a new session with no memory of this conversation) needs to know *why*, not just *what*, especially for anything flagged as tunable/needs-playtesting in the companion docs above.

Known open questions in this update cycle that should **not** be silently resolved by an agent — flag them back to the user instead, the same way the original `README.md`'s "Known Open Questions" section did:
- Exact motorcycle tip-over threshold/penalty numbers (needs playtesting, not a one-shot guess).
- Whether guest (no-account) players ever appear on the online leaderboard, or only logged-in players do.
- Whether OAuth-linked accounts (Discord/Google) that share an email with an existing email/password account should be merged or kept separate.
- Final choice of `.glb` vs `.fbx` for the custom vehicle exports, if not already decided by the user.

## 4. Session handoff

If you're an agent that can only see this conversation and not prior sessions' internal state: assume nothing about what's already been built beyond what's actually in the repo/diff in front of you. Don't trust a previous session's summary of "I already did X" over what the files on disk actually show — verify by reading the relevant file before building on top of a claimed prior change. This mirrors the general rule that a prior session's work is not authorization to skip re-checking the current state.
