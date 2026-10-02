#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POLKIT_SRC="$REPO_DIR/config/polkit/90-kmdot-server-mode.rules"
POLKIT_DST="/etc/polkit-1/rules.d/90-kmdot-server-mode.rules"

# Polkit rule letting wheel manage the server-mode services without a
# password prompt (bar start/stop). Idempotent: skip when already installed.
if [ -f "$POLKIT_DST" ] && cmp -s "$POLKIT_SRC" "$POLKIT_DST"; then
  echo "Polkit server-mode rule already installed, skipping."
elif sudo install -Dm644 "$POLKIT_SRC" "$POLKIT_DST"; then
  echo "Polkit server-mode rule installed."
else
  echo "Could not install polkit rule (sudo unavailable). Run manually:"
  echo "  sudo install -Dm644 $POLKIT_SRC $POLKIT_DST"
fi

# Essential system units.
if sudo systemctl enable NetworkManager bluetooth; then
  echo "NetworkManager + bluetooth enabled."
else
  echo "Could not enable system units (sudo unavailable). Run manually:"
  echo "  sudo systemctl enable NetworkManager bluetooth"
fi

# Fish as default shell, only when it isn't already.
CURRENT_SHELL="$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)"
FISH_PATH="$(command -v fish || true)"
if [ -n "$FISH_PATH" ] && [ "$CURRENT_SHELL" = "$FISH_PATH" ]; then
  echo "Fish is already the default shell, skipping."
elif [ -z "$FISH_PATH" ]; then
  echo "Fish is not installed, skipping chsh. Install fish, then run:"
  echo "  chsh -s <path-to-fish>"
elif chsh -s "$FISH_PATH"; then
  echo "Default shell changed to fish."
else
  echo "Could not change shell. Run manually:"
  echo "  chsh -s $FISH_PATH"
fi

# TPM (tmux plugin manager). Plugin install stays interactive (prefix + I).
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "TPM already present, skipping."
elif command -v git >/dev/null 2>&1 && git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"; then
  echo "TPM cloned. Install plugins with prefix + I inside tmux."
else
  echo "Could not clone TPM. Run manually:"
  echo "  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
fi

echo "kmDot system steps synced!!!"
