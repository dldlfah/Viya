#!/usr/bin/env python3
"""Changed-source contracts only; never substitute these for Godot tests.
Run: python tools/check_run_navigation.py
Native suite: Godot --headless --path . --script res://tests/test_run_navigation.gd
"""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = ('scripts/combat/run_state.gd', 'scripts/ui/mobile_main.gd',
         'tests/test_run_navigation.gd', 'tools/check_project.py',
         'tools/check_run_navigation.py')


def function(source: str, name: str) -> str:
    match = re.search(r'^func ' + re.escape(name) + r'\([^\n]*\).*?:\n(.*?)(?=^func |\Z)', source, re.M | re.S)
    return match[1] if match else ''



def check_single_line_strings(text: str) -> None:
    """This task's GDScript files use only ordinary quoted strings."""
    quote = ''
    escaped = False
    comment = False
    for char in text:
        if comment:
            if char == '\n':
                comment = False
            continue
        if quote:
            if char == '\n':
                raise ValueError('literal newline inside ordinary GDScript string')
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = ''
        elif char == '#':
            comment = True
        elif char in ('"', "'"):
            quote = char


def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    run = sources[FILES[0]]
    ui = sources[FILES[1]]
    requirements = [
        ('DEFEAT, CHOOSING, ABANDONED', run),
        ('expected_ticket != navigation_ticket', function(run, 'request_transition')),
        ('action not in ["leave", "restart"]', function(run, 'request_transition')),
        ('set_paused(true)', function(run, 'request_transition')),
        ('not _valid_confirmation(expected_ticket)', function(run, 'confirm_transition')),
        ('not _valid_confirmation(expected_ticket)', function(run, 'cancel_transition')),
        ('set_paused(false)', function(run, 'cancel_transition')),
        ('return start(0, growth.character_id, account_level, map_id, growth.ruleset,{},run_mode,dungeon_day,growth.pacing_version,-1,encounter_version,loot_rules_version)', function(run, 'confirm_transition')),
        ('_finish_run("abandoned")', function(run, 'confirm_transition')),
        ('_finish_run("defeat")', function(run, 'damage_player')),
        ('if not transition_action.is_empty():', function(run, 'set_paused')),
        ('phase == Phase.PAUSED', function(run, '_valid_confirmation')),
        ('expected_ticket == navigation_ticket', function(run, '_valid_confirmation')),
        ('_finished_result.duplicate(true)', function(run, 'result_summary')),
        ('growth.ticket += 1', function(run, '_finish_run')),
        ('growth.pending = 0', function(run, '_finish_run')),
        ('navigation_ticket += 1', function(run, 'start')),
        ('_finished_result.clear()', function(run, 'start')),
        ('phase not in [Phase.DEFEAT, Phase.ABANDONED, Phase.CLEARED]', function(run, 'return_to_ready')),
        ('phase = Phase.READY', function(run, 'return_to_ready')),
        ('extends "res://scripts/main.gd"', ui),
        ('child.pressed.disconnect(begin_run)', function(ui, '_show_menu')),
        ('_request_transition.bind("restart", ticket, revision)', function(ui, '_show_menu')),
        ('_return_to_lobby.bind(ticket, revision)', function(ui, '_show_menu')),
        ('revision == _menu_revision', function(ui, '_menu_matches')),
        ('ticket == simulation.navigation_ticket', function(ui, '_menu_matches')),
        ('not _menu_matches(ticket, revision)', function(ui, '_confirm_transition')),
        ('not _menu_matches(ticket, revision)', function(ui, '_cancel_transition')),
        ('simulation.interrupt_transition()', function(ui, 'pause_game')),
        ('not simulation.transition_action.is_empty()', function(ui, '_unhandled_key_input')),
        ('_cancel_transition(simulation.navigation_ticket, _menu_revision)', function(ui, '_unhandled_key_input')),
        ('res://tests/test_run_navigation.gd', sources[FILES[3]]),
    ]
    for marker, target in requirements:
        if marker not in target:
            errors.append('missing contract: ' + marker)
    for name in ('request_transition', 'cancel_transition', 'interrupt_transition'):
        body = function(run, name)
        for forbidden in ('growth.reset(', 'growth.open_offer(', 'offer.clear(', 'hp =', 'mana =', '_refresh_stats('):
            if forbidden in body:
                errors.append(name + ': forbidden gameplay mutation ' + forbidden)
    for forbidden in ('start(', 'phase =', 'gain('):
        if forbidden in function(run, 'interrupt_transition'):
            errors.append('interruption must remain paused: ' + forbidden)
    if 'hp = 0' in function(run, '_finish_run'):
        errors.append('abandonment must not fake lethal damage')
    if 'start(' in function(ui, '_confirm_transition') or 'begin_run()' in function(ui, '_confirm_transition'):
        errors.append('UI must not start a second run after confirmed restart')
    if 'super._notification' in ui:
        errors.append('do not double-dispatch inherited focus notifications')
    return errors


