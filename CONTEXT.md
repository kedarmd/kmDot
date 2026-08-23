# Context

Glossary for kmDot's domain language. Terms only — implementation detail lives in code and AGENTS.md.

## Surfaces

- **Launcher** — a keyboard-first picker: centered card with search box, scored results, footer. Opened by global keybind or bar click through its unix socket; one instance per launcher, coordinated so opening one closes any other.
- **Popup** — an anchored dropdown card opened from a top-bar module (battery, volume, brightness, calendar, handy). Card appears under the module that owns it.
- **Dropdown** — a tray-style card opened from inside the hidden-modules tray (e.g. server mode).
- **Mode pill** — the right-aligned footer pill in a launcher used to toggle a two-mode surface (e.g. Models ↔ History); Tab triggers it like any footer action.

## Handy

- **Handy launcher** — the Super+H launcher managing transcription models and recent recordings. Coexists with the tray popup: the launcher owns quick keyboard verbs (switch model, copy, retry, play); the popup keeps the mouse-first rich surface (inline editing, playback progress). Neither replaces the other.
- **Recording** — one WAV plus its transcription row from Handy's history. Capped at the 5 most recent entries everywhere.
