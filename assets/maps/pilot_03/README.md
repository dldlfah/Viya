# VIYA map pilot 03

Three user-supplied pilot PNGs, connected only to prologue_wall following the explicit user selection on 2026-11-24 KST. Final art and physical mobile approval remain separate.

The prepared PNG files are byte-identical to textures/ inside VIYA_map_pilot_03.zip (SHA-256 887357f23b29a1226d6d49190fd58de113ea67039be75fa09be22cd411e60864). The original asset_manifest.json is preserved as source_manifest.json for provenance; its integration-pending status describes the handoff, not the later game integration.

wall_top_tile and ruin_top_tile are opaque192x160 top-down materials repeated on a global96x80 world grid. The existing ground projection is applied once, producing96x69.282 screen tiles. Destination and corresponding source regions are clipped to the original top rectangle and viewport. Existing heights122/65, front textures, borders, depth sorting, occlusion and collision remain.

gate_front is opaque480x228, drawn once in the existing240x114 vertical front rectangle. Bottom-center anchor is world2500,420; no extra ground compression, opening, collision, animation or gate HP is introduced. Existing border/torches remain; missing textures retain original primitive fills.

Pilot01/02's six bindings and PNGs, shared53blank paths, other maps/F8, stable camera, hidden respawn UI, loot/45active-second regeneration and SAVE18 remain. No preparation/generation script was executed, large masters copied, images edited or paid service called.
