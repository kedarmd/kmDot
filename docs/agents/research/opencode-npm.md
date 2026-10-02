# Research: opencode npm install truth (for install.sh design)

Ticket: kedarmd/kmDot#87 (child of map #86).
Question: official no-AUR way to install opencode via npm — exact package name,
global install command, resulting binary path + version-pinning story — and how it
behaves under mise-managed Node (npm bundled? shims/PATH wiring for bash + fish?).

All claims below are grounded in primary sources (cited per claim) plus one local
verification (npm tarball inspection). mise itself is NOT installed on this machine,
so mise PATH/prefix facts are derived from mise's own docs, marked as such.

## 1. Official npm package: `opencode-ai`, binary `opencode`

- OpenCode's own docs (`https://opencode.ai/docs`, Install section) list under
  "Using Node.js": `npm install -g opencode-ai` (also `bun/pnpm/yarn` equivalents),
  and under Windows "Using NPM": the same command. The curl script
  (`curl -fsSL https://opencode.ai/install | bash`) is presented as the easiest path;
  npm is the documented Node-based alternative. `npm install -g opencode` (no `-ai`
  suffix) is NOT the documented package.
- Registry metadata (`https://registry.npmjs.org/opencode-ai/latest`, checked
  2026-10-02: version **1.18.34**) confirms: `name: opencode-ai`,
  `bin: { "opencode": "bin/opencode.exe" }`, `os: [darwin, linux, win32]`,
  `cpu: [arm64, x64]`, 12 `optionalDependencies` of the form
  `opencode-<platform>-<arch>[@-musl/-baseline]@<same version>`.
- So after a correct global install, the command on PATH is **`opencode`**
  (bin name), from package **`opencode-ai`**.

## 2. Exact commands + version-pinning story (npm semantics)

- Install latest: `npm install -g opencode-ai`
  (npm docs: bare `<name>` installs the version tagged `latest`;
  `https://docs.npmjs.com/cli/v11/commands/npm-install/`).
- Pin exact: `npm install -g opencode-ai@<version>` (e.g. `opencode-ai@1.18.34`).
  Other supported specs per the same page: `<name>@<tag>` (e.g. `@latest`),
  `<name>@<version range>` (quoted, e.g. `"opencode-ai@>=1.18 <1.19"`).
- Live-update to latest tag: `npm update -g opencode-ai`
  (`https://docs.npmjs.com/cli/v11/commands/npm-update/`; `-g` updates global packages).
- Check installed: `npm ls -g opencode-ai`; available: `npm view opencode-ai version`
  (dist-tags include `latest`, plus `next`/`beta`/`dev` snapshot tags — pinning to
  `latest` explicitly avoids snapshot tags).
