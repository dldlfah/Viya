# GAME070 — producer-accepted SW running

2026-11-28: the producer instructed `이대로 적용해` after the candidate04 review. This authorizes applying the existing result with its disclosed gait defects. The earlier technical rejection and all raw evidence remain historical records; this delivery does not claim those defects were repaired.

- Raw source: [candidate04](../../../../tools/higgsfield/requests/game070/evidence/packet_9927fcd/candidate_04.mp4) (repository path: `tools/higgsfield/requests/game070/evidence/packet_9927fcd/candidate_04.mp4`). SHA-256 `342c0358f79bdf15166734663e468e20c08198dbe8fe033f75bd7c7d5c52e1b4`.
- Seedance2.5 omni_reference; job `da27204a-f0a6-47ce-9831-a4b5481b8d36`. Requested4s/720p/3:4/audiofalse/count1. Actual RGB834×1112,24fps,97frames,4.041667s,no audio. Original inputs/options/quote/status/balance are preserved in the evidence folder.
- Selected zero-based source34..50, uninterrupted native frames. Source51 is the inspected next-motif boundary and is excluded. Native cycle708.333ms; engine nominal660ms, distance cycle155/235=659.574468ms. No retimed source video, interpolated poses, ping-pong or duplicated endpoint.
- 17 RGBA200×248 PNGs; fixed scale0.245, translation(-13,-9) for every frame; root(100,248), display69×85.56. No per-frame registration.
- Olive-green RGB background was keyed locally using inspected green dominance, nearest opaque paint at mixed boundaries and premultiplied bicubic registration. See `tools/higgsfield/prepare_game070.py` and black/gray/white boundary comparison. No paid background removal.
- Independent barrel-tip measurements and manually inspected projected boot-tip landmarks are in `provenance/`. Phase0.574866559295493 is fitted to opposite support anchors against S17. Maximum anchor residual77.647ms of nominal cycle remains; equal distance phase does not guarantee visually identical support or physical zero-slip across cameras.
- Known accepted motion defect: near-leg support is repeated within the native motif. The short15..26 trial was not used. Neither trimming nor metadata corrects the original leg sequencing. The fixed camera, costume, low two-handed carry and original full-body poses were retained.
- This application:0 new paid submissions/0 credits. Candidate04 cost28, GAME070 cumulative4 submissions/gross112/observed returned28/net84. Last observed account486 is historical, not a new balance query. No remaining generation allowance is assumed.

Only `run_sw11` is replaced; all other34clips331frames stay identical. Active composite35clips348frames. Existing E/SE/S moving-fire is preserved; SW dedicated moving-fire remains absent. `integration_manifest.json` records packing; actual execution evidence is in `docs/validation/GAME070_INTEGRATION_REPORT.json` after validation. Candidate visual application was explicitly approved; a later producer review of the in-game result and Windows/mobile/real-time performance are separate.

Reproduction (from repository root):

```bash
python tools/higgsfield/prepare_game070.py --video tools/higgsfield/requests/game070/evidence/packet_9927fcd/candidate_04.mp4 --out assets/characters/pilot_32/game070_sw_run --decoded-dir .local_validation/GAME070_RETRY04/source --start 34 --end 51 --scale .245 --tx -13 --ty -9
python tools/higgsfield/measure_game070.py
python tools/higgsfield/preview_game070.py
python tools/build_viya_game070.py
```

The art-only GIF uses quantized display timing; CSV, SpriteFrames and distance sampling are the playback authority. Static S/SW foot distances are projected image differences, not measured ground slip.
