#!/usr/bin/env python3
"""Targeted source contract checks only. Does NOT execute or type-check GDScript."""
from __future__ import annotations
import ast
import copy
import hashlib
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ('scripts/combat/feedback_state.gd', 'scripts/combat/run_state.gd',
           'scripts/ui/feedback_panel.gd', 'scripts/main.gd', 'tests/test_feedback.gd')


def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    feedback = sources[SOURCES[0]]
    run = sources[SOURCES[1]]
    panel = sources[SOURCES[2]]
    ui = sources[SOURCES[3]]
    try:
        durations = ast.literal_eval(re.search(r'^const DURATIONS := (.+)$', feedback, re.M)[1])
        order = ast.literal_eval(re.search(r'^const ORDER := (.+)$', feedback, re.M)[1])
        ratio = float(re.search(r'^const LOW_HP_RATIO := (.+)$', feedback, re.M)[1])
        if order != ['hurt', 'magic', 'levelup'] or set(durations) != set(order):
            errors.append('reaction priority/duration keys mismatch')
        if any(not isinstance(x, (int, float)) or not math.isfinite(x) or x <= 0 for x in durations.values()):
            errors.append('invalid reaction duration')
        if ratio != 0.30:
            errors.append('unexpected provisional low-HP threshold')
    except (AttributeError, TypeError, ValueError, SyntaxError):
        errors.append('reaction rules cannot be read')
    requirements = [
        ('feedback.reset()', run), ('feedback.finish()', run),
        ('feedback.trigger("hurt")', run), ('feedback.trigger("magic")', run),
        ('feedback.level_up(growth.ticket)', run), ('feedback.advance(dt, true)', run),
        ('if not running or defeated or delta <= 0.0 or not is_finite(delta)', feedback),
        ('offer_ticket <= _last_level_ticket', feedback),
        ('if defeated or hp <= 0:', feedback), ('result["low_hp"] = is_low(hp, maximum)', feedback),
        ('const FeedbackPanel = preload(', ui), ('bottom_row.add_child(feedback_panel)', ui),
        ('simulation.feedback.snapshot(simulation.hp, simulation.max_hp)', ui),
        ('feedback_panel.present(data, context)', ui), ('simulation.result_summary()', ui),
        ('mouse_filter = Control.MOUSE_FILTER_IGNORE', panel),
        ('danger_text.text = "저체력 경고" if bool(data["low_hp"]) else ""', panel),
    ]
    for marker, source in requirements:
        if marker not in source:
            errors.append('missing integration: ' + marker)
    step = run.split('func step(', 1)[1].split('\nfunc ', 1)[0]
    if step.find('if phase != Phase.RUNNING') > step.find('feedback.advance('):
        errors.append('feedback advanced before phase guard')
    cast = run.split('func cast_ultimate(', 1)[1].split('\nfunc ', 1)[0]
    if cast.find('if cast.is_empty():') > cast.find('feedback.trigger("magic")'):
        errors.append('cast feedback happens before accepted-cast guard')
    if any(x in feedback + panel for x in ('Timer.new(', 'create_timer(', 'create_tween(', 'Time.get_')):
        errors.append('feedback must not use wall-clock timers/tweens')
    if 'feedback.advance(' in ui or 'feedback.advance(' in panel:
        errors.append('UI may not advance reaction clocks')
    return errors


def check() -> dict:
    sources = {name: (ROOT / name).read_text(encoding='utf-8') for name in SOURCES}
    errors = validate(sources)
    # Reuse the repository's exact delimiter helper without importing unrelated
    # data checks. This is intentionally a targeted changed-file validation.
    checker_source = (ROOT / 'tools/check_project.py').read_text(encoding='utf-8')
    tree = ast.parse(checker_source)
    helper = next(x for x in tree.body if isinstance(x, ast.FunctionDef) and x.name == 'check_delimiters')
    namespace: dict = {}
    exec(compile(ast.Module(body=[helper], type_ignores=[]), 'delimiter_helper', 'exec'), namespace)
    checked = dict(sources)
    for name in ('tools/check_project.py', 'tools/check_feedback_data.py'):
        checked[name] = (ROOT / name).read_text(encoding='utf-8')
    for name, text in checked.items():
        try:
            if name.endswith('.gd'):
                namespace['check_delimiters'](text)
            elif name.endswith('.py'):
                compile(text, name, 'exec')
            for number, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line:
                    errors.append(f'{name}:{number}: trailing whitespace')
                if name.endswith('.gd') and line.startswith(' '):
                    errors.append(f'{name}:{number}: expected tab indentation')
        except (ValueError, SyntaxError) as error:
            errors.append(f'{name}: {error}')
    for broken in ('var x = (1 + 2\n', 'var x = [1, 2}\n'):
        try:
            namespace['check_delimiters'](broken)
            errors.append('delimiter negative control not rejected')
        except ValueError:
            pass
    if 'res://tests/test_feedback.gd' not in checker_source:
        errors.append('actual engine test is not registered')
    for name in ('scripts/combat/feedback_state.gd', 'scripts/ui/feedback_panel.gd'):
        if not (ROOT / name).is_file():
            errors.append('missing new runtime dependency: ' + name)
    negative = []
    for name, file, old, new in [
        ('missing_damage_hook', SOURCES[1], 'feedback.trigger("hurt")', 'pass'),
        ('missing_reset', SOURCES[1], 'feedback.reset()', 'pass'),
        ('negative_duration', SOURCES[0], '"hurt": 0.55', '"hurt": -0.55'),
        ('missing_low_hp_warning', SOURCES[2], 'danger_text.text = "저체력 경고"', 'danger_text.text = ""'),
        ('missing_stale_guard', SOURCES[0], 'offer_ticket <= _last_level_ticket', 'offer_ticket < -999'),
    ]:
        broken = copy.copy(sources)
        assert old in broken[file], name
        broken[file] = broken[file].replace(old, new, 1)
        rejected = bool(validate(broken))
        negative.append({'fixture': name, 'rejected': rejected})
        if not rejected:
            errors.append('negative control not rejected: ' + name)
    return {'status': 'FAIL' if errors else 'PASS', 'errors': errors,
            'negative_controls': negative,
            'files_checked': len(checked),
            'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in checked},
            'scope': '7 affected code/test/checker files: UTF-8, delimiters, whitespace, Python syntax, reaction constants, integration markers, engine-test registration and new dependency paths only. NOT the full project check or GDScript parser/type/runtime, rendering, or mobile input tests.'}


if __name__ == '__main__':
    result = check()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
