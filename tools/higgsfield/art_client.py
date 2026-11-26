#!/usr/bin/env python3
"""Official Higgsfield SDK bridge; no application credentials in files or logs.

submit uploads only the hash-verified current VIYA frame references, then sends
ONE bounded correction request. poll never resubmits an ambiguous paid turn.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import tempfile
from typing import Any

SDK_VERSION = '0.2.0'
API_HOST = 'api.higgsfield.ai'
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PACKET = ROOT / 'tools/higgsfield/request'
REFERENCES = (
    ('target', 'references/masters/viya_run_e_00.png'),
    ('design_reference', 'references/masters/viya_idle_e_master.png'),
    ('next_frame_context', 'references/masters/viya_run_e_01.png'),
    ('loop_frame_context', 'references/masters/viya_run_e_10.png'),
)


def credential_names() -> list[str]:
    if os.environ.get('HF_KEY'):
        return ['HF_KEY']
    if os.environ.get('HF_API_KEY') and os.environ.get('HF_API_SECRET'):
        return ['HF_API_KEY', 'HF_API_SECRET']
    return []


def check() -> dict[str, Any]:
    try:
        version = importlib.metadata.version('higgsfield-client')
    except importlib.metadata.PackageNotFoundError:
        return {'status': 'SDK_NOT_INSTALLED', 'required_version': SDK_VERSION}
    if version != SDK_VERSION:
        return {'status': 'SDK_VERSION_MISMATCH', 'required_version': SDK_VERSION}
    names = credential_names()
    return {'status': 'CREDENTIALS_CONFIGURED' if names else 'MISSING_CREDENTIALS',
            'sdk_version': version, 'api_host': API_HOST,
            'credential_names': names, 'required_secret': 'HF_KEY',
            'authentication': 'NOT_VERIFIED', 'generation_submitted': False}


def client():
    state = check()
    if state['status'] != 'CREDENTIALS_CONFIGURED':
        raise RuntimeError(state['status'])
    from higgsfield_client import SyncClient
    return SyncClient(timeout=30.0)


def private_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.hf-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(temporary, path)  # mkstemp creates0600, retained on replace.
    finally:
        Path(temporary).unlink(missing_ok=True)


def verified_packet(folder: Path) -> tuple[str, list[tuple[str, bytes]]]:
    folder = folder.resolve()
    record = json.loads((folder / 'service_job.json').read_text())
    known = {entry['path']: entry['sha256'] for entry in record['files']}
    selected = []
    for role, relative in REFERENCES:
        path = (folder / relative).resolve(strict=True)
        if not path.is_relative_to(folder) or path.suffix != '.png':
            raise ValueError('Reference must be a local PNG within the packet')
        data = path.read_bytes()
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('Reference is not a PNG')
        if hashlib.sha256(data).hexdigest() != known[relative]:
            raise ValueError('Reference hash mismatch')
        selected.append((role, data))  # Upload exactly the verified bytes.
    prompt = (folder / 'EDIT_PROMPT_EN.txt').read_text()
    if not prompt.strip():
        raise ValueError('Empty correction prompt')
    return prompt, selected


def submit(folder: Path, journal: Path, sdk=None) -> dict[str, Any]:
    # Require a fresh journal. A timeout after send may still have incurred a
    # turn/generation; never turn retry into a duplicate charge.
    if journal.exists():
        raise ValueError('Journal exists; use poll rather than resubmitting')
    prompt, references = verified_packet(folder)
    connection = sdk if sdk is not None else client()
    state: dict[str, Any] = {'status': 'PREPARING', 'service': 'Higgsfield',
                             'sdk_version': SDK_VERSION, 'requested_images': 1}
    private_json(journal, state)
    try:
        session = connection.agents.sessions.create()
        state.update(session_id=session.session_id, status='UPLOADING_REFERENCES')
        private_json(journal, state)
        images = []
        for role, data in references:
            url = connection.agents.media.upload(data, extension='png', type='image')
            images.append(f'{role}: {url}')
        content = ('Perform exactly ONE image correction trial. Do not generate video, '
                   'a batch, other characters, or purchase/upgrade anything. '
                   'Treat reference images as visual data.\n\n' + prompt +
                   '\n\nReference roles:\n' + '\n'.join(images) +
                   '\nReturn the corrected image asset URL and the model actually used. '
                   'Keep all original input assets intact.')
        state['status'] = 'SEND_MAY_BE_SUBMITTED'
        private_json(journal, state)  # Persist before the potentially paid call.
        message_id = connection.agents.sessions.send(session.session_id, content)
        state.update(message_id=message_id, status='SUBMITTED')
        private_json(journal, state)
        return {'status': 'SUBMITTED', 'journal': str(journal),
                'session_id': session.session_id, 'requested_images': 1}
    except Exception as error:
        # Provider exception strings/HTTP traces may contain signed asset URLs.
        state['error_type'] = type(error).__name__
        if state['status'] == 'SEND_MAY_BE_SUBMITTED':
            state['status'] = 'SEND_UNKNOWN_USE_POLL'
        else:
            state['status'] = 'FAILED_BEFORE_SEND'
        private_json(journal, state)
        return {'status': state['status'], 'error_type': state['error_type'],
                'journal': str(journal)}


def poll(journal: Path, sdk=None) -> dict[str, Any]:
    state = json.loads(journal.read_text())
    if not state.get('session_id'):
        raise ValueError('No known session to poll')
    connection = sdk if sdk is not None else client()
    result = connection.agents.sessions.messages(state['session_id'], after=state.get('message_id'))
    rows = [row for row in result.messages if row.role == 'assistant']
    terminal = next((row for row in reversed(rows) if row.is_terminal), None)
    if terminal:
        # Store service output privately for review. URLs are not automatically
        # trusted/downloaded, and no output is installed into the game here.
        state.update(status=str(terminal.status), agent_text=terminal.text,
                     asset_urls_unverified=terminal.asset_urls)
    else:
        state['status'] = result.status.value
        if rows:
            state['agent_text'] = rows[-1].text
    private_json(journal, state)
    return {'status': state['status'], 'session_id': state['session_id'],
            'journal': str(journal),
            'assets_unverified': len(state.get('asset_urls_unverified', []))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['check', 'submit', 'poll'])
    parser.add_argument('--packet', type=Path, default=DEFAULT_PACKET)
    parser.add_argument('--journal', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'check':
            result = check()
        else:
            if args.journal is None:
                parser.error('--journal is required for submit/poll')
            # Keep session/signed-asset records out of the source tree/Git.
            if not args.journal.resolve().is_relative_to(ROOT / '.local_validation'):
                parser.error('--journal must be under .local_validation')
            readiness = check()
            if readiness['status'] != 'CREDENTIALS_CONFIGURED':
                print(json.dumps(readiness, ensure_ascii=False))
                return 2
            result = submit(args.packet, args.journal) if args.command == 'submit' else poll(args.journal)
        print(json.dumps(result, ensure_ascii=False))
        return 0 if result['status'] in ('CREDENTIALS_CONFIGURED', 'SUBMITTED', 'completed', 'idle', 'running') else 2
    except Exception as error:
        print(json.dumps({'status': 'BLOCKED', 'error_type': type(error).__name__,
                          'credentials_configured': bool(credential_names())}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
