#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
repository=${2:-}
package=${3:-}

open_pacman_terminal() {
  local transaction=$1 target=$2 terminal=${KMDOT_LAUNCHER_TERMINAL:-ghostty}
  command -v "$terminal" >/dev/null 2>&1 || {
    echo "Terminal not found: $terminal" >&2
    return 1
  }
  local script='sudo pacman '"$transaction"' --noconfirm -- "$1"; result=$?; printf "\nPacman exited with status %s. Press Enter to close this window. " "$result"; read -r _; exit "$result"'
  setsid nohup "$terminal" -e bash -lc "$script" kmdot-pacman "$target" </dev/null >/dev/null 2>&1 &
  echo "Opened Pacman in $terminal. Complete authentication and review the transaction there."
}

case "$action" in
  list-install)
    # Show only not-installed packages from enabled official Arch repositories.
    installed_list=$(pacman -Qq)
    repository_list=$(pacman -Sl)
    declare -A installed=()
    while IFS= read -r name; do
      [[ -n "$name" ]] && installed["$name"]=1
    done <<< "$installed_list"
    while read -r repo name version _; do
      [[ "$repo" == core || "$repo" == extra || "$repo" == multilib ]] || continue
      [[ -n "$name" && -n "$version" ]] || continue
      [[ -v "installed[$name]" ]] && continue
      printf '%s\t%s\t%s\n' "$name" "$version" "$repo"
    done <<< "$repository_list"
    ;;
  list-remove)
    pacman -Q | awk 'BEGIN { FS = " " } NF >= 2 { printf "%s\t%s\n", $1, $2 }'
    ;;
  info-install|info-remove)
    if [[ "$action" == info-install ]]; then
      [[ "$package" =~ ^[a-zA-Z0-9@._+-]+$ ]] || exit 2
      [[ "$repository" == core || "$repository" == extra || "$repository" == multilib ]] || exit 2
      pacman -Si -- "$repository/$package" 2>/dev/null || exit 1
    else
      [[ "$repository" =~ ^[a-zA-Z0-9@._+-]+$ ]] || exit 2
      pacman -Qi -- "$repository" 2>/dev/null || exit 1
    fi
    ;;
  install)
    [[ "$package" =~ ^[a-zA-Z0-9@._+-]+$ ]] || exit 2
    [[ "$repository" == core || "$repository" == extra || "$repository" == multilib ]] || exit 2
    # Require an exact package match in the synced official repository DB before
    # handing the transaction to polkit. This excludes foreign/AUR packages.
    pacman -Sl "$repository" | awk -v wanted="$package" '$2 == wanted { found=1 } END { exit !found }' || {
      echo "Package is not available in an enabled official Pacman repository." >&2
      exit 1
    }
    open_pacman_terminal "-S --needed" "$repository/$package"
    ;;
  remove)
    [[ "$repository" =~ ^[a-zA-Z0-9@._+-]+$ ]] || exit 2
    pacman -Qq | awk -v wanted="$repository" '$0 == wanted { found=1 } END { exit !found }' || {
      echo "Package is not installed." >&2
      exit 1
    }
    open_pacman_terminal "-Rns" "$repository"
    ;;
  *)
    echo "Usage: package-manager.sh {list-install|list-remove} | {info-install|info-remove} [repository] package | install repository package | remove package" >&2
    exit 2
    ;;
esac
