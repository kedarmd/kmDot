# Hex and kmDot integration feasibility

Researched 2026-11-01. Scope: whether Hex on Linux can replace kmDot's Handy Quickshell launcher and bar popup, and what a safe migration would require.

## Assessment

**A partial replacement is practical now; a feature-for-feature replacement is not supported by the interfaces documented for the installed Hex 3.0.0.** Hex can take over dictation, expose recording status, and open its own Settings/History window. kmDot can build a theme-aware control popup around those operations. The current installation does not expose the machine-readable Linux history/model interfaces needed to reproduce Handy's custom history and model picker reliably.

This assessment distinguishes the installed version from upstream's moving `dev` documentation. Local `hex --version` reports `3.0.0`; its command help includes `dictation`, `paste-last`, `status`, and model status/install/check/transcribe operations, but not a history query or a model-list/model-selection command. `hex settings` identifies itself as macOS-only. Newer upstream docs describe a richer cross-platform control CLI, but they are not proof that those commands exist in the installed 3.0.0 binary.

## What Hex provides on Linux

- Hex's Linux beta supports Hyprland and includes its own Settings and History views. It runs as one per-user process; closing its window does not stop the listener. Its own app can therefore remain the owner of history/model UI while kmDot supplies shortcuts and a bar entry. [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- The installed 3.0.0 CLI supports dictation start/stop/toggle/cancel, paste-last, status, and model lifecycle commands. `hex status` returns JSON including listener, model, and activity state, which is enough for a small status-aware bar/popup. It does not currently expose the existing Handy launcher's model catalog or transcript list through the installed CLI. (Verified with this workstation's `hex --help`, `hex model --help`, and `hex status`.)
- Current upstream `dev` docs describe broader commands including `window show history`, `model list/use/install`, `settings`, and history clearing. However, the transcript CLI documentation says read-only `hex history` queries currently target macOS; Linux and Windows retain their existing command surfaces. These moving docs should be rechecked against the exact installed version before relying on a command. [Hex CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md), [transcript CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/transcript-cli.md)
- Hex retains successful dictation text for a configurable period, seven days by default, but does not save dictation audio by default. Its own History view is available on Linux; there is no documented Linux transcript API that kmDot can consume in the installed version, and no audio file source for replay or retry. [Hex privacy and data notes](https://github.com/anomalyco/hex#privacy-and-local-data), [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- **Recording HUD replacement is feasible.** Hex's Linux guide says its native recording/processing pill is a focus-free, click-through layer-shell surface and its Recording indicator setting can place it at the top or bottom, or turn it off. The installed `hex status` JSON includes the `desktop.activity.state` and `settings.indicator_position` fields; a kmDot HUD can poll status while visible and render themed Listening/Recording/Transcribing/Failure states. Hex's CLI also supplies dictation control. This would be a status/control HUD, not a live transcript surface: the documented status payload is not a partial-transcript stream. [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md), [Hex CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md)
- Handy's current recording overlay is a separate native `Recording` window, not the kmDot Quickshell popup. kmDot's Hyprland rules float/pin it, prevent focus theft, and reposition it at bottom-center. Handy upstream documents an `Overlay Position: None` option that disables the Linux overlay. Thus the replacement path is to turn off Handy's native overlay, disable Hex's native indicator, and let one Quickshell HUD represent Hex's status. [Handy Linux limitations](https://github.com/cjpais/Handy#known-issues--current-limitations), [kmDot Hyprland rules](../../../config/hyprland/rules.lua)
- The Linux guide documents no public app-theme hook or theme-switcher integration. Quickshell can match the kmDot theme; Hex's own window will remain styled by Hex unless upstream exposes a supported appearance setting/API. [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)

## What kmDot currently gets from Handy

The existing Handy surfaces are much more than an app launcher. The [HandyStore singleton](../../../config/quickshell/HandyStore.qml) shares fetched models/history, model selection, one audio player, playback progress, and serialized mutations between the [launcher](../../../config/quickshell/menu/HandyLauncher.qml) and [popup](../../../config/quickshell/menu/HandyPopup.qml). The [Handy control script](../../../config/quickshell/scripts/handy-control.mjs) reads Handy's SQLite history/settings and recordings, then supports model selection, retry, deletion, and text editing. The current UI can play recordings, copy/edit transcripts, retry from audio, and delete the audio plus history row.

Handy's upstream README documents external start/stop/cancel CLI controls and notes a Raycast integration for browsing history, managing its dictionary, and switching models. It does not document a stable general-purpose Linux history API in the README. kmDot's current history/model bridge is consequently tied to Handy's local storage and CLI formats. [Handy README: CLI and integrations](https://github.com/cjpais/Handy#integrations)

## Feature comparison

| kmDot Handy feature | Hex Linux status | Feasibility |
|---|---|---|
| Start/stop dictation from a key | Supported by Hex CLI and documented Hyprland global action | Ready; current Super+I binding already targets Hex |
| Running/listener status | `hex status` JSON | Straightforward Quickshell integration |
| Recording HUD | Hex can place its native pill top/bottom/off; `hex status` exposes activity state | Straightforward to disable native pill and render a kmDot-themed status HUD; no documented partial transcript feed |
| Open a dictation app window | `hex app` opens/focuses Hex | Straightforward; use Hex's own UI |
| Built-in history browsing | Hex's Linux window has a History view | Available through Hex UI; exact deep-link command depends on installed version |
| Custom kmDot history list/search/copy | No documented Linux query API in installed Hex 3.0.0 | Blocked on a supported query API; do not parse undocumented private storage |
| Play recording / retry transcription | Audio is not retained by default | Not equivalent; requires Hex to expose retained audio and retry APIs |
| Delete one recording and row | No audio/history-item mutation API documented for installed Linux CLI | Not equivalent; current upstream clear-all is not a per-entry deletion API |
| Edit transcript | No supported transcript edit API documented for installed CLI | Not equivalent |
| List/download/select models in kmDot | Installed CLI covers default-model status/install/check, not model catalog/use | Use Hex's native model UI for now; revisit if installed version gains documented model-list/use controls |
| Tie Hex window colors to kmDot themes | No documented Linux theme interface found | Keep Hex's window independent; theme the kmDot popup only |

The limitation is at the integration contract, not at Quickshell: Quickshell can run commands and render a custom panel, but it should not own or mutate a private Hex data format.

## Recommended migration plan

1. **Keep the current trial binding and Hex autostart.** Verify the shortcut, paste behavior, model readiness, and daily reliability while Handy remains available as a rollback path.
2. **Add a thin Hex bar module/popup and optional HUD.** Read `hex status` with a low-frequency poll while visible; show enabled/recording/transcribing/error state; provide Start/Stop/Cancel, Paste last, and Open Hex actions using the installed CLI. Theme these kmDot surfaces with existing Quickshell roles. Turn off Hex's native Recording indicator before showing a custom HUD, so two indicators do not overlap. Avoid starting a second Hex process or duplicating microphone ownership.
3. **Replace Handy's launcher entry with an action launcher, not a cloned history UI.** Offer Open Hex and the supported dictation actions. If the installed CLI supports a stable way to open the History pane, add that only after verifying it locally; otherwise open Hex and let the user select History.
4. **Do not remove Handy's history/popup implementation yet.** First decide whether Hex's native History is sufficient. For parity, request or wait for documented Linux APIs for list/search/read/delete/edit, plus an explicit audio-retention/retry contract. A stable API could then back a new Quickshell store and UI.
5. **Retire Handy only after parity decisions.** Remove its keybind, launcher/menu entries, server-mode handling, package/install entry, and scripts as separate reviewed work. Keep Handy's local recordings untouched unless the user separately asks to delete them.

## Decision

**Yes, Hex can replace Handy as the dictation engine and be integrated into kmDot's bar/launcher. No, the installed Hex 3.0.0 does not currently provide the supported Linux data/control surface to reproduce kmDot's Handy history panel and model picker feature-for-feature.** The sensible near-term design is a kmDot-themed Hex status/control popup that delegates model management and history to Hex's own window. A full custom replacement becomes viable if Hex's Linux CLI/API grows stable history and model operations; until then, scraping its private files would be brittle and unsafe.

## Primary sources

- [Hex Linux installation and behavior guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- [Hex control CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md)
- [Hex transcript CLI and platform notes](https://github.com/anomalyco/hex/blob/dev/docs/transcript-cli.md)
- [Hex project README](https://github.com/anomalyco/hex)
- [Handy project README](https://github.com/cjpais/Handy)
