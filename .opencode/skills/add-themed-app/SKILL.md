---
name: add-themed-app
description: Integrate a new application into kmDot's theming system end-to-end — research how to install it and how it themes, then generate themes/<theme>/<app> files for all five themes plus config/, sync/<app>.sh, its theme-switcher hook, and installer-script registration. Falls back to a pending plan in .plans/ when the app is not yet installed. Use when the user asks to add a new app to kmDot theming, integrate an application with the theme switcher, or theme an app that has no kmDot integration yet.
---

# Add a Themed App

Take one application from "unintegrated" to a full kmDot citizen: theme files for all five themes (`catppuccin`, `everforest`, `nord`, `onedark`, `tokyonight`), deployed config, a theme-switcher hook, and installer registration. The repository is the source of truth — never edit `~/.config` directly.

Sub-agents start with empty context. Every dispatch must pass: the app name, the relevant research findings pasted into the prompt, the mode (`build` or `plan`), and the instruction to read the specific skill file by path.

## 1. Identify the application

Resolve the request to exactly one application and its binary/package name. If the request is ambiguous between candidates, ask before spawning anything.

Done when: you have a single app name and its likely binary name.

## 2. Check for a pending plan, then check installation

Resume first: if `.plans/<app>.md` exists, present it and ask whether to execute it (jump to step 4, then delete the file per its own checklist) or discard it and re-research fresh.

Then detect installation on this machine:

```bash
command -v <binary>
pacman -Qi <package>
flatpak list 2>/dev/null | grep -i <name>   # flatpak fallback
```

A hit on any counts as installed. Record the result.

Done when: resume question settled and installed/not-installed is decided.

## 3. Research

Dispatch research sub-agent(s) that follow `.opencode/skills/theme-app-research/SKILL.md`:

- **App missing** → one session covering BOTH goals: `install-methods` AND `theming-internals`.
- **App installed** → one session, goal `theming-internals` only.

Prompt skeleton:

> Read /home/kedarmd/dev/kmDot/.opencode/skills/theme-app-research/SKILL.md and follow it. Goal(s): <install-methods | theming-internals | both>. Application: <name>, binary: <bin>. Return your findings in the structured format that skill defines. Do not modify any files.

When findings come back, summarize them for the user. If `theming-internals` research concludes the app has no viable theming mechanism, stop and say so — inventing one is out of scope.

Done when: findings for every applicable goal are in hand and reported.

## 4a. App installed — build

Dispatch TWO sub-agents in parallel (one message, disjoint file sets):

1. **theme-generator**, mode `build`:

   > Read /home/kedarmd/dev/kmDot/.opencode/skills/theme-generator/SKILL.md and follow it in build mode. Application: <name>. Research findings: <paste theming-internals findings>.

2. **theme-sync-generator**, mode `build`:

   > Read /home/kedarmd/dev/kmDot/.opencode/skills/theme-sync-generator/SKILL.md and follow it in build mode. Application: <name>. Research findings: <paste theming-internals findings, including the exact XDG config paths and reload semantics>.

Then run step 5 verification, delete `.plans/<app>.md` if one existed, and report.

Done when: both agents report success AND step 5 passes.

## 4b. App not installed — inform + plan-mode fallback

Tell the user the app is not installed and give the exact install commands from the `install-methods` findings. Then capture the work so post-install execution needs no re-research:

1. Dispatch **theme-generator** and **theme-sync-generator** in parallel, mode `plan`. Same prompts as 4a plus: "Plan mode: produce the full planned output defined by your skill and modify nothing."
2. Merge everything into ONE file `.plans/<app>.md`:

   ```markdown
   # Pending theme integration: <app>
   ## Status
   Not installed at plan time (<date>).
   ## Install
   <commands, package sources, post-install notes>
   ## Research findings
   <theming-internals findings>
   ## Theme files (all five themes)
   <complete contents per file, ready to write>
   ## Config / sync / hook / registration plan
   <sync-generator's planned tree and full script bodies>
   ```

3. Ensure `.plans/` is gitignored. Stop — this branch writes nothing outside `.plans/`.

Done when: the user has install instructions AND `.plans/<app>.md` exists with all four sections complete.

## 5. Verify (build branch)

Run, in order:

```bash
bash -n sync/<app>.sh theme-switcher/hooks/<app>.sh
./sync/<app>.sh
theme-switcher/main.sh <other-theme> && theme-switcher/main.sh <original-theme>
```

The round-trip must leave the app themed as the original theme with no hook errors. Check parity greps from the sync-generator skill. Report precisely what was verified live versus left to the user (e.g., GUI appearance).

## Completion checklist

- [ ] `themes/{catppuccin,everforest,nord,onedark,tokyonight}/<app>.<ext>` all exist.
- [ ] Hook exists, reads from `~/.config/kmdot/themes/$THEME/`, registered in `theme-switcher/main.sh`.
- [ ] `sync/<app>.sh` executable, follows the copy+symlink pattern.
- [ ] `config/<app>/` holds the final configs.
- [ ] `config-install.sh` and `config-uninstall.sh` registered per the sync-generator contract.
- [ ] Theme round-trip verified, or the unverified part stated plainly.
- [ ] Pending plan deleted (if one existed).
- [ ] `AGENTS.md` updated only if a lasting convention or quirk emerged.
