"""Unit tests for the real Python runner's orchestration, not gameplay tests.
The delegated checker/engine outcomes are explicit test doubles. No Godot is run.
Run: python -m unittest discover -s tests -p test_check_project.py -v
"""
from __future__ import annotations
import ast
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def load_tool(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load_tool('check_project')
cues = load_tool('check_combat_cues')
EXPECTED = (
    ('growth_data_contract', 'check_growth_data'),
    ('magic_data_contract', 'check_magic_data'),
    ('feedback_source_contract', 'check_feedback_data'),
    ('mobile_hud_source_contract', 'check_mobile_hud'),
    ('run_navigation_source_contract', 'check_run_navigation'),
    ('combat_cues_source_contract', 'check_combat_cues'),
)


class RunnerIntegrationTests(unittest.TestCase):
    def checks(self, failing=None, value=None):
        results = {key: {'status': 'PASS'} for key, _ in EXPECTED}
        if failing:
            results[failing] = {'status': 'FAIL'} if value is None else value
        return results

    def run_main(self, contracts=None, integrity=None, integrity_error=None,
                 executable=None, engine_result=None):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            argv = ['check_project.py', '--output', str(output)]
            if executable:
                argv += ['--godot', executable]
            with patch.object(runner, 'source_checks', return_value=contracts or self.checks()), \
                 patch.object(runner, 'static_checks', return_value=integrity or {'status': 'PASS'},
                              side_effect=integrity_error), \
                 patch.object(runner.shutil, 'which', return_value=None), \
                 patch.object(runner, 'run_engine', return_value=engine_result or {'status': 'PASS'}) as engine, \
                 patch.object(sys, 'argv', argv), contextlib.redirect_stdout(io.StringIO()):
                code = runner.main()
                report = json.loads((output / 'report.json').read_text())
                return code, report, engine.call_count

    def test_all_six_suites_are_registered(self):
        self.assertEqual(runner.SOURCE_CHECK_MODULES, EXPECTED)

    def test_each_suite_is_invoked_once(self):
        delegates = {name: SimpleNamespace(check=Mock(return_value={'status': 'PASS'}))
                     for _, name in EXPECTED}
        with patch.object(runner.importlib, 'import_module', side_effect=delegates.__getitem__) as imports:
            results = runner.source_checks()
        self.assertEqual(list(results), [key for key, _ in EXPECTED])
        self.assertEqual(imports.call_count, 6)
        for delegate in delegates.values():
            delegate.check.assert_called_once_with()

    def test_failure_does_not_skip_later_suites(self):
        delegates = {name: SimpleNamespace(check=Mock(return_value={'status': 'PASS'}))
                     for _, name in EXPECTED}
        delegates[EXPECTED[0][1]].check.return_value = {'status': 'FAIL'}
        with patch.object(runner.importlib, 'import_module', side_effect=delegates.__getitem__):
            results = runner.source_checks()
        self.assertEqual(results[EXPECTED[0][0]]['status'], 'FAIL')
        self.assertEqual(results[EXPECTED[-1][0]]['status'], 'PASS')
        self.assertTrue(all(item.check.call_count == 1 for item in delegates.values()))

    def test_missing_module_is_reported_and_remaining_suites_run(self):
        calls = []
        def resolve(name):
            calls.append(name)
            if name == 'check_mobile_hud':
                raise ModuleNotFoundError('fixture: missing checker')
            return SimpleNamespace(check=lambda: {'status': 'PASS'})
        with patch.object(runner.importlib, 'import_module', side_effect=resolve):
            results = runner.source_checks()
        self.assertEqual(len(calls), 6)
        self.assertEqual(results['mobile_hud_source_contract']['status'], 'FAIL')
        self.assertIn('ModuleNotFoundError', results['mobile_hud_source_contract']['error'])
        self.assertEqual(results['combat_cues_source_contract']['status'], 'PASS')

    def test_checker_exceptions_and_malformed_results_fail_closed(self):
        for value in (None, {}, {'status': 'NOT_VERIFIED'}, 'PASS', {'status': True}):
            with self.subTest(value=value):
                with patch.object(runner.importlib, 'import_module',
                                  return_value=SimpleNamespace(check=lambda: value)):
                    result = runner.source_checks()
                self.assertTrue(all(r['status'] == 'FAIL' for r in result.values()))
        for error in (AssertionError('fixture'), SyntaxError('fixture'), IndexError('fixture')):
            with self.subTest(error=type(error).__name__):
                with patch.object(runner.importlib, 'import_module',
                                  return_value=SimpleNamespace(check=Mock(side_effect=error))):
                    result = runner.source_checks()
                self.assertTrue(all(r['status'] == 'FAIL' for r in result.values()))

    def test_no_engine_stays_not_verified_with_exit_two(self):
        code, report, calls = self.run_main()
        self.assertEqual(code, 2)
        self.assertEqual(calls, 0)
        self.assertEqual(report['godot_runtime']['status'], 'NOT_VERIFIED')
        self.assertTrue(all(key in report for key, _ in EXPECTED))
        for key in ('windows_f5', 'android_device', 'ios_device'):
            self.assertEqual(report[key], 'NOT_VERIFIED')

    def test_any_failed_suite_blocks_engine_and_exits_one(self):
        for key, _ in EXPECTED:
            with self.subTest(failing=key):
                code, report, calls = self.run_main(contracts=self.checks(failing=key), executable='fixture-engine')
                self.assertEqual((code, calls), (1, 0))
                self.assertEqual(report[key]['status'], 'FAIL')
                self.assertEqual(report['godot_runtime']['status'], 'NOT_VERIFIED')

    def test_integrity_exception_still_produces_report(self):
        code, report, calls = self.run_main(integrity_error=FileNotFoundError('fixture: missing project'),
                                          executable='fixture-engine')
        self.assertEqual((code, calls), (1, 0))
        self.assertEqual(report['static_integrity']['status'], 'FAIL')
        self.assertIn('FileNotFoundError', report['static_integrity']['error'])
        self.assertTrue(all(key in report for key, _ in EXPECTED))

    def test_engine_outcome_is_not_promoted_to_mobile_pass(self):
        for status, expected in (('PASS', 0), ('FAIL', 1)):
            with self.subTest(status=status):
                code, report, calls = self.run_main(executable='fixture-engine', engine_result={'status': status})
                self.assertEqual((code, calls), (expected, 1))
                self.assertEqual(report['godot_runtime']['status'], status)
                self.assertEqual(report['android_device'], 'NOT_VERIFIED')

    def test_exact_native_engine_function_is_preserved(self):
        source = (ROOT / 'tools/check_project.py').read_text()
        self.assertEqual(cues.engine_function_digest(source), cues.BASE_ENGINE_FUNCTION_SHA256)
        changes = (
            ('res://tests/test_growth.gd', 'res://tests/missing.gd'),
            ('result.returncode == 0 and not bad_log', 'True and not bad_log'),
            ('and not bad_log and not test_not_passed', 'and not test_not_passed'),
            ('and not bad_log and not test_not_passed', 'and not bad_log'),
        )
        for old, new in changes:
            with self.subTest(change=old):
                self.assertIn(old, source)
                self.assertNotEqual(cues.engine_function_digest(source.replace(old, new, 1)),
                                    cues.BASE_ENGINE_FUNCTION_SHA256)

    def test_native_guard_connections_and_authored_regressions_exist(self):
        source = (ROOT / 'scripts/ui/mobile_main.gd').read_text()
        native = (ROOT / 'tests/test_mobile_hud.gd').read_text()
        runner.check_delimiters(source)
        runner.check_delimiters(native)
        self.assertIn('_close_skill_detail.bind(simulation.navigation_ticket, _menu_revision)', source)
        close = source.split('func _close_skill_detail(', 1)[1].split('\nfunc ', 1)[0]
        self.assertLess(close.index('not _menu_matches(expected_ticket, expected_revision)'),
                        close.index('_detail_open = false'))
        self.assertLess(close.index('_menu_revision += 1'), close.index('super.resume_game()'))
        self.assertIn('_close_skill_detail(simulation.navigation_ticket, _menu_revision)', source)
        self.assertIn('_test_stale_detail_close(scene)', native)
        self.assertIn('get_signal_connection_list("pressed")', native)
        self.assertIn('old_close.call()', native)

    def test_changed_python_compiles(self):
        for relative in ('tools/check_project.py', 'tools/check_combat_cues.py', 'tests/test_check_project.py'):
            with self.subTest(path=relative):
                ast.parse((ROOT / relative).read_text(), filename=relative)


if __name__ == '__main__':
    unittest.main()
