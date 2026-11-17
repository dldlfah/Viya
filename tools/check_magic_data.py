#!/usr/bin/env python3
"""Data and source-contract audit only. This NEVER simulates Godot or proves gameplay."""
from __future__ import annotations
import copy
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
NUMERIC = ('max_mana', 'mana_cost', 'mana_regen', 'cooldown', 'damage',
           'damage_per_rank', 'radius', 'radius_per_rank', 'effect_duration')
POSITIVE = ('max_mana', 'mana_cost', 'cooldown', 'damage', 'radius', 'effect_duration')


def validate(data: dict) -> list[str]:
    errors = []
    for owner, hero in data.get('characters', {}).items():
        skills = data.get('common', []) + hero.get('skills', [])
        for skill in skills:
            if not str(skill.get('name', '')).startswith('[임시] '):
                errors.append(f'{owner}: unmarked skill name: {skill.get("id")}')
        magic = hero.get('active_magic')
        if not isinstance(magic, dict):
            errors.append(f'{owner}: missing active magic')
            continue
        if magic.get('owner') != owner or magic.get('effect') != 'radial_burst':
            errors.append(f'{owner}: magic owner/effect mismatch')
        if not magic.get('prototype') or not str(magic.get('name', '')).startswith('[임시] '):
            errors.append(f'{owner}: unmarked magic')
        upgrades = {s['id'] for s in hero.get('skills', []) if s.get('kind') == 'ultimate' and s.get('effect') == 'ultimate'}
        if magic.get('upgrade_skill_id') not in upgrades:
            errors.append(f'{owner}: wrong magic enhancement binding')
        valid_numbers = True
        for key in NUMERIC:
            value = magic.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                errors.append(f'{owner}: invalid {key}')
                valid_numbers = False
            elif key in POSITIVE and value <= 0:
                errors.append(f'{owner}: nonpositive {key}')
                valid_numbers = False
        if valid_numbers and magic['mana_cost'] > magic['max_mana']:
            errors.append(f'{owner}: impossible mana cost')
    return errors


def check() -> dict:
    data = json.loads((ROOT / 'data/prototype_skills.json').read_text(encoding='utf-8'))
    errors = validate(data)
    negative = []
    for change in ('plain_name', 'foreign_owner', 'missing_magic', 'negative_cost',
                   'zero_cooldown', 'wrong_upgrade', 'nonfinite_radius', 'impossible_cost'):
        broken = copy.deepcopy(data)
        hero = broken['characters']['viya']
        if change == 'plain_name':
            broken['common'][0]['name'] = '소총'
        elif change == 'foreign_owner':
            hero['active_magic']['owner'] = 'other'
        elif change == 'missing_magic':
            del hero['active_magic']
        elif change == 'negative_cost':
            hero['active_magic']['mana_cost'] = -1
        elif change == 'zero_cooldown':
            hero['active_magic']['cooldown'] = 0
        elif change == 'wrong_upgrade':
            hero['active_magic']['upgrade_skill_id'] = 'viya_sigil'
        elif change == 'nonfinite_radius':
            hero['active_magic']['radius'] = float('nan')
        else:
            hero['active_magic']['mana_cost'] = 101
        rejected = bool(validate(broken))
        negative.append({'fixture': change, 'rejected': rejected})
        if not rejected:
            errors.append(f'negative control accepted: {change}')
    growth = (ROOT / 'scripts/progression/growth_state.gd').read_text(encoding='utf-8')
    multiplier = re.search(r'^const XP_REQUIREMENT_MULTIPLIER := (\d+\.\d+)', growth, re.M)
    if not multiplier or float(multiplier.group(1)) != 3.0:
        errors.append('XP requirement multiplier must be 3.0')
    if 'return (10.0 + float(level - 1) * 6.0) * XP_REQUIREMENT_MULTIPLIER' not in growth:
        errors.append('unexpected threshold formula')
    sources = {f: (ROOT / f).read_text(encoding='utf-8') for f in (
        'scripts/combat/run_state.gd', 'scripts/combat/magic_state.gd',
        'scripts/main.gd', 'scripts/combat/battle_view.gd', 'tools/check_project.py')}
    markers = {
        'scripts/combat/run_state.gd': ['magic.consume(expected_ticket, phase == Phase.RUNNING',
            'magic.owner_id != growth.character_id', 'magic.advance(dt, true)',
            '_burst(player, float(cast["radius"]), float(cast["damage"]), "ultimate")',
            'value: float = 5.0'],
        'scripts/combat/magic_state.gd': ['expected_ticket != ticket', 'invalidate_requests()',
            'if not running or config.is_empty()', 'mana = maxf(0.0, mana -'],
        'scripts/main.gd': ['magic_button.pressed.connect(_cast_magic)', 'InputEventScreenTouch',
            'InputEvent.DEVICE_ID_EMULATION', 'magic_button.disabled = not reason.is_empty()',
            '[임시]', 'mana_bar.value = magic.mana'],
        'scripts/combat/battle_view.gd': ['effect["kind"] == "ultimate"', 'effect.get("duration", 0.25)'],
        'tools/check_project.py': ['res://tests/test_magic.gd', 'check_magic()', "code = 2"],
    }
    for path, required in markers.items():
        for marker in required:
            if marker not in sources[path]:
                errors.append(f'{path}: missing contract marker {marker}')
    return {'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'negative_controls': negative, 'temporary_skill_names': 18,
            'required_xp_first_five': [30, 48, 66, 84, 102],
            'xp_drop_unchanged': 5.0,
            'scope': 'JSON validation, negative data controls and source markers/arithmetic; NOT GDScript runtime, UI, input dispatch or mobile tests.'}


if __name__ == '__main__':
    result = check()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
