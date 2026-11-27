# VIYA — next single production unit

GAME066 SE full-body run is technically complete in the work branch. 18 unique RGBA frames on a fixed 200x248 canvas replace SE run11, nominal cycle660ms. Godot4.7.2 regression465 PASS and actual X11 SE renderer198 frames / 5 cycles PASS. User's final art approval and hardware FPS are separate. See docs/validation/GAME066_INTEGRATION_REPORT.json.

## Next: GAME067 SE moving fire

Create a true full-body southeast running-while-aiming/firing loop on the same southeast camera and original character identity. Use the accepted GAME066 SE run as gait reference and preserve its current run phase; do not rotate E pose or duplicate generic running frames. No baked flashes/bullets; game owns shot effects. Deliver registered transparent PNG frames, exact timings, separate per-frame muzzle and actual engine run/fire switches, stop/turn/reverse/pause checks. Retain other 32 poses, original 208, ARTFIX001, GAME064/GAME065, SAVEFIX001, save22, 7 RNG streams. Read current model pricing/balance before billed generation; no purchase or auto-recharge. Only mark art approval after user's actual approval.

Other open items: Windows/mobile hardware QA, 1540-actor performance, economy and full first-stage finish.
