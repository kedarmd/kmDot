#!/usr/bin/env bash
# Validate the entire palette before emitting QML or preview JSON. Never substitute colors.
set -euo pipefail
source_file="${1:?Usage: render-quickshell.sh palette.conf [--json]}"
format="${2:-qml}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mapfile -t roles < "$script_dir/quickshell.roles"
declare -A allowed=() colors=()
for role in "${roles[@]}"; do allowed["$role"]=1; done
while IFS='=' read -r key value || [[ -n "$key" ]]; do
  case "$key" in ''|\#*) continue ;; esac
  if [[ ! "$key" =~ ^[a-z][a-z0-9_]*$ ]] || [[ ! -v "allowed[$key]" ]]; then
    echo "ERROR: Unknown Quickshell role '$key' in $source_file" >&2; exit 1
  fi
  if [[ -v "colors[$key]" ]] || [[ ! "$value" =~ ^\#([[:xdigit:]]{6}|[[:xdigit:]]{8})$ ]]; then
    echo "ERROR: Duplicate or invalid Quickshell role '$key' in $source_file" >&2; exit 1
  fi
  colors["$key"]="$value"
done < "$source_file"
for role in "${roles[@]}"; do
  if [[ ! -v "colors[$role]" ]]; then
    echo "ERROR: Missing Quickshell role '$role' in $source_file" >&2; exit 1
  fi
done
if [[ "$format" == --json ]]; then
  printf '{'
  separator=''
  for role in "${roles[@]}"; do
    printf '%s"%s":"%s"' "$separator" "$role" "${colors[$role]}"
    separator=,
  done
  printf '}\n'
else
  printf 'pragma Singleton\nimport QtQuick\nimport Quickshell\n\n// Generated from %s. Edit the source palette, then sync.\nSingleton {\n' "$(basename "$(dirname "$source_file")")/$(basename "$source_file")"
  for role in "${roles[@]}"; do printf '  readonly property color %s: "%s"\n' "$role" "${colors[$role]}"; done
  printf '}\n'
fi
