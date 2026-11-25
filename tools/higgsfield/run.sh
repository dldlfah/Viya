#!/usr/bin/env bash
set -euo pipefail
viya_hf_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
viya_hf_env="${VIYA_HIGGSFIELD_ENV:-/workspace/.viya-tools/higgsfield-0.2.0/venv}"
if [ ! -x "$viya_hf_env/bin/python" ]; then
  echo 'Higgsfield SDK is not installed. Run bash tools/higgsfield/install.sh.' >&2
  exit 2
fi
exec "$viya_hf_env/bin/python" "$viya_hf_dir/art_client.py" "$@"
