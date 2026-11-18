#!/usr/bin/env python3
"""Validate catalog and integration contracts; does NOT execute GDScript behavior."""
from __future__ import annotations
from collections import Counter
from pathlib import Path
import copy
import json
import re

ROOT = Path(__file__).resolve().parents[1]
ATTACK_EFFECTS = {'rifle', 'scatter', 'lance', 'grenade', 'pulse', 'crossfire', 'chain', 'heavy'}
PASSIVE_EFFECTS = {'power', 'haste', 'vitality', 'stride', 'magnet', 'learning', 'precision', 'recovery'}

def validate(data: dict) -> list[str]:
    errors: list[str] = []
    common = data.get('common', [])
    if Counter(x.get('kind') for x in common) != {'attack': 8, 'passive': 8}:
        errors.append('common must contain exactly 8 attacks and 8 passives')
    for name, hero in data.get('characters', {}).items():
        unique = hero.get('skills', [])
        if Counter(x.get('kind') for x in unique) != {'character': 1, 'ultimate': 1}:
            errors.append(f'{name}: missing two unique skill types')
        pool = common + unique
        ids = [x.get('id') for x in pool]
        if len(pool) != 18 or len(set(ids)) != 18 or not all(ids):
            errors.append(f'{name}: invalid/duplicate skill IDs or count')
        for x in pool:
            owner = name if x in unique else ''
            if x.get('owner') != owner:
                errors.append(f'{name}: foreign owner')
            if not x.get('prototype') or x.get('max_level', 0) <= 0:
                errors.append(f'{name}: unmarked or invalid prototype')
            expected_row = 'attack' if x['kind'] in ('attack', 'character') else x['kind']
            if x.get('row') != expected_row:
                errors.append(f'{name}: wrong HUD row')
            if x['kind'] == 'passive' and ('resist' in x.get('effect', '').lower() or '저항' in x.get('name', '')):
                errors.append('resistance passive is forbidden')
    if set(x['effect'] for x in common if x['kind'] == 'attack') != ATTACK_EFFECTS:
        errors.append('unsupported attack effect')
    if set(x['effect'] for x in common if x['kind'] == 'passive') != PASSIVE_EFFECTS:
        errors.append('unsupported passive effect')
    return errors

def check() -> dict:
    data = json.loads((ROOT / 'data/prototype_skills.json').read_text(encoding='utf-8'))
    errors = validate(data)
    negative = []
    for change in ('duplicate', 'resistance', 'foreign_owner', 'missing_ultimate', 'wrong_row'):
        broken = copy.deepcopy(data)
        if change == 'duplicate':
            broken['common'][1]['id'] = broken['common'][0]['id']
        elif change == 'resistance':
            broken['common'][8]['effect'] = 'fire_resistance'
        elif change == 'foreign_owner':
            broken['characters']['viya']['skills'][0]['owner'] = 'other'
        elif change == 'missing_ultimate':
            broken['characters']['viya']['skills'].pop()
        else:
            broken['common'][0]['row'] = 'passive'
        rejected = bool(validate(broken))
        negative.append({'fixture': change, 'rejected': rejected})
        if not rejected:
            errors.append(f'negative control not rejected: {change}')
    run = (ROOT / 'scripts/combat/run_state.gd').read_text(encoding='utf-8')
    growth = (ROOT / 'scripts/progression/growth_state.gd').read_text(encoding='utf-8')
    ui = (ROOT / 'scripts/main.gd').read_text(encoding='utf-8')
    for effect in ATTACK_EFFECTS - {'rifle'} | {'sigil'}:
        if f'"{effect}":' not in run:
            errors.append(f'missing offensive handler: {effect}')
    for effect in PASSIVE_EFFECTS:
        if f'int(ranks.get("{effect}", 0))' not in run:
            errors.append(f'missing passive integration: {effect}')
    for marker in ('var profile: Dictionary = stats_profile(growth.owned)', 'stats = profile["stats"]'):
        if marker not in run:
            errors.append('missing shared passive profile connection: ' + marker)
    for text, source in [('expected_ticket != ticket', growth), ('rng.randi_range(0, i)', growth),
                         ('RunState.Phase.CHOOSING', ui), ('_choose_skill.bind(id, last_ticket)', ui),
                         ('growth.select(id, ticket)', run), ('add_pickup(enemies[i]["p"])', run),
                         ('grant_xp(reward)', run), ('magic_button.disabled = true', ui)]:
        if text not in source:
            errors.append(f'missing integration marker: {text}')
    return {'status': 'FAIL' if errors else 'PASS', 'pool_count': 18,
            'counts': {'common_attack': 8, 'character_attack': 1, 'common_passive': 8, 'ultimate_enhancement': 1},
            'negative_controls': negative, 'errors': errors,
            'scope': 'JSON schema/content and source integration markers only; not GDScript runtime/behavior.'}

if __name__ == '__main__':
    result = check()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
