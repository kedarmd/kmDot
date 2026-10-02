# Research: mise Node LTS bootstrap truth

Ticket: [#88](https://github.com/kedarmd/kmDot/issues/88) (child of map #86).
Question: correct fresh-box mise bootstrap (official installer, shell activation
for bash/fish) and Node LTS pin shape, with npm guaranteed present, plus how
`mise use/install` + shims put node/npm on PATH non-interactively, and what
removing the pacman `nodejs-lts-jod` fallback implies.

Grounding: mise docs (installing, getting-started, lang/node, shims, dev-tools,
CI pages) + `src/plugins/core/node.rs` on main + `nodejs.org/en/about/
previous-releases` (checked 2026-10-02). No secondary write-ups.

## TL;DR

- Installer (canonical): `curl -fsSL https://mise.run | sh` → binary at
  `~/.local/bin/mise`. (Arch `sudo pacman -S mise` exists but upstream prefers
  the `mise.run` single binary: faster, `mise self-update` works.)
- Activation lines: bash `eval "$(~/.local/bin/mise activate bash)"` in
  `~/.bashrc`; fish `~/.local/bin/mise activate fish | source` in
  `~/.config/fish/config.fish`. Repo `config/fish/config.fish` currently has
  **no** mise line — one must be added.
- `.mise.toml` recommendation: rename `nodejs` → `node`, keep `"24"`:
  `node = "24"`. Do NOT switch to `lts`.
- npm is bundled by default; mise post-install runs both `node -v` and `npm -v`.
  No bare-node-without-npm path via the core backend.
- In scripts (incl. `install.sh`): `mise install` + `mise exec -- <cmd>`. Do not
  rely on shell activation or shims there.
- Removing the pacman fallback makes mise the single Node provider: `install.sh`
  must bootstrap mise itself, and every node consumer (`toggle.sh`'s
  `node -e`, `*.mjs` with `#!/usr/bin/env node`, `HandyStore.qml`
  `exec(["node", …])`) depends on mise PATH wiring — including GUI-launched
  quickshell, which never sources a shell rc (see §6).

## 1. Official installer

Primary source: `mise.jdx.dev/installing-mise.html`, `getting-started.html`.

```sh
curl -fsSL https://mise.run | sh
~/.local/bin/mise --version   # mise not on PATH yet; activation fixes that
~/.local/bin/mise doctor
```

Notes (all from the installing page):

- Installer drops the binary in `~/.local/bin/mise` (override with
  `MISE_INSTALL_PATH="$HOME/bin/mise"`). `~/.local/bin` does not need to be on
  PATH — activation adds mise itself to PATH.
- Shell-specific one-shot installers also append activation:
  `curl -fsSL https://mise.run/bash | sh`,
  `curl -fsSL https://mise.run/fish | sh`.
- Arch alternative `sudo pacman -S mise` exists
  ([Arch package](https://archlinux.org/packages/extra/x86_64/mise/)), but the
  `mise.run` binary is the documented preference on Linux ("preferred method",
  "can be updated immediately with `mise self-update`"; package builds trail and
  the Homebrew formula is "substantially slower and larger").
- GPG verification of the installer exists (release key fingerprint
  `24853EC9F655CE80B48E6C3A8B81C9D17413A06D`) — optional for our script.

## 2. Shell activation: bash + fish

Primary source: `installing-mise.html` §Shells, `getting-started.html` §4.
Idempotent forms (guard against duplicate appends):

```sh
# bash
activation='eval "$(mise activate bash)"'
grep -qxF "$activation" ~/.bashrc 2>/dev/null || printf '%s\n' "$activation" >> ~/.bashrc
```

```sh
# fish
mkdir -p ~/.config/fish
activation='mise activate fish | source'
grep -qxF "$activation" ~/.config/fish/config.fish 2>/dev/null || printf '%s\n' "$activation" >> ~/.config/fish/config.fish
```

Fresh-box variant (mise not on PATH yet — our case): use the absolute path in
the activation line, exactly as the getting-started guide does:

```sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
```

Repo gap: `config/fish/config.fish` (27 lines) sources secrets, starship,
Android/Java paths — but contains **no mise activation line**. The fish hook
must be added there (and synced via `sync/fish.sh`) or `node`/`npm` will be
missing in every interactive fish shell on a mise-only box.

## 3. Node LTS pin shape: keep `"24"`, rename to `node`

Current repo state: `.mise.toml` contains `[tools]` / `nodejs = "24"`.

Recommendation:

```toml
[tools]
node = "24"
```

Why, per primary sources:

- **Name**: `nodejs` is not a real tool name. `lang/node.html` ("nodejs" →
  "node" Alias): "You cannot install/use a plugin named `nodejs`. If you try,
  mise renames it to `node`" (see also the FAQ). So `mise install nodejs@24`
  in `install.sh:61` only works by accident of the rename — write `node`.
- **Value `"24"` vs `lts`**: `src/plugins/core/node.rs` `get_aliases()` pins
  `lts → 24`, `lts/krypton`/`lts-krypton → 24`, `lts/jod`/`lts-jod → 22`.
  `nodejs.org/en/about/previous-releases` (2026-10-02): v24 "Krypton" = LTS,
  v22 "Jod" = LTS, v26 = Current. So today `lts` and `"24"` resolve identically
  — but `lts` is a **floating alias**: when v26 goes Active LTS (even majors cut
  over each October), `lts` silently jumps 24 → 26, while `"24"` keeps tracking
  the 24.x patch line (`mise upgrade node` moves patch, never major).
  Upstream's own examples declare `node = "24"` (`dev-tools/`, cookbook,
  getting-started lockfile example). For dotfiles reproducibility, keep `"24"`
  and bump the major deliberately. (`mise use --pin` / `mise.lock` exist for
  exact-pin needs; out of scope for this ticket.)
- Unrelated `nodejs` hits in-repo (`starship.toml` `[nodejs]` sections) are the
  starship **prompt module** name, not mise — leave them alone.

## 4. npm-bundled guarantee

Primary source: `lang/node.html` §Pinning npm version: "By default, Node.js
ships with a bundled version of npm." Corroboration in `node.rs`:
`install_version_` runs `test_node` (`node -v`) **and** `test_npm` (`npm -v`)
post-install, and `node.npm_shim` (default `true`) installs a bash wrapper at
`bin/npm` that triggers `mise reshim` after `npm install -g`. There is no
core-backend path that yields node-without-npm. Pin a separate npm only if the
team needs lockstep versions:

```toml
[tools]
node = "24"
npm = "11"
```

(`mise use --pin node@lts npm@latest` writes the resolved concrete versions.)

## 5. `mise use` / `mise install` + shims, non-interactively

Primary sources: `dev-tools/` (§Choose the right command, §`mise use`,
§`mise install`), `dev-tools/shims.html`, `continuous-integration.html`.

| Goal | Command |
|---|---|
| Add/change a project's tool version (installs + writes config) | `mise use node@24` |
| Install tools already declared in config (no config change) | `mise install` |
| One-off command with project tools, no activation | `mise exec -- node --version` |
| Run a named task with project tools/env | `mise run <task>` |

Rules for scripts (`install.sh`, CI — from the CI page: "Interactive shell
activation is not needed in CI"):

- `mise install` (from the repo root, reading `.mise.toml`) then
  `mise exec -- <cmd>`. `mise exec`/`mise run` auto-install missing tools by
  default (`exec_auto_install`, `task.run_auto_install` default true).
- Only requirement: `mise` itself on PATH — export
  `PATH="$HOME/.local/bin:$PATH"` or call `~/.local/bin/mise` absolutely.
- Shims (`~/.local/share/mise/shims`, via `export PATH=…shims:$PATH` or
  `mise activate --shims`) resolve per-directory versions for processes that
  never load a shell rc — but upstream recommends **PATH activation for
  interactive shells** and **`mise exec` for scripts**: shims don't provide env
  vars except through the shimmed tool and don't fire `cd`/`enter`/`leave`
  hooks. So: use `mise exec` in `install.sh`, not shims, not activation.
- Current `install.sh:55-68` bug shape: it runs `mise install nodejs@24`
  (positional-version form of `mise install` does work, but bypasses the config
  and uses the wrong `nodejs` name). Fresh-box correct form is
  `mise install` (declares from `.mise.toml`) or `mise use node@24` to record.

## 6. What removing the pacman `nodejs-lts-jod` fallback implies

1. **mise becomes the only Node provider.** `install.sh` must bootstrap mise
   itself (installer in §1) before any `mise install` — the current
   "mise found → use it, else pacman" branch collapses to "ensure mise, then
   `mise install`". No system node also means nothing masks a broken mise
   install; `command -v node` failing post-install is a hard error, not a
   fallback trigger.
2. **Every node consumer must resolve through mise.** Inventory:
   `config/quickshell/scripts/toggle.sh:11` (`node -e` socket connect),
   `calendar-events.mjs` / `handy-control.mjs` / `opencode-usage.mjs`
   (`#!/usr/bin/env node`), `HandyStore.qml` (`exec(["node", …])` ×6).
   Interactive shells are covered by §2 activation; scripts by §5 `mise exec`.
3. **GUI-launched processes don't source shell rcs.** Quickshell started via a
   Hyprland `exec-once` inherits the compositor's environment, not
   `config.fish`/`bashrc` — so activation lines alone do NOT put `node` on
   quickshell's PATH. The install/sync side must ensure `node` resolves there
   too (options, in upstream terms: shims dir on PATH exported through the
   Hyprland exec environment, or `mise exec`-wrapped entry points). This is the
   one wiring question the `install.sh` redesign must answer explicitly; the
   pacman package never had this problem because `/usr/bin/node` is global.
4. **Version drift goes away, deliberate upgrades replace it.** Today a box with
   both providers can run pacman-node 22 (jod) in `/usr/bin` while mise serves
   24 — after removal there is exactly one Node (mise 24.x), upgraded via
   `mise upgrade node`, major bumps via the `.mise.toml` edit.
