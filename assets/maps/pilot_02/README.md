# VIYA map pilot 02

User-supplied pilot PNGs, added only to `prologue_wall` in the default high-angle renderer following the user's explicit selection on 2026-11-24 KST. This is a pilot integration, with final art/mobile approval still pending.

The three PNGs are byte-identical to `textures/` inside `VIYA_map_pilot_02.zip` (SHA-256 `49557ccb6ed1efb40341004da82518438fe077aa8f25cdfad33598005637e24f`). The original `asset_manifest.json` is retained here as `source_manifest.json` for provenance; its candidate status and older checked HEAD describe the source handoff, not the current integration state.

Only `ruin_block`, `prop_urn` and `prop_debris` were appended to the existing prologue map overrides. Pilot 01's original three PNGs/bindings, all shared slots, other maps and the F8 comparison renderer remain as before. Existing camera and hidden respawn UI are retained.

Ruin front: RGB 192x130 at 96x65 screen units, using the existing world-anchored repeat and source/destination clipping. Existing top/geometry/occlusion/collision remain authoritative. Urn/debris: RGBA 92x86, drawn in the existing 46x43 canvas at bottom-center, preserving the original transparent padding. Both are living destructible props, not destroyed-state art. Original rubble, hit/flash, loot and 45 active-second respawn remain.

No preparation/generation script was executed, image bytes edited, external generation requested, or large source masters copied into the runtime asset directory.
