#!/usr/bin/env python3
"""Changed-source proof only; NOT GDScript parsing, behavior, rendering or FPS."""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = ('scripts/combat/run_state.gd', 'scripts/combat/battle_view.gd',
         'scripts/combat/combat_cues.gd', 'tests/test_combat_cues.gd',
         'tools/check_project.py', 'tools/check_combat_cues.py')
# GAME-007: reviewed presentation metadata/drawing; gameplay restored byte-for-byte to GAME-006.
BASE_RUN_BLOB = '7f2e884105953378b438368e3da0859c7be45a24'
BASE_VIEW_BLOB = 'dcfd178805e51b086044faf98ff44606741283d4'
BASE_RUNNER_BLOB = '1ab68ad8a51271e3d47db8b02d433991f42e8d6c'
# Exact run_engine() from GAME-004D; all 7 suites and failure checks are protected.
BASE_ENGINE_FUNCTION_SHA256 = '9156043eaf896d72565563cc1e2f623cf0c8fbac7f032f19bffee7e4946a69ee'
ADDED_RUN_LINES = ('const CombatCues = preload("res://scripts/combat/combat_cues.gd")', 'var cues = CombatCues.new()', '\tcues.reset()', '\tcues.advance(dt)', '\t\tcues.record_collected_xp(player, reward)', '\t\tvar critical: bool = false', '\t\tvar previous_hp: int = int(enemies[i]["hp"])', '\t\tvar hit_at: Vector2 = enemies[i]["p"]', '\t\t\tcritical = true', '\t\t# Display HP actually removed, not theoretical overkill damage. Reuse the crit roll.', '\t\tvar hp_lost: int = maxi(0, previous_hp - maxi(0, int(enemies[i]["hp"])))', '\t\tcues.record_hit(id, hit_at, hp_lost, critical)', '\t\t\tcues.record_kill(id, hit_at)')


def blob(text: str) -> str:
    data = text.encode('utf-8')
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def section(source: str, name: str) -> str:
    return source.split('func ' + name + '(', 1)[1].split('\nfunc ', 1)[0]


def engine_function_digest(source: str) -> str:
    """Allow source-orchestration changes, never alteration of native checks."""
    try:
        nodes = [n for n in ast.parse(source).body
                 if isinstance(n, ast.FunctionDef) and n.name == 'run_engine']
        if len(nodes) != 1:
            return ''
        function_source = ast.get_source_segment(source, nodes[0])
        return hashlib.sha256(function_source.encode('utf-8')).hexdigest()
    except (SyntaxError, AttributeError, UnicodeError):
        return ''


def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    run, view, cues, tests, runner, _ = [sources[x] for x in FILES]
    restored = run
    for line in ADDED_RUN_LINES:
        if restored.splitlines().count(line) != 1:
            errors.append('Missing/duplicate reviewed visual hook: ' + line.strip())
        restored = restored.replace(line + '\n', '', 1)
    if blob(restored) != BASE_RUN_BLOB:
        errors.append('RunState changed outside reviewed additive visual hooks')
    if engine_function_digest(runner) != BASE_ENGINE_FUNCTION_SHA256:
        errors.append('Existing native engine commands or pass/fail criteria changed')
    restored_view = view.split('\nfunc _draw_combat_cues() -> void:', 1)[0]
    restored_view = restored_view.replace('\t_draw_combat_cues()\n', '', 1)
    restored_view = restored_view.replace('\t\t\tvar flash: float = simulation.cues.flash_alpha(int(enemy["id"]))\n', '', 1)
    restored_view = restored_view.replace('\t\t\tvar enemy_color: Color = Color("aa5364").lerp(Color("fff1db"), flash)\n', '', 1)
    restored_view = restored_view.replace(']), enemy_color)', ']), Color("aa5364"))', 1)
    if blob(restored_view) != BASE_VIEW_BLOB:
        errors.append('Existing battle View changed outside the tint and draw hook')
    for value in ('const MAX_EVENTS := 48', 'const MAX_FLASHES := 80',
                  'events.size() >= MAX_EVENTS', 'events.pop_front()',
                  'flashes.size() >= MAX_FLASHES', 'flashes.erase(flashes.keys()[0])',
                  'events.remove_at(i)', 'flashes.erase(id)',
                  'events.duplicate(true)', 'not enabled or hp_lost <= 0',
                  'not enabled or amount <= 0.0 or not is_finite(amount)'):
        if value not in cues:
            errors.append('Missing bounded presentation contract: ' + value)
    code_cues = '\n'.join(line.split('#', 1)[0] for line in cues.splitlines())
    for forbidden in ('randf(', 'randi(', 'RandomNumberGenerator', 'Timer.new(',
                      'create_timer(', 'create_tween(', 'Time.get_', 'simulation.',
                      'growth.', 'magic.', 'RunState.new('):
        if forbidden in code_cues:
            errors.append('Presentation must not own gameplay/RNG/wall time: ' + forbidden)
    step = section(run, 'step')
    if step.index('cues.advance(dt)') < step.index('if phase != Phase.RUNNING'):
        errors.append('Visual time advances before the RUNNING guard')
    hit = section(run, '_damage_enemy')
    if hit.index('cues.record_hit(') < hit.index('enemies[i]["hp"] -='):
        errors.append('Hit cue emitted before actual damage')
    if hit.index('cues.record_kill(') < hit.index('kills += 1'):
        errors.append('Kill cue emitted before actual kill')
    collect = section(run, '_collect_pickups')
    if collect.index('cues.record_collected_xp(') < collect.index('grant_xp(reward)'):
        errors.append('XP cue emitted before actual collection grant')
    if 'cues.' in section(run, 'add_pickup') or 'cues.' in section(run, 'grant_xp'):
        errors.append('Drop creation or arbitrary XP grant must not advertise collection')
    if 'cues.advance(' in view or 'cues.record_' in view or 'cues.reset(' in view:
        errors.append('View must be read-only')
    for marker in ('simulation.cues.flash_alpha(int(enemy["id"]))', '_draw_combat_cues()',
                   'for event in simulation.cues.events:', 'clip_contents = true'):
        if marker not in view:
            errors.append('View missing connection: ' + marker)
    for marker in ('gameplay_snapshot(a) == gameplay_snapshot(b)', 'Cues.MAX_EVENTS',
                   'state.request_transition("leave"', 'scene.slot_buttons[0].pressed.emit()',
                   'state.cues.events.is_empty() and state.cues.flashes.is_empty()'):
        if marker not in tests:
            errors.append('Missing authored engine regression: ' + marker)
    return errors


