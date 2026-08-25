---
name: theme-sync-generator
description: Create the kmDot deployment side for one application's theming — config/<app>/ final configs, sync/<app>.sh on the copy+symlink pattern, the theme-switcher hook with reload/restart handling, registration in main.sh, and APPS/TARGETS/SOURCES entries in install.sh and uninstall.sh. Runs in build mode (writes) or plan mode (returns full planned files, writes nothing). Used by the add-themed-app orchestrator.
---

# Generate Sync, Hook, and Registration

Own everything deployment-side for one application. Inputs arrive in the dispatch prompt: app name, research findings (exact XDG paths, file format, reload semantics), and mode (`build` or `plan`). The theme files themselves belong to `theme-generator` — coordinate on the file name only.

Scripts are bash (`#!/usr/bin/env bash`, `set -e`); Node is the only exception. New scripts get `chmod +x` in the repo. Never write `~/.config` outside a sync script.

## Deliverables

1. `config/<app>/` — final configs
2. `sync/<app>.sh` — deployment script
3. `theme-switcher/hooks/<app>.sh` — theme application + reload
4. One line in `theme-switcher/main.sh`
5. Entries in `install.sh` and `uninstall.sh`
6. Verification

## 1. config/<app>/

Hold the app's final working config. Name the folder after the app's real XDG config dir when they match (ghostty → `ghostty`); where repo name and target diverge (legacy: `config/hyprland` deploys to `~/.config/hypr`), keep the divergence explicit and carry the true target through every registration below.

## 2. sync/<app>.sh

Template: copy `sync/tmux.sh` — resolve `REPO_DIR`, define the kmdot dir and target, `mkdir -p ~/.config/kmdot`, `rm -rf` both, `cp -r` repo → kmdot dir, `ln -sf`. Known deviations to reuse rather than reinvent:

- Single-file targets: `sync/starship.sh`.
- Copy without symlink (systemd units): `sync/battery.sh`.
- System-rooted targets needing sudo: `sync/sddm.sh` — these apps are **excluded from uninstall.sh**; note the exclusion in a comment there.
- Post-copy fixes (chmod inside deployed dir): `sync/quickshell.sh`.

Done when: the script mirrors one exemplar exactly, adjusted only where research demands it.

## 3. theme-switcher/hooks/<app>.sh

Template: `hooks/ghostty.sh` (pointer style) or `hooks/zed.sh` (raw-config / watcher-sensitive formats). Contract:

- Read from `$HOME/.config/kmdot/themes/$THEME/<file>`; exit 1 with an ERROR line when missing.
- Apply atomically — temp file + move, or `cat >` in-place when the app's watcher tracks the inode.
- Reload semantics from research:
  - hot-reload → nothing further;
  - restart needed → `pkill -x <bin> || true` then relaunch detached (`setsid nohup … </dev/null &`);
  - launch-only/GUI-only → apply config, state the limitation in the script's output.
- Echo a `✓ <App> theme updated` confirmation like the sibling hooks.

Register in `theme-switcher/main.sh`: one `. "$SCRIPT_DIR/hooks/<app>.sh" "$THEME"` line, alphabetical among the existing block.

## 4. Installer registration

| Script | Entry | Rule |
| --- | --- | --- |
| `install.sh` | `"app"` in `APPS` | Alphabetical insert |
| `uninstall.sh` | `"app"` in `APPS` | Alphabetical insert |
| `uninstall.sh` | `TARGETS["app"]="…"` | Copied verbatim from the `ln -sf` target(s) your sync script creates — dir or single file; space-separated list for multiple links |
| `uninstall.sh` | `SOURCES["app"]="…"` | Your script's `~/.config/kmdot/<dir>`; omit when none |

Invariants:

- `sync/<app>.sh` is the single source of truth for both maps — extract, never retype from memory.
- Every `uninstall.sh` APPS entry has a `TARGETS` key; every `install.sh` APPS entry has a `sync/<app>.sh`.
- Keep the pickers' height dynamic: `--height=$(( ${#APPS[@]} + 2 ))` — re-assert after inserting.
- System-rooted apps (sddm precedent): skip uninstall registration, leave an explanatory comment.

## 5. Verify (build mode)

```bash
bash -n sync/<app>.sh theme-switcher/hooks/<app>.sh install.sh uninstall.sh
./sync/<app>.sh                       # deploys cleanly
theme-switcher/main.sh <t1> && theme-switcher/main.sh <t2>   # hook round-trip
grep -c '"app"' install.sh uninstall.sh                       # registration present
```

Every `APPS` entry vs `sync/` parity check stays green. Report what was verified live versus left to the user.

## Plan mode

Return the complete planned tree plus full contents of every file (sync script, hook, main.sh diff, installer diffs) in fenced blocks — ready for the orchestrator to paste into `.plans/<app>.md`. Write nothing.

Done when: build mode passes all verification, or plan mode returns every artifact complete.
