#!/usr/bin/env bash

set -e
# pipefail: `curl -fsSL … | sh` must fail when the download fails (an empty
# stdin would otherwise make `sh` exit 0 — false success in ensure_mise).
set -o pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Usage: ./install.sh                          (interactive gum choose over all groups)
#        ./install.sh --all                     (non-interactive, default groups only —
#                                               includes handy/opencode/zed via no-AUR
#                                               installers, no AUR for those three)
#        ./install.sh --all [--themed-extras] [--server]
#                                               (defaults plus the given opt-in groups)
#        ./install.sh [--themed-extras] [--server] [--handy]
#                                               (non-interactive, just the given opt-in groups;
#                                                --handy kept for compatibility, handy is a default)

echo '
██╗                   ██████╗              ██╗
██║                   ██╔══██╗             ██║
██║ ██╗ ████████████╗ ██║  ██║  ██████╗  ██████╗
█████╔╝ ██╔══██╔══██║ ██║  ██║ ██╔═══██╗ ╚═██╔═╝
██╔═██╗ ██║  ██║  ██║ ██████╔╝ ╚██████╔╝   ╚████╗
╚═╝ ╚═╝ ╚═╝  ╚═╝  ╚═╝ ╚═════╝   ╚═════╝     ╚═══╝
'

echo "kmDot package installer"
echo ""

# --- Args (parsed before any bootstrap so --help/usage is side-effect free) ---

MODE="interactive"
SELECTED=()
OPT_INS=()

for arg in "$@"; do
  case "$arg" in
    --all) MODE="all" ;;
    --themed-extras|--server|--handy) OPT_INS+=("${arg#--}") ;;
    -h|--help)
      sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: ./install.sh [--all] [--themed-extras] [--server] [--handy]" >&2
      exit 2
      ;;
  esac
done

# --- Bootstrap: git + base-devel (needed for yay below) ---

if ! command -v git &>/dev/null || ! command -v makepkg &>/dev/null; then
  echo "Installing git and base-devel..."
  sudo pacman -S --noconfirm --needed git base-devel
  echo "git and base-devel installed."
fi

# --- Bootstrap: yay (AUR helper) ---

install_yay() {
  if command -v yay &>/dev/null; then
    echo "yay is already installed."
    return
  fi

  echo "Installing yay from AUR..."
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
  echo "yay installed."
}

install_yay

# --- Bootstrap: gum (needed by config scripts) ---

if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  sudo pacman -S --noconfirm --needed gum
  echo "gum installed."
fi

# --- Bootstrap: mise (sole Node provider) + Node.js ---
# mise owns Node — there is no pacman fallback. install.sh bootstraps mise
# itself, installs the pinned Node from .mise.toml, and pins it globally so
# GUI-launched processes (quickshell, keybind-spawned toggle.sh) resolve node
# through the shims dir on PATH (see config/hyprland/env.lua).
# Non-interactive throughout: shell activation only fires at prompt time, so
# everything here uses plain `mise` / `mise exec`, never activation.

export PATH="$HOME/.local/bin:$PATH"

