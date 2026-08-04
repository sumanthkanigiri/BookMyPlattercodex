#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run() {
  echo "==> $*"
  "$@"
}

run git diff --check

if rg -n '<<<<<<<|=======|>>>>>>>' --glob '!build/**' --glob '!.dart_tool/**' --glob '!tool/project_audit.sh' .; then
  echo 'Conflict markers found.'
  exit 1
fi

if rg -n 'TODO|FIXME|mock data|demo data|demo code' --glob '!build/**' --glob '!.dart_tool/**' --glob '!tool/project_audit.sh' --glob '!ios/Runner/Base.lproj/*.storyboard' .; then
  echo 'Prohibited TODO/mock/demo text found.'
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
roots = {
    'bookmyplatter_admin': Path('admin/lib'),
    'bookmyplatter': Path('lib'),
    'bookmyplatter_website': Path('website/lib'),
}
missing = []
for root in [Path('admin/lib'), Path('lib'), Path('website/lib')]:
    if not root.exists():
        continue
    for path in root.rglob('*.dart'):
        for line in path.read_text().splitlines():
            line = line.strip()
            if line.startswith("import 'package:") and '/src/' in line:
                package = line.split('package:', 1)[1].split('/', 1)[0]
                rest = line.split(package + '/', 1)[1].split("'", 1)[0]
                base = roots.get(package)
                if base and not (base / rest).exists():
                    missing.append((str(path), line, str(base / rest)))
if missing:
    for item in missing:
        print(item)
    raise SystemExit(1)
print('checked package imports')
PY

if command -v dart >/dev/null 2>&1; then
  run dart format --set-exit-if-changed lib test admin/lib admin/test website/lib
else
  echo 'WARN: dart is not installed; skipping dart format check.'
fi

if command -v flutter >/dev/null 2>&1; then
  for package in . admin website; do
    (cd "$package" && run flutter pub get && run flutter analyze)
    if [ -d "$package/test" ]; then
      (cd "$package" && run flutter test)
    fi
  done
else
  echo 'WARN: flutter is not installed; skipping Flutter analysis/tests.'
fi

if command -v deno >/dev/null 2>&1; then
  run deno lint supabase/functions
  run deno check supabase/functions/*/index.ts
else
  echo 'WARN: deno is not installed; skipping edge function checks.'
fi

if command -v supabase >/dev/null 2>&1; then
  run supabase db lint --local --level error
else
  echo 'WARN: supabase CLI is not installed; skipping Supabase lint.'
fi
