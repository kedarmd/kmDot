#!/usr/bin/env bash
set -uo pipefail

# Pacman remains the transaction authority. This launcher previews with Pacman's
# non-committing print mode, then leaves the final transaction summary and
# confirmation to a normal `pacman -Syu` invocation.

action=${1:-}
script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.local/share/mise/shims:$PATH"
preflight_tmp_dir=""

cleanup_preflight() {
  if [[ -n "$preflight_tmp_dir" && -d "$preflight_tmp_dir" ]]; then
    rm -rf -- "$preflight_tmp_dir"
  fi
}

open_terminal() {
  local terminal=${KMDOT_LAUNCHER_TERMINAL:-ghostty}
  command -v "$terminal" >/dev/null 2>&1 || {
    printf 'Terminal not found: %s\n' "$terminal" >&2
    return 1
  }
  setsid nohup "$terminal" -e bash -lc '"$1" run; status=$?; printf "\\nSystem-upgrade flow finished with status %s. Press Enter to close this window. " "$status"; read -r _; exit "$status"' kmdot-system-upgrade "$script_path" </dev/null >/dev/null 2>&1 &
  printf 'Opened the system-upgrade preflight in %s.\n' "$terminal"
}

human_kib() {
  awk -v kib="$1" 'BEGIN {
    value = kib * 1024
    split("B KiB MiB GiB TiB", units, " ")
    unit = 1
    while (value >= 1024 && unit < 5) { value /= 1024; unit++ }
    printf "%.1f %s", value, units[unit]
  }'
}

plan_summary() {
  local installed_file=$1 targets_file=$2 root_space=$3 boot_space=$4 efi_space=$5 pending_configs=$6
  awk -F'|' -v root_space="$root_space" -v boot_space="$boot_space" -v efi_space="$efi_space" -v pending_configs="$pending_configs" '
    FNR == NR { installed[$1] = $2; next }
    NF >= 4 && $1 ~ /^[[:alnum:]@._+-]+$/ && $2 != "" {
      count++
      base = $4 == "" ? $1 : $4
      bases[base] = 1
      if (!($1 in installed)) new_targets++
      else if (installed[$1] != $2) version_changes++
      if ($1 ~ /^linux(-|$)/) kernel = 1
      if ($1 ~ /^(lib32-)?(mesa($|-)|vulkan-|nvidia|amdvlk|libdrm|xf86-video-)/) graphics = 1
      if ($1 ~ /^(glibc|systemd(-|$)|pacman|grub(-|$)|mkinitcpio(-|$)|dracut(-|$)|openssl(-|$)|cryptsetup(-|$)|sudo)$/) core = 1
      if ($1 ~ /^(hyprland|quickshell|qt[56]-|kwin|plasma-)/) desktop = 1
    }
    END {
      for (base in bases) base_count++
      printf "Local report: %d Pacman targets across %d package bases", count, base_count
      if (version_changes > 0) printf "; %d installed versions change", version_changes
      if (new_targets > 0) printf "; %d targets are new package names", new_targets
      details = ""
      if (kernel) details = details (details == "" ? "" : ", ") "kernel"
      if (graphics) details = details (details == "" ? "" : ", ") "graphics stack"
      if (core) details = details (details == "" ? "" : ", ") "core system"
      if (desktop) details = details (details == "" ? "" : ", ") "desktop stack"
      if (details != "") printf "; includes %s updates", details
      if (root_space != "") printf "; / has %s free", root_space
      if (boot_space != "") printf "; /boot has %s free", boot_space
      if (efi_space != "") printf "; EFI partition has %s free", efi_space
      if (pending_configs > 0) printf "; %d pre-existing .pacnew/.pacsave files", pending_configs
      printf "."
    }
  ' "$installed_file" "$targets_file"
}

