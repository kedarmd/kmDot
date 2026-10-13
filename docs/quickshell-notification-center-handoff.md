# Notification Center Handoff

Updated: 2026-10-13

## Current status

The notification bell is at the far right after Battery, following the user’s latest placement trial. Top-bar tooltips have been removed at the user's request. These preferences supersede the original desktop design's bell placement. User review is in progress; final full-scope acceptance is not recorded.

DND-on now uses the approved R1 bell-off vector and blue tonal pill with light foreground. [DND-01 rev 1](quickshell-r1-dnd-state-proposal.md) records the user's approval, canonical component IDs, manifest update and live visual verification. The normal bell and unread dot behavior are retained.

The user accepted the deployed DND appearance (“Good”), then approved 20px eye/bell sizing. The bell is now after Battery, with Attention in the inline tray and the clock alone at center; this is a placement trial for a couple of days. Canonical DND assets stay 24px and render at 20px in the bar. The final placement startup reached `Configuration Loaded` in `/tmp/kmdot-bar-placement.log`. All implementation changes were committed as `5486179`, merged into `main`, and pushed to `origin/main`. Real message delivery and full-scope acceptance remain separate pending checks.

The Notification Center work is in `config/quickshell/menu/NotificationCenter.qml`.

- Expanded app groups use a clipped, bounded Flickable so long histories scroll without covering the pinned count/Clear all footer.
- The latest notification keeps its body and eligible Reply action. Older items render as compact summary rows.
- App group headings include the number of entries.
- Group and individual close actions use matching 24px targets and 16px glyphs. Entry summaries flex to put their timestamps and close actions on the same right edge as the group close.
- Small labels and metadata use the 12/14/16px JetBrains Mono scale. Existing TokyoNight semantic colors remain in use.

## Latest verification — 2026-10-13

The repo config was synced with `./sync/quickshell.sh`, Quickshell restarted, and startup reached `Configuration Loaded`. A live capture with grouped notifications is at `/tmp/kmDot-notifications-clear-all-final.png`. The footer action now matches the R1 120×40 filled pill, with a text-only `Clear all` label. The group and row close actions share a right edge; title, metadata sizes, TODAY label, scrollable group area, and pinned footer match the R1 board hierarchy. `git diff --check` passes, and the deployed tree matches `config/quickshell`.

## Fresh R1 review — 2026-10-13

The full-scope continuation corrected the 24px heading and DND text wrapping, bounded the group viewport to the 688px frame, added the R1 empty state, and fixed newest-group expansion after sorting. Live notifications expose their native action buttons and eligible Reply action; expired persisted history remains view-only. Toasts and the 488px reply composer now follow the R1 spacing/type/control geometry. Temporary preview state lives only under `/tmp`. See [the consolidated local review](quickshell-r1-local-review.md) and `/tmp/kmdot-r1-review/review.html` for comparison captures and verification limits.

## Design reference

- Penpot file: **Redesign**
- Page: **04 · Panels — R1**, ID `cfe1987a-fff1-803d-8008-c75906a01894`
- Board: **Notifications**, ID `cfe1987a-fff1-803d-8008-c75b9d29719f` (424×688)
- Historical screenshot that prompted the corrected close alignment: `/tmp/codex-clipboard-7EWBw0.png`
- Full redesign notes and history: [quickshell-penpot-redesign-handoff.md](quickshell-penpot-redesign-handoff.md)

No temporary preview IPC hook remains in `shell.qml`.

## Pending checks

- Real notification action execution and inline-reply delivery have not been verified; view fixtures demonstrated toast/reply layouts only.
- Persisted expired notifications are intentionally view-only; eligible actions require a live notification.
- Final user acceptance and broad narrow-screen/multi-monitor coverage remain pending. See the [main redesign handoff](quickshell-penpot-redesign-handoff.md) for the full pending list, including native Bluetooth passkey implementation.
