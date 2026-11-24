#!/usr/bin/env bash
# Read-only check of literal repo paths and config installer mappings.
set -eu
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
failed=0

while IFS= read -r app; do
  if [[ ! -x "sync/$app.sh" ]]; then
    printf 'config-install.sh: missing executable sync/%s.sh\n' "$app" >&2
    failed=1
  fi
done < <(sed -n '/^APPS=(/,/^)/s/^[[:space:]]*"\([a-z0-9_-]*\)"[[:space:]]*$/\1/p' config-install.sh)

for script in sync/*.sh; do
  while IFS= read -r path; do
    # Variable paths are resolved by the sync script at runtime.
    [[ "$path" == *'$'* || "$path" == *'*'* ]] && continue
    if [[ ! -e "$path" ]]; then
      printf '%s: missing %s\n' "$script" "$path" >&2
      failed=1
    fi
  done < <(sed -n 's/^[[:space:]]*#.*//; s/.*"\$REPO_DIR\/\([^"]*\)".*/\1/p' "$script")
done

if (( failed == 0 )); then
  echo "Config references OK."
fi
exit "$failed"
