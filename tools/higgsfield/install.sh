#!/usr/bin/env bash
set -euo pipefail
viya_hf_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
viya_hf_env="${VIYA_HIGGSFIELD_ENV:-/workspace/.viya-tools/higgsfield-0.2.0/venv}"
if [ ! -x "$viya_hf_env/bin/python" ]; then
  python3 -m venv "$viya_hf_env"
fi
"$viya_hf_env/bin/python" -m pip install --disable-pip-version-check --no-cache-dir --require-hashes -r "$viya_hf_dir/requirements.lock"
