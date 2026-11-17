#!/usr/bin/env python3
"""Prepare a pinned Godot for a Linux x86_64 development agent, not the user's PC.
No sudo, account credentials, cloud provisioning, paid CI, or repository reset.
Downloading/installing the engine is NOT a project test. --check runs the real
existing project checker and propagates its result (0 pass, 1 fail, 2 unverified).
"""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile

VERSION = '4.7.2'
FILENAME = 'Godot_v4.7.2-stable_linux.x86_64.zip'
EXECUTABLE = FILENAME.removesuffix('.zip')
URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/' + FILENAME
ARCHIVE_SHA256 = 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'
MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
MAX_BINARY_BYTES = 512 * 1024 * 1024
ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(block)
    return hasher.hexdigest()


def verify_archive(path: Path) -> None:
    if not path.is_file() or not 0 < path.stat().st_size <= MAX_ARCHIVE_BYTES:
        raise ValueError('Missing or oversized Godot archive')
    if digest(path) != ARCHIVE_SHA256:
        raise ValueError('Godot archive checksum mismatch; do not execute it')


def fetch_archive(destination: Path) -> None:
    request = urllib.request.Request(URL, headers={'User-Agent': 'Viya-Dev-Bootstrap/1'})
    total = 0
    with urllib.request.urlopen(request, timeout=20) as response, destination.open('wb') as out:
        while block := response.read(1024 * 1024):
            total += len(block)
            if total > MAX_ARCHIVE_BYTES:
                raise ValueError('Download exceeded the pinned archive size limit')
            out.write(block)
    verify_archive(destination)


def prepare(cache: Path, supplied: Path | None) -> Path:
    if platform.system() != 'Linux' or platform.machine().lower() not in ('x86_64', 'amd64'):
        raise ValueError('This bootstrap is Linux x86_64 only; never substitute another build silently')
    cache.mkdir(parents=True, exist_ok=True)
    cached_archive = cache / FILENAME
    executable = cache / EXECUTABLE
    # Always verify the original archive and extract only its expected executable.
    # Cached executable bytes are not trusted merely because a filename exists.
    with tempfile.TemporaryDirectory(prefix='prepare-', dir=cache) as directory:
        staging = Path(directory)
        archive = supplied if supplied is not None else cached_archive
        if not archive.exists():
            if supplied is not None:
                raise FileNotFoundError('The supplied offline archive does not exist')
            archive = staging / FILENAME
            fetch_archive(archive)
        verify_archive(archive)
        staged_binary = staging / EXECUTABLE
        with zipfile.ZipFile(archive) as bundle:
            entries = [entry for entry in bundle.infolist() if entry.filename == EXECUTABLE]
            if len(entries) != 1:
                raise ValueError('The expected executable is missing or duplicated in the archive')
            entry = entries[0]
            if entry.is_dir() or stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError('The executable must be a regular file')
            if not 0 < entry.file_size <= MAX_BINARY_BYTES:
                raise ValueError('Unexpected executable size')
            with bundle.open(entry) as source, staged_binary.open('wb') as out:
                shutil.copyfileobj(source, out, 1024 * 1024)
        staged_binary.chmod(0o755)
        version = subprocess.run([str(staged_binary), '--headless', '--version'],
                                 capture_output=True, text=True, timeout=30)
        lines = (version.stdout + version.stderr).splitlines()
        if version.returncode != 0 or not any(line.strip().startswith(VERSION + '.stable.') for line in lines):
            raise RuntimeError('Pinned Godot did not start correctly: ' + '\n'.join(lines)[-1200:])
        if archive != cached_archive:
            staged_archive = staging / 'verified.zip'
            shutil.copyfile(archive, staged_archive)
            os.replace(staged_archive, cached_archive)
        os.replace(staged_binary, executable)
    return executable


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Optional already-downloaded official ZIP (same checksum)')
    parser.add_argument('--cache', type=Path,
                        default=Path.home() / '.cache' / 'viya' / 'godot' / VERSION)
    parser.add_argument('--check', action='store_true', help='After setup, run the REAL repository checker')
    args = parser.parse_args()
    try:
        engine = prepare(args.cache.expanduser().resolve(), args.archive.expanduser().resolve() if args.archive else None)
    except (OSError, ValueError, RuntimeError, urllib.error.URLError,
            zipfile.BadZipFile, subprocess.SubprocessError) as error:
        print('ENVIRONMENT_NOT_READY: ' + str(error), file=sys.stderr)
        print('No project engine test ran. Preserve NOT_VERIFIED; fix network/dependencies or provide the verified archive.', file=sys.stderr)
        return 2
    print('GODOT_EXECUTABLE=' + str(engine), flush=True)
    print('Engine setup succeeded. This alone is not a game-test PASS.', flush=True)
    if args.check:
        try:
            return subprocess.run([sys.executable, str(ROOT / 'tools' / 'check_project.py'),
                                   '--godot', str(engine)], cwd=ROOT, check=False).returncode
        except OSError as error:
            print('CHECKER_FAILED: ' + str(error), file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