def check() -> dict:
    sources = {name: (ROOT / name).read_text(encoding='utf-8') for name in FILES}
    errors = validate(sources)
    # Existing delimiter helper, read via AST without executing full-project imports.
    tree = ast.parse(sources['tools/check_project.py'])
    helper = next(x for x in tree.body if isinstance(x, ast.FunctionDef) and x.name == 'check_delimiters')
    ns: dict = {}
    exec(compile(ast.Module(body=[helper], type_ignores=[]), 'delimiter_helper', 'exec'), ns)
    for name, text in sources.items():
        try:
            if name.endswith('.gd'):
                ns['check_delimiters'](text)
                check_single_line_strings(text)
                names = re.findall(r'^func (\w+)\(', text, re.M)
                if len(names) != len(set(names)):
                    errors.append(name + ': duplicate function')
            else:
                ast.parse(text, filename=name)
            for n, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line:
                    errors.append(f'{name}:{n}: trailing whitespace')
                if name.endswith('.gd') and line.startswith(' '):
                    errors.append(f'{name}:{n}: non-tab indentation')
        except (ValueError, SyntaxError) as exc:
            errors.append(f'{name}: {exc}')
    negatives = []
    try:
        check_single_line_strings('var text = "bad\nstring"')
        errors.append('unescaped-newline negative control not rejected')
    except ValueError:
        negatives.append({'fixture': 'unescaped_string_newline', 'rejected': True})
    for label, path, before, after in [
        ('unguarded_intent', FILES[0], 'expected_ticket != navigation_ticket or not has_active_run()', 'not has_active_run()'),
        ('confirmation_resets_hp', FILES[0], '\tset_paused(true)\n\ttransition_action', '\thp = 100\n\tset_paused(true)\n\ttransition_action'),
        ('cancel_rerolls', FILES[0], '\tset_paused(false) # Same XP', '\tgrowth.open_offer()\n\tset_paused(false) # Same XP'),
        ('leave_fakes_death', FILES[0], '_finish_run("abandoned")', '_finish_run("defeat")'),
        ('no_result_copy', FILES[0], '_finished_result.duplicate(true)', '_finished_result'),
        ('stale_menu_revision', FILES[1], 'revision == _menu_revision', 'revision >= 0'),
        ('unregistered_engine_test', FILES[3], 'res://tests/test_run_navigation.gd', 'res://tests/missing.gd'),
    ]:
        assert before in sources[path], label
        mutated = dict(sources)
        mutated[path] = mutated[path].replace(before, after, 1)
        rejected = bool(validate(mutated))
        negatives.append({'fixture': label, 'rejected': rejected})
        if not rejected:
            errors.append('negative control not rejected: ' + label)
    hashes = {name: hashlib.sha256(text.encode()).hexdigest() for name, text in sources.items()}
    return {'status': 'FAIL' if errors else 'PASS', 'files_checked': len(FILES),
            'errors': errors, 'negative_controls': negatives, 'source_sha256': hashes,
            'source_fingerprint': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
            'scope': 'UTF-8/delimiters/Python syntax and navigation SOURCE contracts only; NOT GDScript parsing/types, native execution, actual UI/input, or mobile testing.'}


if __name__ == '__main__':
    try:
        result = check()
    except (OSError, ValueError, SyntaxError, StopIteration, AssertionError) as exc:
        result = {'status': 'FAIL', 'error': str(exc)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result['status'] == 'PASS' else 1)