# Bootstrap: mise via the upstream install pipe. curl|sh here is an accepted
# risk (mise publishes no versioned checksums for the bootstrap script);
# every versioned payload below (opencode, handy, zed installer) is pinned,
# and handy + the zed install script are hash-verified.
ensure_mise() {
  if command -v mise &>/dev/null; then
    echo "mise is already installed."
    return 0
  fi

  echo -n "Installing mise... "
  if err=$(curl -fsSL https://mise.run | sh 2>&1); then
    echo "done."
  else
    echo "FAILED"
    head -5 <<<"$err"
    echo "mise is required (sole Node provider) — aborting." >&2
    exit 1
  fi
}

ensure_node_via_mise() {
  echo "Ensuring Node.js 24 via mise..."
  if err=$(cd "$REPO_DIR" && mise install 2>&1); then
    # Global pin: shims resolve per-directory config, and GUI-launched
    # processes run outside the repo — without a global default, `node`
    # via shims finds no version there. Idempotent rewrite of one entry.
    if err=$(mise use -g node@24 2>&1); then
      if node_ver=$(cd "$REPO_DIR" && mise exec -- node --version 2>/dev/null) \
        && (cd "$REPO_DIR" && mise exec -- npm --version &>/dev/null) \
        && (cd /tmp && mise exec -- node --version &>/dev/null); then
        echo "Node.js installed ($node_ver, npm bundled)."
      else
        echo "mise installed Node but node/npm failed verification." >&2
        exit 1
      fi
    else
      echo "mise global node pin FAILED"
      head -5 <<<"$err"
      exit 1
    fi
  else
    echo "mise install FAILED"
    head -5 <<<"$err"
    exit 1
  fi
}

ensure_mise
ensure_node_via_mise

# --- Package mapping ---
# Key = config directory name (matches sync/<name>.sh)
# Value = pacman/yay package name(s), space-separated for multi-package entries
# Empty value = config-only, skip with a note

declare -A PKGS
PKGS["fish"]="fish"
PKGS["ghostty"]="ghostty"
PKGS["herdr"]="herdr-bin"
PKGS["hyprland"]="hyprland hypridle hyprlock hyprshot awww"
PKGS["nvim"]="neovim"
PKGS["quickshell"]="quickshell"
PKGS["sddm"]="sddm"
PKGS["starship"]="starship"
PKGS["tmux"]="tmux"
PKGS["xdg-desktop-portal"]="xdg-desktop-portal xdg-desktop-portal-hyprland"
PKGS["battery"]=""
PKGS["theme-switcher"]=""
PKGS["runtime"]="ttf-jetbrains-mono-nerd networkmanager network-manager-applet pipewire wireplumber pipewire-pulse bluez blueman wl-clipboard brightnessctl upower jq playerctl curl libnotify power-profiles-daemon lua gnome-keyring nautilus zen-browser"
# No-AUR apps: empty here — owned by install_opencode/install_zed/
# install_handy below (npm global / official script / upstream AppImage).
PKGS["opencode"]=""
PKGS["zed"]=""
PKGS["handy"]=""
# Opt-in groups: visible in the picker, excluded from --all
PKGS["themed-extras"]="btop"
PKGS["server"]="tailscale jellyfin-server docker containerd"

# Canonical order for display (includes opt-in groups)
APPS=(
  "battery"
  "fish"
  "ghostty"
  "handy"
  "herdr"
  "hyprland"
  "nvim"
  "opencode"
  "quickshell"
  "runtime"
  "sddm"
  "server"
  "starship"
  "theme-switcher"
  "themed-extras"
  "tmux"
  "xdg-desktop-portal"
  "zed"
)

# Default groups installed by --all (opt-in groups excluded).
# handy/opencode/zed are defaults — installed via no-AUR installers, not AUR.
DEFAULT_APPS=(
  "battery"
  "fish"
  "ghostty"
  "handy"
  "herdr"
  "hyprland"
  "nvim"
  "opencode"
  "quickshell"
  "runtime"
  "sddm"
  "starship"
  "theme-switcher"
  "tmux"
  "xdg-desktop-portal"
  "zed"
)

# --- Selection (APPS known here; interactive picker needs gum above) ---

if [[ "$MODE" == "all" ]]; then
  # Dedupe: --all already includes handy, so --all --handy must not double it.
  SELECTED=($(printf "%s\n" "${DEFAULT_APPS[@]}" "${OPT_INS[@]}" | awk '!seen[$0]++'))
elif [ ${#OPT_INS[@]} -gt 0 ]; then
  MODE="opt-in"
  SELECTED=("${OPT_INS[@]}")
fi

if [[ "$MODE" == "interactive" ]]; then
  while IFS= read -r app; do
    [ -n "$app" ] && SELECTED+=("$app")
  done < <(
    gum choose \
      --header="Select apps to install packages for:" \
      --unselected-prefix="[ ] " \
      --selected-prefix="[x] " \
      --no-limit \
      --height=$(( ${#APPS[@]} + 2 )) \
      "${APPS[@]}"
  )
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "No apps selected. Exiting."
  exit 0
fi

echo ""
echo "Installing packages for: ${SELECTED[*]}"
echo ""

# --- Install packages ---
# Failures are collected, not fatal: one bad package must not hide the
# rest, and the summary + nonzero exit lets callers react.

FAILED_PKGS=()

# Single pacman/yay install with skip-if-present + failure reporting.
# Prefer pacman for official repos, fall back to yay for AUR.
install_pkg() {
  local pkg="$1"

  if pacman -Qi "$pkg" &>/dev/null; then
    echo "  $pkg: already installed."
    return 0
  fi

  echo -n "  Installing $pkg... "
  if pacman -Si "$pkg" &>/dev/null; then
    if err=$(sudo pacman -S --noconfirm --needed "$pkg" 2>&1); then
      echo "done."
    else
      echo "FAILED"
      head -5 <<<"$err"
      FAILED_PKGS+=("$pkg")
    fi
  else
    if err=$(yay -S --noconfirm --needed "$pkg" 2>&1); then
      echo "done."
    else
      echo "FAILED"
      head -5 <<<"$err"
      FAILED_PKGS+=("$pkg")
    fi
  fi
}

# No-AUR installers. Each is idempotent (skip-if-present) and reports via
# FAILED_PKGS like install_pkg. Non-interactive: `mise exec` everywhere —
# activation only fires at prompt time, so scripts must not rely on it.

install_opencode() {
  if pacman -Qi opencode-bin &>/dev/null; then
    echo "  WARNING: AUR package opencode-bin is installed and may shadow the npm install."
    echo "  Remove it with: yay -Rns opencode-bin"
  fi
  if (cd "$REPO_DIR" && mise exec -- opencode --version &>/dev/null); then
    echo "  opencode: already installed."
    return 0
  fi

  echo -n "  Installing opencode v$OPENCODE_VERSION (npm -g)... "
  # Never --ignore-scripts: the shipped bin is a stub until postinstall
  # copies the platform binary over it.
  npm_err=""
  postinstall_err=""
  npm_err=$(cd "$REPO_DIR" && mise exec -- npm install -g "opencode-ai@$OPENCODE_VERSION" 2>&1) || true
  if (cd "$REPO_DIR" && mise exec -- opencode --version &>/dev/null); then
    echo "done."
    return 0
  fi
  # npm may fail after extracting the package (postinstall stub left
  # behind) — retry postinstall whenever the package dir is present,
  # even when the npm step itself failed.
  if npm_root=$(cd "$REPO_DIR" && mise exec -- npm root -g 2>/dev/null) \
    && [[ -f "$npm_root/opencode-ai/postinstall.mjs" ]] \
    && postinstall_err=$(cd "$REPO_DIR" && mise exec -- node "$npm_root/opencode-ai/postinstall.mjs" 2>&1) \
    && (cd "$REPO_DIR" && mise exec -- opencode --version &>/dev/null); then
    echo "done (postinstall retried)."
  else
    echo "FAILED (postinstall recovery failed)"
    if [[ -n "$postinstall_err" ]]; then
      head -5 <<<"$postinstall_err"
    else
      head -5 <<<"$npm_err"
    fi
    FAILED_PKGS+=("opencode")
  fi
}

install_zed() {
  if command -v zed &>/dev/null; then
    echo "  zed: already installed."
    return 0
  fi

  echo -n "  Installing zed (official install script)... "
  tmp=$(mktemp) || { echo "FAILED (mktemp)"; FAILED_PKGS+=("zed"); return 0; }
  if err=$(curl -fSL -o "$tmp" https://zed.dev/install.sh 2>&1); then
    if echo "$ZED_INSTALL_SHA256  $tmp" | sha256sum -c - &>/dev/null; then
      if err=$(sh "$tmp" 2>&1); then
        rm -f "$tmp"
        echo "done."
      else
        rm -f "$tmp"
        echo "FAILED"
        head -5 <<<"$err"
        FAILED_PKGS+=("zed")
      fi
    else
      rm -f "$tmp"
      echo "FAILED (install script hash mismatch — zed.dev/install.sh changed upstream; update ZED_INSTALL_SHA256)"
      FAILED_PKGS+=("zed")
    fi
  else
    rm -f "$tmp"
    echo "FAILED"
    head -5 <<<"$err"
    FAILED_PKGS+=("zed")
  fi
}

# Pinned — never resolve "latest" at install time.
# OPENCODE_VERSION: latest opencode-ai on npm as of 2026-10-03
#   (`npm view opencode-ai versions`); re-verify on bump.
# HANDY_VERSION + HANDY_SHA256: GitHub release v0.9.7 asset
#   Handy_0.9.7_amd64.AppImage (sha256 computed 2026-10-03); re-verify on bump.
# ZED_INSTALL_SHA256: https://zed.dev/install.sh fetched 2026-10-03. Pins the
#   installer logic; the script itself tracks Zed stable (Zed publishes no
#   versioned checksums for the script path) — accepted residual risk.
OPENCODE_VERSION="1.18.34"
HANDY_VERSION="0.9.7"
HANDY_SHA256="e0625120b5a5c1d45e1e536b9d20f5220e7558e50c701e72e014f99c948e363a"
ZED_INSTALL_SHA256="c42e96c9e3da1fae61ac11b0922ad033e8fcac3c34b44303805ad3796081b502"

install_handy() {
  if [[ -x "$HOME/.local/bin/handy" ]]; then
    echo "  handy: already installed."
    return 0
  fi
  if pacman -Qi handy-bin &>/dev/null; then
    echo "  WARNING: AUR package handy-bin is installed and may shadow ~/.local/bin/handy."
    echo "  Remove it with: yay -Rns handy-bin"
  fi
  # Runtime deps from official repos: fuse2 runs the AppImage,
  # gtk-layer-shell is the overlay window layer.
  install_pkg "gtk-layer-shell"
  install_pkg "fuse2"

  mkdir -p "$HOME/.local/bin"
  echo -n "  Installing handy v$HANDY_VERSION (upstream AppImage)... "
  tmp=$(mktemp "$HOME/.local/bin/.handy.XXXXXX") || { echo "FAILED (mktemp)"; FAILED_PKGS+=("handy"); return 0; }
  if err=$(curl -fSL -o "$tmp" \
    "https://github.com/cjpais/Handy/releases/download/v$HANDY_VERSION/Handy_${HANDY_VERSION}_amd64.AppImage" 2>&1) \
    && echo "$HANDY_SHA256  $tmp" | sha256sum -c - &>/dev/null \
    && chmod +x "$tmp" \
    && mv "$tmp" "$HOME/.local/bin/handy"; then
    echo "done."
  else
    echo "FAILED (download or checksum mismatch — upstream asset may have changed; re-verify HANDY_SHA256)"
    head -5 <<<"$err"
    rm -f "$tmp"
    FAILED_PKGS+=("handy")
  fi
}

for app in "${SELECTED[@]}"; do
  case "$app" in
    opencode) install_opencode; continue ;;
    zed) install_zed; continue ;;
    handy) install_handy; continue ;;
  esac

  pkgs="${PKGS[$app]:-}"

  if [ -z "$pkgs" ]; then
    echo "  $app: config-only, no package to install."
    continue
  fi

  for pkg in $pkgs; do
    install_pkg "$pkg"
  done
done

echo ""
if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
  echo "Failed packages: ${FAILED_PKGS[*]}" >&2
  echo "Fix the failures above, then re-run ./install.sh (installed packages are skipped)."
  exit 1
fi
echo "All done!"
echo ""
echo "Next step: run ./config-install.sh to deploy config files."
