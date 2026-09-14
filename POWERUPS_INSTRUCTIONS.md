# Powerups Instructions — Crazy Racer v1.1

The item system itself isn't part of the requested scope this cycle (no new items were asked for), but two of the changes in this update touch things items depend on — this doc exists so those changes don't quietly regress the 14-item pipeline.

Baseline: `GAMEPLAY_RULES.md`/`LIREMOI-JOUER.md` §5 (14 items: Banane, Triple Banane, Champignon, Triple Champi, Carapace Verte, Carapace Rouge, Bouclier, Étoile, Foudre, Pistolet Inverseur, Rayon Réducteur, Pluie de Poulets, Banana Super Boost, Rocket Pingouin), `AI_AGENT_INSTRUCTIONS.md` §0 ("Item effects are hardcoded... the `match` block is the pipeline").

## Guardrails while doing the vehicle/physics/UI work

- **Vehicle asset swap (`PHYSICS_MOVEMENT_INSTRUCTIONS.md` §1)**: several items reshape or reposition the vehicle/driver (Rayon Réducteur → mini-pig shrink, Rocket Pingouin → penguin rebuild, shrink/reverse steering effects). When you swap a vehicle's mesh, confirm these item effects still find the anchors they expect (`ItemHoldAnchor`, `BoostTrailAnchor`, `DriftTrailAnchorL/R` are `Marker3D` nodes on the vehicle scene, not the mesh — they should be unaffected by a visual-only swap, but verify each item still visually lines up once the new model is in).
- **Motorcycle tip-over risk (`PHYSICS_MOVEMENT_INSTRUCTIONS.md` §2)**: this reuses the existing >1.3-knockback spin-out code path. Make sure a self-triggered tip-over doesn't double-stack with an item-caused spin-out (e.g. getting hit by a shell while already destabilized) in a way that produces an unfair chain-stun — cap combined stun duration the same way knockback already presumably caps today, don't add a second uncapped timer.
- **Animal locomotion (`PHYSICS_MOVEMENT_INSTRUCTIONS.md` §3)**: the Rayon Réducteur item already rebuilds the driver into a "mini-cochon" — if you add a reactive-movement layer to animal drivers, make sure the shrink-ray's driver rebuild either inherits or gracefully skips it, rather than the mini-pig ending up with a broken/oversized lean applied at the wrong scale.

## If a future task *does* add new items

Not requested this cycle, but for consistency if it comes up: new items are new `ItemData` `.tres` resources (`assets/resources/*.tres`) plus a new branch in `ItemSystem._apply_to`'s `match` block — never a new `effect_script_path`/external-script pattern (that pattern was deliberately removed as dead code, see `AI_AGENT_INSTRUCTIONS.md` §0). Reuse `VfxFactory`'s existing per-kind-color burst pattern for any new visual effect (`STYLE_GUIDE.md` §5).
