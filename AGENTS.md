# AGENTS.md

This file is designed to support coding agents (like Copilot or Cursor) while working within this repository. It provides comprehensive guidelines on build/lint/test commands, code style guidelines, and conventions to follow. By adhering to these rules, agents can maintain consistency, reliability, and quality in their contributions.

---

## 1. Build, Lint, and Test Commands

### 1.1 General Guidelines
- For automated tasks, ensure all commands are run from the root directory of the repository.
- Use Neovim-specific tools (when applicable) and plugins as defined in the `lazy-lock.json` file.

### 1.2 Build Commands
N/A - This repository appears to contain configuration files rather than a project requiring builds. If build steps are applicable to specific modules, adjust these instructions accordingly.

### 1.3 Lint Commands
Neovim plugins like `nvim-lint` and `conform.nvim` are used for linting. Ensure that your code adheres to linting rules configured via these plugins. The following commands can be used for linting:

- **To lint all Lua files:**
  ```bash
  :lua require("lint").try_lint()
  ```
- **Ensure `conform.nvim` auto-formats code on save if configured.**

### 1.4 Test Commands
This repository does not include specific test runners. If applicable for plugins or scripts:
- Use `plenary.nvim` for Lua unit tests.
- Create your tests in directories as per Neovim plugin conventions.

Run tests with:
```bash
:PlenaryBustedFile
```

### 1.5 Running a Specific Test
Use the filename or pattern to execute individual tests:
```bash
:PlenaryBusted %filename%
```

(Note: Adjust these instructions to suit specific additional test frameworks.)

---

## 1.6 Dotfiles Workflow

### 1.6.1 Sync Model (Required)
- Source of truth is this repo: `config/`, `theme-switcher/`, `themes/`, `sync/`.
- Do not write directly to `~/.config/*` or `~/.tmux.conf`.
- Always use `sync/*.sh` to copy into `~/.config/kmdot` and create symlinks.

### 1.6.2 Installer
- `install.sh` runs the per-app sync scripts.
- Add new apps to `install.sh` and create a matching `sync/<app>.sh`.

### 1.6.3 Theme System
- Themes live in `themes/<theme>/`.
- Theme switching is done by `theme-switcher/main.sh <theme>`.
- Hooks update app configs and reload where relevant.

---

## 2. Code Style Guidelines

### 2.1 Imports
- Follow the import conventions specified by `lua require` paths.
- Organize imports alphabetically where applicable to improve readability.
- Use lazy loading for plugins wherever possible (`lazy.nvim` plugin features).

### 2.2 Formatting
- Consistently use code formatters (e.g., `conform.nvim`) for Lua code.
- Align with LSP configurations (`mason.nvim` and dependencies) to ensure uniform formatting.
- Use spaces instead of tabs for alignment where configuration allows.

### 2.3 Types
- Specify type annotations explicitly in Lua where beneficial (function parameters, return values). Example:
```lua
---@param opts table
---@return boolean
local function example_function(opts)
    -- Implementation
end
```

### 2.4 Naming Conventions
- **Files:** Use snake_case for filenames (e.g., `my_plugin.lua`).
- **Functions and Variables:** Use camelCase or snake_case consistently within the same file.
- **Constants:** Use SCREAMING_SNAKE_CASE (e.g., `MAX_RETRIES`).
- **Global variables:** Avoid declaring unless necessary for `vim` APIs.

### 2.5 Error Handling
- Use robust error handling for critical functions.
- Example using `pcall` in Lua:
```lua
local success, result = pcall(require, "module_name")
if not success then
    vim.notify("Module failed to load!")
end
```

### 2.6 Comments
- Write concise, meaningful comments.
- Use the LuaDoc format for functions and modules:
```lua
--- This function does X
---@param inputType string Description
---@return outputType Description
```

---

## 3. Repository Conventions

### 3.1 Neovim Configuration
- Plugins are managed via `lazy.nvim`, as defined in `lazy-lock.json`.
- Ensure proper configuration loading via lazy loading or `config` blocks.

### 3.2 Plugin-Specific Notes
- Use `mason.nvim` and its integrators (`mason-lspconfig.nvim`, etc.) for LSP management.
- `nvim-treesitter` is used for syntax highlighting. Ensure grammars for relevant languages are up-to-date.

### 3.3 Debugging Utilities
- Use `plenary.nvim` for utility functions or debugging.
- Print debugging information succinctly:
```lua
print(vim.inspect(variable))
```

---

## 4. App-Specific Notes

### 4.1 Tmux
- Modular config under `config/tmux/conf.d/`.
- Runtime theme colors are written to `~/.config/kmdot/tmux/colors.conf`.
- Layout is in `config/tmux/theme.conf`.
- Prefix is `C-s`; window indices renumber automatically.
- TPM is used for plugins; install separately.

### 4.2 Theme Switcher
- Hooks live in `theme-switcher/hooks/`.
- `theme-switcher/hooks/starship.sh` enforces `right_format = ""` and disables battery.
- `theme-switcher/hooks/waybar.sh` restarts waybar with output silenced.

### 4.3 Hyprland Wallpapers
- Wallpaper cycling: `config/hyprland/scripts/cycle_wallpapers.sh`.
- Script exits early if hyprpaper is not running.

### 4.4 Locale and Nerd Fonts
- Tmux requires UTF-8 locale for Nerd Font glyphs.
- Recommended: `LANG=en_IN.UTF-8` and `LC_ALL=en_IN.UTF-8`.

---

This file may be updated as the repository evolves. Always ensure local overrides or project-specific updates are communicated across contributors/agencies.
