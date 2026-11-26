#!/usr/bin/env python3
"""GAME-004B changed-source checks only; no GDScript execution or rendering.
This does not replace check_project.py or the actual test_mobile_hud.gd suite.
"""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    'scenes/main.tscn', 'scripts/ui/mobile_main.gd', 'scripts/ui/hud_layout.gd',
    'scripts/ui/responsive_feedback_panel.gd', 'scripts/ui/move_input.gd',
    'tests/test_mobile_hud.gd', 'tools/check_project.py', 'tools/check_mobile_hud.py',
)


def body(source: str, name: str) -> str:
    match = re.search(r'^func ' + re.escape(name) + r'\([^\n]*\).*?:\n(.*?)(?=^func |\Z)',
                      source, re.M | re.S)
    return match.group(1) if match else ''


def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    ui = sources['scripts/ui/mobile_main.gd']
    move = sources['scripts/ui/move_input.gd']
    layout = sources['scripts/ui/hud_layout.gd']
    runner = sources['tools/check_project.py']
    scene = sources['scenes/main.tscn']
    for text, source in (
        ('extends "res://scripts/main.gd"', ui),
        ('res://scripts/ui/mobile_main.gd', scene),
        ('HudLayout.build(root_ui.size, _safe_rect())', ui),
        ('_place(view, layout_data["battle"])', ui),
        ('movement.set_interaction_rect(local_to_move * layout_data["move"])', ui),
        ('get_screen_transform().affine_inverse() * physical', ui),
        ('get_global_transform_with_canvas().affine_inverse() * at', move),
        ('region.has_point(_local_position(at))', move),
        ('button.pressed.connect(_open_owned_detail.bind(row_id, index))', ui),
        ('_choice_grid.columns = int(layout_data["card_columns"])', ui),
        ('ScrollContainer.SCROLL_MODE_AUTO', ui),
        ('"card_columns": 3 if modal_width >= 850.0 else 1', layout),
        ('res://tests/test_mobile_hud.gd', runner),
    ):
        if text not in source:
            errors.append('missing integration: ' + text)
    detail = body(ui, '_open_skill_detail')
    close = body(ui, '_close_skill_detail')
    if 'simulation.set_paused(true)' not in detail or 'movement.set_enabled(false)' not in detail:
        errors.append('read-only detail must pause the existing simulation and release movement')
    if 'super.resume_game()' not in close or 'not _detail_open' not in close:
        errors.append('detail close must be guarded and restore the existing resume path')
    for forbidden in ('select_skill(', 'growth.select(', 'growth.reset(', 'growth.open_offer(', 'cast_ultimate('):
        if forbidden in detail or forbidden in close:
            errors.append('detail must not change skills/offers or cast: ' + forbidden)
    if '130.0' in move or 'size.y - 174.0' in move or 'size.x * 0.32' in move:
        errors.append('old hard-coded movement hit area returned')
    if 'clear_input()' not in body(move, 'set_interaction_rect'):
        errors.append('resizing must cancel the held movement finger')
    if 'super._notification' in ui:
        errors.append('Godot automatically dispatches inherited notifications; do not call super twice')
    if 'RunState.new()' in ui or 'Growth.new()' in ui or 'MagicState.new()' in ui:
        errors.append('presentation adapter must not create a second authoritative simulation')
    return errors


def check() -> dict:
    sources = {name: (ROOT / name).read_text(encoding='utf-8') for name in FILES}
    # Reuse the real existing delimiter checker without importing its unrelated
    # full-project dependencies. This is still not a GDScript parser.
    parsed = ast.parse(sources['tools/check_project.py'])
    node = next(x for x in parsed.body if isinstance(x, ast.FunctionDef) and x.name == 'check_delimiters')
    namespace: dict = {}
    exec(compile(ast.Module(body=[node], type_ignores=[]), 'check_delimiters', 'exec'), namespace)
    errors = validate(sources)
    hashes: dict[str, str] = {}
    for name, text in sources.items():
        hashes[name] = hashlib.sha256(text.encode('utf-8')).hexdigest()
        try:
            if name.endswith(('.gd', '.tscn')):
                namespace['check_delimiters'](text)
            elif name.endswith('.py'):
                ast.parse(text, filename=name)
            for line, value in enumerate(text.splitlines(), 1):
                if value.rstrip() != value:
                    errors.append(f'{name}:{line}: trailing whitespace')
                if name.endswith('.gd') and value.startswith(' '):
                    errors.append(f'{name}:{line}: non-tab indentation')
        except (SyntaxError, ValueError) as error:
            errors.append(f'{name}: {error}')
    negatives = []
    for fixture in ('layout_detached', 'detail_not_paused', 'detail_mutates_skill', 'resize_retains_touch', 'test_not_registered'):
        broken = dict(sources)
        name = 'scripts/ui/mobile_main.gd'
        if fixture == 'layout_detached':
            broken[name] = broken[name].replace('_place(view, layout_data["battle"])', 'pass')
        elif fixture == 'detail_not_paused':
            broken[name] = broken[name].replace('simulation.set_paused(true)', 'pass')
        elif fixture == 'detail_mutates_skill':
            broken[name] = broken[name].replace('\t_detail_open = true', '\tsimulation.select_skill(id, 0)\n\t_detail_open = true')
        elif fixture == 'resize_retains_touch':
            name = 'scripts/ui/move_input.gd'
            broken[name] = broken[name].replace('\tclear_input()\n\t_region_configured', '\t_region_configured')
        else:
            name = 'tools/check_project.py'
            broken[name] = broken[name].replace('res://tests/test_mobile_hud.gd', 'res://tests/missing.gd')
        rejected = bool(validate(broken))
        negatives.append({'fixture': fixture, 'rejected': rejected})
        if not rejected:
            errors.append('negative control not rejected: ' + fixture)
    return {'status': 'FAIL' if errors else 'PASS', 'files_checked': len(FILES),
            'errors': errors, 'negative_controls': negatives, 'source_sha256': hashes,
            'source_fingerprint': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
            'scope': 'Changed UTF-8 files, delimiters, Python syntax and integration source checks only. '
                     'NOT GDScript parsing/typechecking, actual Control geometry, touch dispatch, rendering or mobile execution.'}


if __name__ == '__main__':
    try:
        result = check()
    except (OSError, ValueError, StopIteration, SyntaxError, KeyError) as error:
        result = {'status': 'FAIL', 'error': str(error)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result['status'] == 'PASS' else 1)
