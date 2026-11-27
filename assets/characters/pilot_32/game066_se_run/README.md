# GAME066 — southeast run

Replaces only the existing southeast run (11 frames) with 18 unique consecutive new frames. Preserves all other 32 animations, the original 208, ARTFIX001, GAME064 E run and GAME065 E moving-fire.

Source frames: Seedance 2.5 video_edit job a9ab0954-f528-4194-b8c1-3cb8954dd02c, source indices 36..53, 24 FPS; frame54 excluded as next-cycle equivalent. Previous Genjutsu ee75ff39-7354-4f8e-a6fb-df30c4eeae46 was rejected due to side-view drift.

Frames: 200x248 transparent RGBA PNG; fixed scale .231, translation [1.20,-1.40], pivot [100,248], display 69x85.56. Native source stride 18 frames/24 FPS = 750ms, retimed to 660ms for 155 world units at speed235. The existing SE gait phase origin 3/11 is preserved. No copied poses, ping pong or added synthetic limbs. Per-frame muzzle stored in provenance metadata.

Build: python3 tools/build_viya_game066.py
QA: docs/validation/GAME066_INTEGRATION_REPORT.json. Godot 4.7.2 regression 465 checks PASS. Actual Godot X11 SE renderer captured 198 frames / 5 cycles, observed all 18 distinct frame indices.
Cost: rejected28 + selected30 =58 credits, verified balance815.25. No purchase or automatic charge.
Open: final user art approval, Windows/mobile hardware, realtime FPS, full-game QA.
