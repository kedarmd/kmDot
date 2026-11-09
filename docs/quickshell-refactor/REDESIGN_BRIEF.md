# Quickshell Clean-Room Redesign Brief

## Purpose and status

This branch prepares a clean implementation surface for the Quickshell redesign. Phase 1 is approved; the complete functional contract is in [FEATURE_REQUIREMENTS.md](FEATURE_REQUIREMENTS.md). Phase 2 cleanup is prepared for review. Design work, upstream theme research, and production QML remain locked until the corresponding approval gates.

## Approved functional scope

The redesign must carry forward the approved inventory: per-monitor desktop bar and workspaces; application and kmDot launchers; system actions; theme and wallpaper selection; clipboard history; Wi-Fi and Bluetooth controls; audio input/output and media; battery and power profiles; displays and brightness; calendar; notifications, DND, replies, and OSDs; native session lock; server and attention modes; Handy transcription; OpenCode/agent usage; and the keybind reference. Preserve feature behavior, system integrations, error handling, IPC/shortcut contracts, and edge cases recorded in the inventory. Do not retire or merge an inventory feature without explicit approval.

The inventory identifies one mismatch for review: the supplied instructions describe a separate brightness popup that is absent from the current repository. Phase 1 records this as unresolved. The separate radio launchers and dropdown/add flows are all currently live and remain in scope pending a decision about how their capabilities should be composed.

## Constraints

- Repository sources remain authoritative. The implementation targets CachyOS/Arch Linux, Hyprland, Wayland, and Quickshell.
- Four supported themes are Tokyo Night, Catppuccin, Everforest, and Nord. Theme research must use authoritative upstream sources and must not use the removed kmDot Quickshell palettes or screenshots as design references.
- All visual design must be created in FigCraft through its MCP integration before production QML begins. Verify the actual MCP capabilities; do not claim unsupported operations.
- Theme-dependent colors belong in external theme definitions and are consumed as semantic roles. QML must not hardcode theme colors.
- Theme switching remains a shared application feature. Quickshell integration may be restored only after the new implementation has an approved theme contract.
- Design system, components, all surfaces, all four theme variants, and required interaction states need explicit approval. Approval of one feature or one theme does not approve the rest.
- No production QML is permitted before the complete design system and all feature/theme designs receive approval.
- Preserve unrelated dotfiles and shared integrations. Quickshell-specific backend scripts may be relocated when another active caller depends on them.

## Design freedom

The visual system is open for independent invention: information architecture, layout, component composition, typography, spacing, icon language, motion, and theme-specific treatment may be redesigned freely. Functional parity, accessibility, keyboard operation, multi-monitor behavior, and the approved integration contracts constrain behavior, not the visual result.

## Workflow and gates

1. **Gate 1 — Functional inventory:** approved. `FEATURE_REQUIREMENTS.md` is the source contract; unresolved scope questions remain visible there.
2. **Gate 2 — Cleanup:** the new branch and cleanup are presented for review. Do not start theme research or FigCraft work until explicit approval.
3. **Phase 3 — Theme research:** document upstream palettes, variants, role meanings, contrast, and rationale in `THEME_RESEARCH.md`, without using former kmDot Quickshell values.
4. **Phase 4 — FigCraft design:** verify MCP, establish the design workspace and system, then design the top bar first and proceed feature by feature. Present all four theme variants and states for each feature; wait for approval before starting the next.
5. **Gate 3 — Design freeze:** maintain `DESIGN_STATUS.md`; production implementation stays blocked until every required feature, theme, and state is approved.
6. **Phase 6 — Implementation:** only after Gate 3, implement the approved designs, restore integration points, and validate against the feature inventory.

## Cleanup notes for review

The legacy Quickshell source tree, deployment script, launcher scripts, theme renderer/schema/hook, Quickshell-only theme files, and legacy Quickshell screenshots have been removed from this branch. Git history retains the source implementation at the branch point. `attention-mode.sh` and `server-mode.sh` were moved under `config/hyprland/scripts/` because Hyprland idle handling and the server-mode backend still consume them. SDDM previously read the Quickshell palette files; the same SDDM-specific roles are now maintained as `themes/<theme>/sddm.conf`, preserving that separate login-screen integration.

Old UI entry points and QML-specific IPC calls have been detached while their surfaces are absent. Basic volume/mute and brightness media-key behavior and session locking remain routed directly to system tools. The legacy theme-switch lock guard was tied to Quickshell IPC; restore equivalent lock awareness in the new integration. The redesigned UI must restore approved shortcuts and IPC integrations from the feature inventory before the refactor is considered complete.
