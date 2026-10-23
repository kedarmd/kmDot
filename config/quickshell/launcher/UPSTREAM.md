# Launcher provenance and integration boundary

Imported from [kedarmd/oma-cast](https://github.com/kedarmd/oma-cast), commit
`5f305925535db9c963f210aeb24ca9ada09270c8` (the local CachyOS/kmDot port,
2026-10-24). Original project: [typecraft-dev/oma-cast](https://github.com/typecraft-dev/oma-cast).
The local reference checkout remains `/home/kedarmd/dev/oma-cast`; deployed code
does not read or execute anything from that checkout.

`plugin/` retains the source layout so later feature imports can be compared
against that revision. `bin/` contains only the two Bash runtime helpers, not
the standalone installer, CLI, service or Python installation tools. The
upstream JavaScript regression tests are in `tests/quickshell-launcher/` at the
kmDot root; the standalone installer tests were excluded.

Local adaptations:

- Rename runtime identity, XDG directories and `KAY_CAST_*` environment knobs
  to `kmdot-launcher` / `KMDOT_LAUNCHER_*`; display the name **kmDot**.
- Embed `plugin/Launcher.qml` through `menu/KmdotLauncher.qml` in the main shell,
  with `scope`, `openLauncher`, `closeLauncher` and the shared overlay coordinator.
- Replace its independent global shortcut with two socket entry points on one
  instance: `kmdot-kmdot` opens All; `kmdot-launcher` opens Applications.
- Explicit entry modes reset to root and clear stale queries. Repeating the
  current mode closes it; requesting another mode changes the existing card.
- Handle the Applications command in place, without starting another process
  or rendering another launcher. Other kmDot menus retain their own UIs.
- Keep independent `systemd-run` app lifetimes and literal argv/cwd handling.
- Keep the reference card, typography, spacing, icons, filters and action panel.
  Continue reading the generated kmDot palette as data; no palette changes.
- Disable source hot reload for the main shell because the source port documents
  a Qt/Wayland surface teardown crash. Data FileViews remain reactive.

`core/OmarchyMenu.js` and `services/OmarchyMenuSource.qml` remain upstream
reference material. The running backend uses `services/DesktopSource.qml`.

For future imports, fetch/pull in the separate oma-cast checkout, compare against
the revision above, and selectively port features into this tree. Preserve the
kmDot lifecycle, paths, shortcut ownership and desktop adapter. Do not run the
standalone installer or enable its service as part of a kmDot update.
