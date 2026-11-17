#!/usr/bin/env python3
"""Integrity/data checks + optional REAL Godot execution; never simulated PASS.
Exit 0: engine checks passed. Exit 1: failure. Exit 2: engine not available.
No CI/network/dependency installation; real runtime logs are isolated from saves.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from check_growth_data import check as check_growth

ROOT = Path(__file__).resolve().parents[1]


def check_delimiters(text: str) -> None:
    stack: list[str] = []
    quote = ''
    escaped = False
    comment = False
    for char in text:
        if comment:
            if char == '\n':
                comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = ''
            continue
        if char == '#':
            comment = True
        elif char in '\"\'':
            quote = char
        elif char in '([{':
            stack.append(char)
        elif char in ')]}':
            expected = {')': '(', ']': '[', '}': '{'}[char]
            if not stack or stack.pop() != expected:
                raise ValueError(f'unmatched delimiter {char}')
    if stack or quote:
        raise ValueError('unclosed delimiter or string')


def static_checks() -> dict:
    files = [ROOT / 'project.godot', *sorted((ROOT / 'scenes').rglob('*.tscn')),
             *sorted((ROOT / 'scripts').rglob('*.gd')), *sorted((ROOT / 'tests').rglob('*.gd')),
             *sorted((ROOT / 'data').rglob('*.json')), *sorted((ROOT / 'tools').glob('*.py'))]
    errors: list[str] = []
    digests: dict[str, str] = {}
    references = 0
    for path in files:
        name = path.relative_to(ROOT).as_posix()
        try:
            data = path.read_bytes()
            text = data.decode('utf-8')
            digests[name] = hashlib.sha256(data).hexdigest()
            if path.suffix in ('.gd', '.tscn'):
                check_delimiters(text)
            elif path.suffix == '.json':
                json.loads(text)
            elif path.suffix == '.py':
                compile(text, name, 'exec')
            for lineno, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line:
                    errors.append(f'{name}:{lineno}: trailing whitespace')
                if path.suffix == '.gd' and line.startswith(' '):
                    errors.append(f'{name}:{lineno}: use tabs for indentation')
            if path.suffix not in ('.gd', '.tscn', '.godot'):
                continue
            for resource in re.findall(r'res://([^"\s]+)', text):
                references += 1
                if '..' in Path(resource).parts or not (ROOT / resource).is_file():
                    errors.append(f'{name}: unresolved resource {resource}')
        except (OSError, UnicodeError, ValueError, SyntaxError) as error:
            errors.append(f'{name}: {error}')
    project = (ROOT / 'project.godot').read_text(encoding='utf-8')
    for required in ('run/main_scene="res://scenes/main.tscn"',
                     'window/handheld/orientation=0', 'renderer/rendering_method="gl_compatibility"'):
        if required not in project:
            errors.append(f'missing project setting: {required}')
    for broken in ('var x = (1 + 2\n', 'var x = [1, 2}\n'):
        try:
            check_delimiters(broken)
            errors.append('delimiter checker failed negative control')
        except ValueError:
            pass
    fingerprint = hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest()
    return {'status': 'FAIL' if errors else 'PASS', 'files_checked': len(files),
            'resource_references_checked': references, 'errors': errors,
            'source_sha256': digests, 'source_fingerprint': fingerprint,
            'scope': 'UTF-8, delimiters, whitespace, JSON/Python syntax, resource existence, project settings; NOT GDScript parser/typechecking or gameplay.'}


def run_engine(engine: str, out: Path) -> dict:
    env = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix='viya-validation-') as tmp:
        env.update(XDG_DATA_HOME=str(Path(tmp) / 'data'), XDG_CONFIG_HOME=str(Path(tmp) / 'config'),
                   APPDATA=str(Path(tmp) / 'roaming'), LOCALAPPDATA=str(Path(tmp) / 'local'))
        commands = [
            [engine, '--headless', '--version'],
            [engine, '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'],
            [engine, '--headless', '--path', str(ROOT), '--script', 'res://tests/test_combat_foundation.gd'],
            [engine, '--headless', '--path', str(ROOT), '--script', 'res://tests/test_growth.gd'],
            [engine, '--headless', '--path', str(ROOT), '--quit-after', '120'],
        ]
        records = []
        for index, command in enumerate(commands):
            try:
                result = subprocess.run(command, capture_output=True, text=True,
                                        encoding='utf-8', errors='replace', timeout=120, env=env)
                log = result.stdout + result.stderr
                (out / f'engine_{index}.log').write_text(log, encoding='utf-8')
                bad_log = any(token in log for token in ('SCRIPT ERROR:', 'ERROR:', 'FAIL:', 'instances leaked', 'resources still in use'))
                test_not_passed = '--script' in command and '"status":"PASS"' not in log.replace(' ', '')
                passed = result.returncode == 0 and not bad_log and not test_not_passed
                records.append({'command': command, 'exit_code': result.returncode, 'status': 'PASS' if passed else 'FAIL'})
                if not passed:
                    return {'status': 'FAIL', 'commands': records}
            except (OSError, subprocess.TimeoutExpired) as error:
                return {'status': 'FAIL', 'commands': records, 'error': str(error)}
        return {'status': 'PASS', 'commands': records,
                'scope': 'headless import, actual foundation/growth GDScript tests and main boot; visual/mobile approval separate'}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', help='Godot 4 executable, e.g. Windows console executable')
    parser.add_argument('--output', type=Path, default=ROOT / '.local_validation')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    integrity = static_checks()
    try:
        growth = check_growth()
    except (OSError, ValueError, KeyError, TypeError) as error:
        growth = {'status': 'FAIL', 'error': str(error)}
    report = {'static_integrity': integrity, 'growth_data_contract': growth,
              'godot_runtime': {'status': 'NOT_VERIFIED'}, 'windows_f5': 'NOT_VERIFIED',
              'android_device': 'NOT_VERIFIED', 'ios_device': 'NOT_VERIFIED'}
    code = 1
    if integrity['status'] == 'PASS' and growth['status'] == 'PASS':
        executable = args.godot or shutil.which('godot') or shutil.which('godot4')
        if executable:
            report['godot_runtime'] = run_engine(executable, args.output)
            code = 0 if report['godot_runtime']['status'] == 'PASS' else 1
        else:
            report['godot_runtime']['reason'] = 'Godot executable unavailable; no engine/parser/behavior execution was performed.'
            code = 2
    (args.output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
