# VIYA map pilot 01

User-supplied pilot materials, enabled only for `prologue_wall` in the default
high-angle renderer. Pilot integration was requested on 2026-11-24 KST; final
art approval and physical mobile validation remain separate.

The three PNG files are byte-identical to `textures/` in the uploaded
`VIYA_map_pilot_01.zip` (archive SHA-256
`6c200744a153aff6f99f107443b1efc5d3e6e373ee164a95568ccfc5d9cb7ab9`).
Their dimensions and SHA-256 hashes are retained in `source_manifest.json`.
The uploaded preparation script was not executed and the images were not
regenerated, recolored or cropped. Original masters and generation logs remain
in the uploaded archive rather than the game's runtime asset directory.

`data/map_presentation_slots.json` selects the three textures for the pilot map.
Shared presentation slots and character art stay unchanged. The F8 comparison
renderer keeps its existing procedural map graphics.

Floor: 224x160 pixels, drawn at 112x80 world units before the existing ground
projection. Wall: 192x244, repeated at 96x122 screen units on the existing front
face, with the procedural top and occlusion alpha retained. Crate: 92x86 RGBA,
drawn at 46x43 with its original transparent padding and bottom-center pivot.
Destroyed crates use the original broken prop drawing.
