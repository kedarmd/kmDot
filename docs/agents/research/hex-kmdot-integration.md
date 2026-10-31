# Hex and kmDot integration feasibility

Researched 2026-11-01. Scope: whether Hex on Linux can replace kmDot's Handy Quickshell launcher and bar popup, and what a safe migration would require.

## Assessment

**A Handy-styled Hex surface is practical, with current-version limits on model management and history mutations.** Hex can take over dictation and expose recording state. The installed Linux 3.0.0 CLI does not list models, switch models, or query history, but its retained-history file matches Hex's documented version-1 schema and can be read without modifying it. The installed CLI has no supported per-entry delete/edit API or retry-audio path.

This assessment distinguishes the installed version from upstream's moving `dev` documentation. Local `hex --version` reports `3.0.0`; its command help includes `dictation`, `paste-last`, `status`, and model status/install/check/transcribe operations, but not a history query or a model-list/model-selection command. Direct checks confirm `hex history` and `hex model list` are unrecognized. The current Hex docs describe `model list/use` and `window show`, but those commands are not proof that they exist in this installed binary. The local retained-history document is version 1 and matches the documented `History` entry fields; the kmDot bridge reads it as data only.

## What Hex provides on Linux

- Hex's Linux beta supports Hyprland and includes its own Settings and History views. It runs as one per-user process; closing its window does not stop the listener. Its own app can therefore remain the owner of history/model UI while kmDot supplies shortcuts and a bar entry. [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- The installed 3.0.0 CLI supports dictation start/stop/toggle/cancel, paste-last, status, and model lifecycle commands. `hex status` returns JSON including listener, model, and activity state, which is enough for a small status-aware bar/popup. It does not currently expose the existing Handy launcher's model catalog or transcript list through the installed CLI. (Verified with this workstation's `hex --help`, `hex model --help`, and `hex status`.)
- Current upstream `dev` CLI docs describe `model list/use/install`, `window show models|history`, and `hex history`; its transcript docs publish a versioned v1 JSON schema. The Linux guide says those control commands are available on Linux, while the transcript page still describes history queries as macOS-only. The installed 3.0.0 CLI lacks the newer subcommands, so kmDot feature-detects model CLI support and reads only the documented v1 retained-history fields on this machine. Recheck the exact binary before relying on newer commands. [Hex CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md), [transcript CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/transcript-cli.md), [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- Hex retains successful dictation text for a configurable period, seven days by default, but does not save dictation audio by default. Its own History view is available on Linux. The current kmDot adapter reads retained text for browsing/copy; there is no audio file source for replay or retry, and the installed CLI exposes no per-entry edit/delete operation. [Hex privacy and data notes](https://github.com/anomalyco/hex#privacy-and-local-data), [Hex Linux guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
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
| Custom kmDot history list/search/copy | Read-only v1 retained-history schema; `hex history` CLI absent in installed build | Available with a defensive read-only adapter; copy supported |
| Play recording / retry transcription | Audio is not retained by default | Not equivalent; requires Hex to expose retained audio and retry APIs |
| Delete one recording and row | No audio/history-item mutation API documented for installed Linux CLI | Not equivalent; current upstream clear-all is not a per-entry deletion API |
| Edit transcript | No supported transcript edit API documented for installed CLI | Not equivalent |
| List/download/select models in kmDot | Installed CLI has `model status`, not `model list/use` | Show the selected installed model; delegate model changes to Hex's window until the installed CLI adds those commands |
| Tie Hex window colors to kmDot themes | No documented Linux theme interface found | Keep Hex's window independent; theme the kmDot popup only |

The limitation is at the integration contract, not at Quickshell: Quickshell can run commands and render a custom panel, but it should not own or mutate a private Hex data format.

## Recommended migration plan

1. **Keep the current trial binding and Hex autostart.** Verify the shortcut, paste behavior, model readiness, and daily reliability while Handy remains available as a rollback path.
2. **Use Handy's two-tab layout for Hex.** Populate History from the documented versioned retained-history fields and support copy. Feature-detect model CLI support; until it is installed, show the selected model and delegate model changes to Hex's window. Leave playback, retry, per-entry edit, and delete out unless Hex adds supported audio/history-item operations.
3. **Keep the custom HUD theme-aware and voice-reactive.** Read status from Hex and sample the PipeWire input level only during recording. Turn off Hex's native Recording indicator before relying on the custom HUD so two indicators do not overlap.
4. **Do not remove Handy's history/popup implementation yet.** First decide whether Hex's native History is sufficient. For parity, request or wait for documented Linux APIs for list/search/read/delete/edit, plus an explicit audio-retention/retry contract. A stable API could then back a new Quickshell store and UI.
5. **Retire Handy only after parity decisions.** Remove its keybind, launcher/menu entries, server-mode handling, package/install entry, and scripts as separate reviewed work. Keep Handy's local recordings untouched unless the user separately asks to delete them.

## Decision

**Hex can replace Handy as the dictation engine and use Handy's kmDot visual language.** The installed build supports a read-only custom history list through its versioned retained-history schema, but model changes still need Hex's window. Playback/retry and per-entry edits/deletes remain unsupported by this Hex build. Newer upstream model/history commands should be enabled only after they are verified on the installed binary.

## Primary sources

- [Hex Linux installation and behavior guide](https://github.com/anomalyco/hex/blob/dev/docs/linux.md)
- [Hex control CLI reference](https://github.com/anomalyco/hex/blob/dev/docs/cli.md)
- [Hex transcript CLI and platform notes](https://github.com/anomalyco/hex/blob/dev/docs/transcript-cli.md)
- [Hex project README](https://github.com/anomalyco/hex)
- [Handy project README](https://github.com/cjpais/Handy)
