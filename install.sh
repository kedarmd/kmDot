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

# --- Bootstrap: tools used by later install/config steps ---

BOOTSTRAP_PKGS=()
command -v curl >/dev/null 2>&1 || BOOTSTRAP_PKGS+=(curl)
command -v git >/dev/null 2>&1 || BOOTSTRAP_PKGS+=(git)
if [ ${#BOOTSTRAP_PKGS[@]} -gt 0 ]; then
  echo "Installing bootstrap tools from the official Arch repositories: ${BOOTSTRAP_PKGS[*]}"
  sudo pacman -S --noconfirm --needed "${BOOTSTRAP_PKGS[@]}"
fi

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
# Value = official pacman package name(s), space-separated for multi-package entries
# Empty value = config-only, skip with a note

declare -A PKGS
PKGS["fish"]="fish"
PKGS["ghostty"]="ghostty"
PKGS["herdr"]=""
PKGS["hyprland"]="hyprland hypridle hyprlock hyprshot awww"
PKGS["nvim"]="neovim gcc make"
PKGS["quickshell"]="quickshell qt6-multimedia qt6-multimedia-ffmpeg qt6-5compat"
PKGS["sddm"]="sddm"
PKGS["starship"]="starship"
PKGS["tmux"]="tmux"
PKGS["xdg-desktop-portal"]="xdg-desktop-portal xdg-desktop-portal-hyprland"
PKGS["battery"]=""
PKGS["theme-switcher"]=""
PKGS["runtime"]="ttf-jetbrains-mono-nerd networkmanager network-manager-applet pipewire wireplumber pipewire-pulse bluez blueman wl-clipboard brightnessctl upower jq playerctl curl git ripgrep libnotify power-profiles-daemon lua gnome-keyring nautilus"
# Apps installed from upstream releases/installers; no package helper or AUR.
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

# Official-repository packages only. Third-party packages use a dedicated,
# upstream installer below; this function never invokes an AUR helper.
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
    echo "FAILED (not in official Arch repositories; AUR is disabled)"
    FAILED_PKGS+=("$pkg")
  fi
}

# Upstream installers. Each is idempotent (skip-if-present) and reports via
# FAILED_PKGS like install_pkg. Non-interactive: `mise exec` everywhere —
# activation only fires at prompt time, so scripts must not rely on it.

install_herdr() {
  if [[ -x "$HOME/.local/bin/herdr" ]]; then
    echo "  herdr: already installed from the upstream installer."
    return 0
  fi

  echo -n "  Installing herdr (upstream installer)... "
  tmp=$(mktemp) || { echo "FAILED (mktemp)"; FAILED_PKGS+=("herdr"); return 0; }
  if err=$(curl -fSL -o "$tmp" https://herdr.dev/install.sh 2>&1) \
    && echo "$HERDR_INSTALL_SHA256  $tmp" | sha256sum -c - &>/dev/null \
    && HERDR_INSTALL_DIR="$HOME/.local/bin" sh "$tmp"; then
    rm -f "$tmp"
    echo "done."
  else
    echo "FAILED (download or installer checksum mismatch; re-verify HERDR_INSTALL_SHA256)"
    head -5 <<<"$err"
    rm -f "$tmp"
    FAILED_PKGS+=("herdr")
  fi
}

install_zen() {
  local arch url archive install_dir launcher desktop icon
  if [[ -x "$HOME/.local/bin/zen" ]]; then
    echo "  zen-browser: already installed."
    return 0
  fi

  case "$(uname -m)" in
    x86_64) arch="x86_64" ;;
    *)
      echo "  zen-browser: no pinned upstream binary for $(uname -m)."
      FAILED_PKGS+=("zen-browser")
      return 0
      ;;
  esac

  url="https://github.com/zen-browser/desktop/releases/download/$ZEN_VERSION/zen.linux-$arch.tar.xz"
  echo -n "  Installing Zen Browser v$ZEN_VERSION (upstream binary)... "
  tmpdir=$(mktemp -d) || { echo "FAILED (mktemp)"; FAILED_PKGS+=("zen-browser"); return 0; }
  archive="$tmpdir/zen.tar.xz"
  install_dir="$HOME/.local/opt/zen/$ZEN_VERSION"
  if err=$(curl -fSL -o "$archive" "$url" 2>&1) \
    && echo "$ZEN_SHA256  $archive" | sha256sum -c - &>/dev/null \
    && tar -xJf "$archive" -C "$tmpdir" \
    && [[ -x "$tmpdir/zen/zen" ]] \
    && mkdir -p "$(dirname "$install_dir")" "$HOME/.local/bin" "$HOME/.local/share/applications" \
    && mv "$tmpdir/zen" "$install_dir"; then
    launcher="$HOME/.local/bin/zen"
    desktop="$HOME/.local/share/applications/zen.desktop"
    icon="$install_dir/browser/chrome/icons/default/default128.png"
    cat >"$launcher" <<EOF
#!/usr/bin/env bash
exec "$install_dir/zen" "\$@"
EOF
    chmod +x "$launcher"
    cat >"$desktop" <<EOF
[Desktop Entry]
Name=Zen Browser
Comment=Experience tranquillity while browsing the web
Keywords=web;browser;internet
Exec=$install_dir/zen %u
Icon=$icon
Terminal=false
StartupNotify=true
StartupWMClass=zen
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
    rm -rf "$tmpdir"
    echo "done."
  else
    echo "FAILED (download or checksum mismatch; re-verify ZEN_VERSION and ZEN_SHA256)"
    head -5 <<<"$err"
    rm -rf "$tmpdir"
    FAILED_PKGS+=("zen-browser")
  fi
}

install_opencode() {
  if pacman -Qi opencode-bin &>/dev/null; then
    echo "  WARNING: legacy package opencode-bin may shadow the npm install."
    echo "  Remove it with: sudo pacman -Rns opencode-bin"
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
# HERDR_INSTALL_SHA256 pins the upstream installer script; the installer then
# verifies the downloaded binary against Herdr's release manifest.
# ZEN_VERSION + ZEN_SHA256 pin the official x86_64 release asset.
OPENCODE_VERSION="1.18.34"
HANDY_VERSION="0.9.7"
HANDY_SHA256="e0625120b5a5c1d45e1e536b9d20f5220e7558e50c701e72e014f99c948e363a"
ZED_INSTALL_SHA256="c42e96c9e3da1fae61ac11b0922ad033e8fcac3c34b44303805ad3796081b502"
HERDR_INSTALL_SHA256="bf83668c944cff30b3365eee5a4fe15ff61a4b749ab0c73b98e7a203f70893dd"
ZEN_VERSION="1.24b"
ZEN_SHA256="323f2682e73e38247a51fbcc75e5628ed2bb9b404db00cf9cf16af329a916fae"

install_handy() {
  if [[ -x "$HOME/.local/bin/handy" ]]; then
    echo "  handy: already installed."
    return 0
  fi
  if pacman -Qi handy-bin &>/dev/null; then
    echo "  WARNING: legacy package handy-bin may shadow ~/.local/bin/handy."
    echo "  Remove it with: sudo pacman -Rns handy-bin"
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
    herdr) install_herdr; continue ;;
  esac

  pkgs="${PKGS[$app]:-}"

  if [ -z "$pkgs" ]; then
    echo "  $app: config-only, no package to install."
    continue
  fi

  for pkg in $pkgs; do
    install_pkg "$pkg"
  done

  if [[ "$app" == "runtime" ]]; then
    install_zen
  fi
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
