"""Offline official-SDK bridge tests: no uploads, credentials or paid requests."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'viya_higgsfield', Path(__file__).resolve().parents[1] / 'tools/higgsfield/art_client.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class FakeSDK:
    def __init__(self, send_error=False):
        self.created = 0
        self.sent = 0
        self.uploads = []
        self.send_error = send_error
        self.result = SimpleNamespace(status=SimpleNamespace(value='running'), messages=[])
        self.agents = SimpleNamespace(sessions=self, media=self)

    def create(self):
        self.created += 1
        return SimpleNamespace(session_id='session-test')

    def upload(self, data, **_options):
        self.uploads.append(data)
        return f'https://assets.example.test/input-{len(self.uploads)}'

    def send(self, _session, content):
        self.sent += 1
        self.content = content
        if self.send_error:
            raise TimeoutError('This provider error text must not be printed or saved')
        return 'message-test'

    def messages(self, _session, after=None):
        return self.result


class HiggsfieldBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.journal = self.folder / 'run.json'
        rows = []
        for role, relative in bridge.REFERENCES:
            data = b'\x89PNG\r\n\x1a\n' + role.encode()
            file = self.folder / relative
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(data)
            rows.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest()})
        (self.folder / 'service_job.json').write_text(json.dumps({'files': rows}))
        (self.folder / 'EDIT_PROMPT_EN.txt').write_text('Repair this existing frame only.')

    def test_missing_credentials_never_claim_authenticated(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(
                bridge.importlib.metadata, 'version', return_value=bridge.SDK_VERSION):
            state = bridge.check()
        self.assertEqual(state['status'], 'MISSING_CREDENTIALS')
        self.assertEqual(state['authentication'], 'NOT_VERIFIED')
        self.assertFalse(state['generation_submitted'])

    def test_configured_key_is_never_returned(self):
        with patch.dict(os.environ, {'HF_KEY': 'dummy-id:dummy-secret'}, clear=True), patch.object(
                bridge.importlib.metadata, 'version', return_value=bridge.SDK_VERSION):
            state = bridge.check()
        self.assertEqual(state['credential_names'], ['HF_KEY'])
        self.assertNotIn('dummy-secret', json.dumps(state))
        self.assertEqual(state['authentication'], 'NOT_VERIFIED')

    def test_missing_key_prevents_creating_session_or_journal(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(RuntimeError):
                bridge.submit(self.folder, self.journal)
        self.assertFalse(self.journal.exists())

    def test_changed_reference_fails_before_any_service_action(self):
        file = self.folder / bridge.REFERENCES[0][1]
        file.write_bytes(b'\x89PNG\r\n\x1a\nmodified')
        sdk = FakeSDK()
        with self.assertRaises(ValueError):
            bridge.submit(self.folder, self.journal, sdk)
        self.assertEqual(sdk.created, 0)
        self.assertEqual(sdk.sent, 0)

    def test_single_send_uses_four_verified_reference_bytes(self):
        sdk = FakeSDK()
        result = bridge.submit(self.folder, self.journal, sdk)
        self.assertEqual(result['status'], 'SUBMITTED')
        self.assertEqual(sdk.created, 1)
        self.assertEqual(sdk.sent, 1)
        self.assertEqual(len(sdk.uploads), 4)
        self.assertIn('exactly ONE image correction trial', sdk.content)
        self.assertEqual(self.journal.stat().st_mode & 0o777, 0o600)

    def test_existing_journal_never_resubmits(self):
        sdk = FakeSDK()
        bridge.submit(self.folder, self.journal, sdk)
        with self.assertRaises(ValueError):
            bridge.submit(self.folder, self.journal, sdk)
        self.assertEqual(sdk.sent, 1)

    def test_ambiguous_send_timeout_can_only_poll(self):
        sdk = FakeSDK(send_error=True)
        result = bridge.submit(self.folder, self.journal, sdk)
        self.assertEqual(result['status'], 'SEND_UNKNOWN_USE_POLL')
        self.assertNotIn('provider error text', self.journal.read_text())
        self.assertEqual(bridge.poll(self.journal, sdk)['status'], 'running')
        self.assertEqual(sdk.sent, 1)
        with self.assertRaises(ValueError):
            bridge.submit(self.folder, self.journal, sdk)

    def test_result_urls_are_private_and_not_auto_applied(self):
        sdk = FakeSDK()
        bridge.submit(self.folder, self.journal, sdk)
        sdk.result = SimpleNamespace(status=SimpleNamespace(value='idle'), messages=[
            SimpleNamespace(role='assistant', is_terminal=True, status='completed',
                            text='Result for review', asset_urls=['https://assets.example.test/result?signature=private'])])
        result = bridge.poll(self.journal, sdk)
        self.assertEqual(result['assets_unverified'], 1)
        self.assertNotIn('signature', json.dumps(result))
        self.assertEqual(sdk.sent, 1)


if __name__ == '__main__':
    unittest.main()