def check() -> dict:
    sources = {name: (ROOT / name).read_text(encoding='utf-8') for name in FILES}
    errors = validate(sources)
    tree = ast.parse(sources['tools/check_project.py'])
    helper = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'check_delimiters')
    ns: dict = {}
    exec(compile(ast.Module(body=[helper], type_ignores=[]), 'existing_delimiter_helper', 'exec'), ns)
    for name, text in sources.items():
        try:
            if name.endswith('.gd'):
                ns['check_delimiters'](text)
                names = re.findall(r'^func (\w+)\(', text, re.M)
                if len(names) != len(set(names)):
                    errors.append(name + ': duplicate function')
            else:
                ast.parse(text, name)
            for number, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line or (name.endswith('.gd') and line.startswith(' ')):
                    errors.append(f'{name}:{number}: whitespace/indentation')
        except (ValueError, SyntaxError) as error:
            errors.append(f'{name}: {error}')
    negative = []
    cases = [
        ('missing_reset', FILES[0], '\tcues.reset()\n', ''),
        ('early_clock', FILES[0], '\tvar dt := minf(delta, 0.05)\n', '\tvar dt := minf(delta, 0.05)\n\tcues.advance(dt)\n'),
        ('changed_damage', FILES[0], 'damage *= 2.0', 'damage *= 3.0'),
        ('drop_as_collection', FILES[0], '\tpickups.append(', '\tcues.record_collected_xp(at, value)\n\tpickups.append('),
        ('unbounded_visuals', FILES[2], 'events.pop_front()', 'pass'),
        ('cosmetic_rng', FILES[2], 'flashes[id] = FLASH_SECONDS', 'flashes[id] = randf()'),
        ('mutable_view', FILES[1], '\t_draw_combat_cues()', '\tsimulation.cues.advance(0.05)\n\t_draw_combat_cues()'),
        ('unregistered_test', FILES[4], 'res://tests/test_combat_cues.gd', 'res://tests/missing.gd'),
        ('ignored_engine_exit', FILES[4], 'result.returncode == 0 and not bad_log', 'True and not bad_log'),
        ('ignored_engine_errors', FILES[4], 'and not bad_log and not test_not_passed', 'and not test_not_passed'),
        ('ignored_test_result', FILES[4], 'and not bad_log and not test_not_passed', 'and not bad_log'),
    ]
    for label, path, old, new in cases:
        altered = dict(sources)
        # The drop insertion is inside the original indentation; it is only a bad-source fixture.
        if old not in altered[path] and label == 'drop_as_collection':
            old = '\t\tpickups.append('
            new = '\t\tcues.record_collected_xp(at, value)\n\t\tpickups.append('
        if old not in altered[path]:
            errors.append('fixture not applied: ' + label)
            continue
        altered[path] = altered[path].replace(old, new, 1)
        rejected = bool(validate(altered))
        negative.append({'fixture': label, 'rejected': rejected})
        if not rejected:
            errors.append('negative not rejected: ' + label)
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
    return {'status': 'FAIL' if errors else 'PASS', 'files_checked': len(FILES),
            'errors': errors, 'negative_controls': negative, 'source_sha256': hashes,
            'source_fingerprint': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
            'baseline_run_blob': BASE_RUN_BLOB, 'baseline_runner_blob': BASE_RUNNER_BLOB,
            'baseline_engine_function_sha256': BASE_ENGINE_FUNCTION_SHA256,
            'scope': 'Changed-source UTF-8/delimiters/Python syntax, hook order, bounds, isolation, '
                     'additive RunState restoration to exact Git blob and preserved engine runner. '
                     'NOT Godot parser/type/runtime, visual quality, input dispatch, or FPS.'}


if __name__ == '__main__':
    try:
        result = check()
    except (OSError, ValueError, IndexError, KeyError, SyntaxError, StopIteration) as error:
        result = {'status': 'FAIL', 'error': str(error)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'PASS' else 1)