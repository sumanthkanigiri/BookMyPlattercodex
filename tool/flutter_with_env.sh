#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_file="${ENV_FILE:-$repository_root/.env}"

if [[ ! -f "$environment_file" ]]; then
  printf 'Missing environment file: %s\n' "$environment_file" >&2
  printf 'Create it with SUPABASE_URL, SUPABASE_ANON_KEY, and PROJECT_ID.\n' >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$environment_file"
set +a

required_variables=(SUPABASE_URL SUPABASE_ANON_KEY PROJECT_ID GOOGLE_MAPS_API_KEY)
for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    printf 'Missing required value %s in %s\n' "$variable" "$environment_file" >&2
    exit 1
  fi
done

expected_host="$PROJECT_ID.supabase.co"
configured_host="${SUPABASE_URL#https://}"
configured_host="${configured_host%%/*}"
if [[ "$configured_host" == *.supabase.co && "$configured_host" != "$expected_host" ]]; then
  printf 'PROJECT_ID does not match the project reference in SUPABASE_URL.\n' >&2
  exit 1
fi

cd "$repository_root/${FLUTTER_APP_DIR:-.}"

flutter "${1:-run}" "${@:2}" \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --dart-define="PROJECT_ID=$PROJECT_ID" \
  --dart-define="GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY"