- Node requirement: the registry metadata carries **no `engines` field** (verified
  locally), and the opencode docs page states no minimum Node version in the Install
  section. npm's own rule still applies: a bare-name install prefers the newest
  version compatible with the running Node via `engines`, but since opencode-ai
  declares none, `latest` resolves unconditionally. (npm-install docs, "Install
  `<name>`" note on engines-aware resolution.)

## 3. Resulting binary path (npm folder layout)

- Per `https://docs.npmjs.com/cli/v11/configuring-npm/folders/`: in global mode
  (`-g`), packages go to `{prefix}/lib/node_modules` (Unix) and executables are
  linked into **`{prefix}/bin`** — that directory must be on `PATH`.
- `prefix` defaults to "the location where node is installed" (same page):
  `/usr/local` for distro Node (`/usr/bin/node` → `/usr/local/bin/opencode`),
  or wherever a version manager's Node lives (see §5). Confirm locally with
  `npm prefix -g` (here: `/home/kedarmd/.local`, since npm resolves prefix from
  the active Node — this machine's `npm` is at `~/.local/bin/npm`).
- Update/uninstall: `npm update -g opencode-ai` / `npm uninstall -g opencode-ai`.

## 4. Load-bearing caveat: the postinstall script MUST run

Verified by inspecting the published tarball locally
(`npm pack opencode-ai`, version 1.18.34):

- `bin/opencode.exe` **as shipped is a stub** that prints an error and exits 1:
  "opencode-ai's postinstall script was not run… when using `--ignore-scripts`…
  or a package manager like pnpm that does not run postinstall scripts by default."
- `postinstall.mjs` detects platform/arch (incl. musl via `ldd`/alpine-release,
  AVX2-baseline fallback on x64 linux/darwin), resolves the matching
  `opencode-<platform>-<arch>` optionalDependency, and copies its real binary over
  `bin/opencode.exe`. If the optional dep isn't present it `npm install`s it into a
  temp prefix.
- Consequences for install.sh design:
  1. **Never install with `--ignore-scripts`** (and never via a backend that
     ignores scripts by default — see §6 on mise's npm backend).
  2. Broken-install recovery is documented in the stub itself:
     `cd $(npm root -g)/opencode-ai && node postinstall.mjs`.
  3. A smoke test after install must be `opencode --version` (exit 0), not just
     "file exists on PATH" — a script-skipped install leaves a plausible-looking
     but dead `opencode` shim.

## 5. mise-managed Node + `npm install -g opencode-ai`

Sources: `https://mise.jdx.dev/lang/node.html`, `https://mise.jdx.dev/dev-tools/shims.html`,
`https://mise.jdx.dev/dev-tools/backends/npm.html`. (mise is not installed on this
machine; paths below are per these docs, not locally executed.)

- **npm is bundled with mise's Node.** "By default, Node.js ships with a bundled
  version of npm" (node.html, "Pinning npm version"). Optionally pin a separate npm:
  `[tools] node = "26", npm = "11"` (separate npm then takes precedence;
  check with `mise exec -- npm --version`).
- **Where the global bin lands.** npm's `prefix` = location where node is installed
  (§3), so under mise-managed Node the global prefix is inside the tool install dir
  (`~/.local/share/mise/installs/node/<version>/`, i.e. `$MISE_INSTALLS/...`), and
  the `opencode` link lands in that install's `bin/`. `mise activate` (PATH mode)
  prepends the active tool `bin` dirs to `PATH`, so `opencode` is on PATH in any
  activated shell. Additionally mise's node backend installs "a bash wrapper at
  `bin/npm` that triggers `mise reshim` after `npm install -g`"
  (`node.npm_shim` setting, default `true`), so the new `opencode` shim appears in
  `~/.local/share/mise/shims/` automatically — no manual `mise reshim` needed
  (reshim "should get called automatically if you're using npm").
- **Shell wiring (bash + fish).** PATH activation (recommended for interactive shells):
  bash → `eval "$(mise activate bash)"` in `~/.bashrc`; fish → `mise activate fish | source`
  in `~/.config/fish/config.fish`. Shims alternative (stable paths, IDEs,
  non-interactive contexts): bash → `eval "$(mise activate bash --shims)"`;
  fish →
  `if status is-interactive; mise activate fish | source; else; mise activate fish --shims | source; end`.
  Shim dir default: `~/.local/share/mise/shims` (or plain
  `export PATH="$HOME/.local/share/mise/shims:$PATH"` if mise isn't on PATH yet).
- **Non-interactive scripts (install.sh!).** `mise activate` updates PATH at prompt
  time, so it "doesn't work well for non-interactive situations like scripts";
  prefer `mise exec -- <command>` / `mise x -- <command>` (loads tools + env
  explicitly; requires only `mise` on PATH). Bash login shells read profile files,
  not `~/.bashrc`, so an install.sh run non-interactively cannot assume an
  activated environment — resolve `node`/`npm` via `mise exec` (or `mise which npm`)
  and export the resulting `{prefix}/bin` explicitly if later steps need `opencode`.
- **Separate concern — mise's own opencode backends.** The opencode docs list
  `mise use -g github:sst/opencode` (GitHub backend: builds/fetches from source
  releases). Independently, mise's **npm backend** installs npm CLIs into separate
  tool dirs (`mise use -g npm:opencode-ai`, a.k.a. `"npm:opencode-ai"` in mise.toml;
  needs `node` declared alongside for runtime). WARNING for either mise-backend
  route: the embedded `aube` installer **denies dependency lifecycle scripts unless
  allowlisted** (`allow_builds`; npm-backend docs), and mise passes
  `--ignore-scripts=true` for npm-installer mode — per §4 that would leave the
  dead stub binary. If install.sh ever uses `npm:`-backend instead of plain
  `npm install -g`, it must set an explicit installer that runs the postinstall
  (or run `node postinstall.mjs` manually afterwards) and smoke-test with
  `opencode --version`.

## 6. Recommendation for install.sh (downstream)

1. Ensure a real Node on PATH first (mise `node` or system node), then run
   `npm install -g opencode-ai[@<pin>]` with scripts enabled (default) — NOT via
   `mise npm:`-backend without script handling.
2. Assert success with `opencode --version` (exit 0); on failure, retry via
   `node $(npm root -g)/opencode-ai/postinstall.mjs` before reporting broken.
3. For PATH: in activated shells mise handles it; in scripts, derive
   `$(npm prefix -g)/bin` after the install (via `mise exec` if mise-managed) and
   export it — never hardcode `/usr/local/bin`.
4. Do NOT confuse with `opencode` (wrong package) or `mise use -g github:sst/opencode`
   (different backend, source builds) — pick one route and pin it.

## Sources

- `https://opencode.ai/docs` (Install section: npm/bun/pnpm/yarn commands, Arch
  pacman/AUR, mise-github, brew/choco/scoop/docker tabs)
- `https://registry.npmjs.org/opencode-ai/latest` (name/bin/os/cpu/optionalDeps;
  1.18.34 on 2026-10-02) + local `npm pack` inspection of `bin/opencode.exe`
  (stub) and `postinstall.mjs` (platform resolution + copy logic)
- `https://docs.npmjs.com/cli/v11/commands/npm-install/` (bare-name→latest,
  `@<version|tag|range>` specs, `global` → `{prefix}/bin` + man pages)
- `https://docs.npmjs.com/cli/v11/configuring-npm/folders/` (prefix defaults,
  global layout `{prefix}/lib/node_modules` + `{prefix}/bin`)
- `https://mise.jdx.dev/lang/node.html` (bundled npm, `npm = "11"` pinning,
  `node.npm_shim` reshim wrapper, `~/.default-npm-packages` deprecated)
- `https://mise.jdx.dev/dev-tools/shims.html` (shim dir, `activate` vs
  `activate --shims`, bash/fish wiring, `mise exec` for scripts)
- `https://mise.jdx.dev/dev-tools/backends/npm.html` (`npm:<pkg>` tool syntax,
  embedded-aube lifecycle-script denial, `--ignore-scripts` under npm installer)