run_preflight() {
  local preview_file dbcheck_file installed_file targets_file disk_file preview_status db_status target_count known_notice_errors
  local root_kib boot_kib efi_kib root_space boot_space efi_space pending_configs summary snapshot_choice proceed_choice snapshot_id
  preflight_tmp_dir=$(mktemp -d)
  preview_file="$preflight_tmp_dir/pacman-preview"
  dbcheck_file="$preflight_tmp_dir/pacman-db-check"
  installed_file="$preflight_tmp_dir/installed-packages"
  targets_file="$preflight_tmp_dir/upgrade-targets"
  disk_file="$preflight_tmp_dir/disk-space"
  trap cleanup_preflight EXIT

  if ! command -v pacman >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
    printf 'Preflight failed: Pacman or sudo is unavailable. No packages were changed.\n'
    return 1
  fi

  printf 'Refreshing official repositories and asking Pacman for an upgrade preview…\n'
  sudo pacman --color never -Syu --print --print-format '%n|%v|%r|%e' 2>&1 \
    | tee "$preview_file" \
    | awk -F'|' 'index($0, "|") == 0 { print; fflush() }'
  preview_status=$?
  if (( preview_status != 0 )); then
    printf '\nPreflight failed: Pacman could not refresh repositories or calculate its preview. No packages were changed.\n'
    printf 'The Pacman error is shown above. This can happen when the network or a configured mirror is unavailable; reconnect and retry.\n'
    return 1
  fi

  awk -F'|' 'NF >= 4 && $1 ~ /^[[:alnum:]@._+-]+$/ && $2 != "" { print }' "$preview_file" >"$targets_file"
  target_count=$(wc -l <"$targets_file")
  if (( target_count == 0 )); then
    printf 'Pacman reports that this system is already up to date. No snapshot or upgrade is needed.\n'
    return 0
  fi

  pacman -Q >"$installed_file" 2>"$dbcheck_file"
  if [[ $? -ne 0 ]]; then
    printf 'Preflight blocked: Pacman could not read the installed package database. No packages were changed.\n'
    cat "$dbcheck_file"
    return 1
  fi

  LC_ALL=C pacman -Dk >"$dbcheck_file" 2>&1
  db_status=$?
  if (( db_status != 0 )); then
    local known_notice_errors
    known_notice_errors=$(grep -c . "$dbcheck_file" || true)
    if (( known_notice_errors == 2 )) \
      && grep -Fxq "error: 'CACHY_UPDATE_NOTICE': description file is missing" "$dbcheck_file" \
      && grep -Fxq "error: 'CACHY_UPDATE_NOTICE': file list is missing" "$dbcheck_file"; then
      printf 'Preflight note: ignoring CachyOS pacman’s known CACHY_UPDATE_NOTICE metadata warning; no dependency errors were reported.\n'
    else
      printf 'Preflight blocked: Pacman reported local package database or dependency errors. No packages were changed.\n\n'
      cat "$dbcheck_file"
      return 1
    fi
  fi

  df -Pk / /boot /boot/efi >"$disk_file" 2>/dev/null || true
  root_kib=$(awk 'NR > 1 && $6 == "/" { print $4; exit }' "$disk_file")
  boot_kib=$(awk 'NR > 1 && $6 == "/boot" { print $4; exit }' "$disk_file")
  efi_kib=$(awk 'NR > 1 && $6 == "/boot/efi" { print $4; exit }' "$disk_file")
  root_space=""
  boot_space=""
  efi_space=""
  [[ "$root_kib" =~ ^[0-9]+$ ]] && root_space=$(human_kib "$root_kib")
  [[ "$boot_kib" =~ ^[0-9]+$ ]] && boot_space=$(human_kib "$boot_kib")
  [[ "$efi_kib" =~ ^[0-9]+$ ]] && efi_space=$(human_kib "$efi_kib")
  pending_configs=$(find /etc -xdev -type f \( -name '*.pacnew' -o -name '*.pacsave' \) -print 2>/dev/null | wc -l)
  summary=$(plan_summary "$installed_file" "$targets_file" "$root_space" "$boot_space" "$efi_space" "$pending_configs")

  printf '\n%s\n' "$summary"
  printf 'Pacman checks: repository refresh and installed dependency check passed.\n'
  printf 'Pacman will calculate its native transaction summary after you proceed; it may still report removals, conflicts, or other issues.\n\n'

  while true; do
    read -r -p 'Proceed to the snapshot choice, or exit? [P/e] ' proceed_choice
    proceed_choice=${proceed_choice,,}
    case "$proceed_choice" in
      ''|p|proceed) break ;;
      e|exit)
        printf 'Exited. No packages were changed.\n'
        return 0
        ;;
      *) printf 'Choose P to proceed or E to exit.\n' ;;
    esac
  done

  read -r -p 'Create a Snapper root snapshot before the upgrade? [Y/n] ' snapshot_choice
  snapshot_choice=${snapshot_choice,,}
  if [[ -z "$snapshot_choice" || "$snapshot_choice" == y || "$snapshot_choice" == yes ]]; then
    if ! command -v snapper >/dev/null 2>&1 || ! snapper list-configs 2>/dev/null | awk '$1 == "root" { found=1 } END { exit !found }'; then
      printf 'Preflight blocked: the Snapper root configuration is unavailable. No packages were changed.\n'
      return 1
    fi
    snapshot_id=$(sudo snapper -c root create --print-number --type single --description 'Before full system upgrade' 2>&1)
    if [[ $? -ne 0 || ! "$snapshot_id" =~ ^[0-9]+$ ]]; then
      printf 'Preflight blocked: Snapper could not create a verified root snapshot. No packages were changed.\n%s\n' "$snapshot_id"
      return 1
    fi
    printf 'Created Snapper root snapshot #%s. Separate subvolumes such as /home and /var are not included.\n' "$snapshot_id"
  else
    printf 'Continuing without a pre-upgrade snapshot, as requested.\n'
  fi

  printf '\nStarting Pacman. Review its final transaction summary and confirm there to apply the upgrade.\n\n'
  sudo pacman -Syu
  local pacman_status=$?
  printf '\nPacman exited with status %s.\n' "$pacman_status"
  return "$pacman_status"
}

case "$action" in
  launch) open_terminal ;;
  run) run_preflight ;;
  *) printf 'Usage: system-upgrade.sh {launch|run}\n' >&2; exit 2 ;;
esac
