#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FLUTTER_APP_DIR=website
exec "$repository_root/tool/flutter_with_env.sh" "${1:-run}" "${@:2}"
