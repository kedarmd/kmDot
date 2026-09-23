# Wi-Fi/Bluetooth Verification Matrix

The radio stores are overlay-agnostic. `shell.qml` owns the six radio views and
closes every other surface before opening one. The four socket-backed views are:

| Surface | Socket |
| --- | --- |
| Wi-Fi launcher | `kmdot-wifi` |
| Bluetooth launcher | `kmdot-bluetooth` |
| Wi-Fi dropdown | `kmdot-wifi-dropdown` |
| Bluetooth dropdown | `kmdot-bluetooth-dropdown` |

## Reload and Socket Cycle

1. Start the repo config with `quickshell --path config/quickshell`.
2. Confirm all four socket paths exist under `$XDG_RUNTIME_DIR`.
3. Toggle each socket twice with `config/quickshell/scripts/toggle.sh <socket>`.
4. Leave each launcher and dropdown open in turn, reload quickshell, and repeat step 2.
5. Remove or stale one socket, then run its toggle command and confirm the command self-heals quickshell and reconnects.

## Surface Matrix

Run each row from both its launcher and dropdown where applicable:

| Action | Wi-Fi | Bluetooth |
| --- | --- | --- |
| Scan/list | launcher + dropdown | launcher + dropdown |
| Connect/pair | saved, open, secured failure | paired, unpaired pair-then-connect |
| Disconnect | active network | connected device |
| Forget | confirm, cancel, confirm | confirm, cancel, confirm |
| Toggle radio | off, on, rescan | off, on, rediscover |
| Coordination | open the other radio view and another popup | open the other radio view and another popup |

Add and confirm popup flows should also be exercised at human speed. No mouse
synthesis is required for this manual pass.
