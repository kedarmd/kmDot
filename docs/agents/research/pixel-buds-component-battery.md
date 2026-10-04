# Research: per-component battery (L/R/case) for Pixel Buds in the Quickshell bluetooth views

Question behind this note: the bluetooth launcher/dropdown shows one battery
percentage for a connected device. For Google Pixel Buds that should be three
values — left bud, right bud, and the case — instead. Can kmDot render those,
and if not, why not?

**Answer: not from anything kmDot already has.** The three values do not exist in
the standard Bluetooth Battery service and Quickshell cannot reach the service
that does hold them. The only practical source is Google's proprietary *Maestro*
RPC over RFCOMM, which today means a third-party Rust binary. Details and the
full option analysis below.

Verified live on this machine (BlueZ 5.87-2.1, quickshell 0.3.1-1.1) against
`AC:3E:B1:84:42:65` "Kedar's Pixel Buds Pro".

## 1. What BlueZ actually exposes — exactly one number

The Pixel Buds are **one** BlueZ device object, not three. `bluetoothctl devices`
lists a single address, and the D-Bus object carries a **single**
`org.bluez.Battery1` interface (plus `Bearer.BREDR1` and `Bearer.LE1` — the buds
negotiate both a classic and an LE bearer).

```
$ busctl --system tree org.bluez | grep -A5 dev_AC_3E_B1_84_42_65
/org/bluez/hci0/dev_AC_3E_B1_84_42_65
├─ …/sep1   ├─ …/sep2/fd0   └─ …/sep3   # classic RFCOMM profile sockets, not GATT

$ gdbus introspect --system --dest org.bluez \
    --object-path /org/bluez/hci0/dev_AC_3E_B1_84_42_65/sep1 | grep UUID
  readonly s UUID = '0000110b-…'   # Audio Sink; fd0 under sep2 = 0x110a A/V Remote Control

$ gdbus call --system --dest org.bluez \
    --object-path /org/bluez/hci0/dev_AC_3E_B1_84_42_65 \
    --method org.freedesktop.DBus.Properties.GetAll org.bluez.Battery1
({'Percentage': <byte 0x07>},)
```

`bluetoothctl info` prints the same single `Battery Percentage: 0x09`; the two
readings differed only because the buds kept discharging between the two calls.
There is no `Left` / `Right` / `Case` property anywhere on the object.

So `BluetoothStore.qml`'s `d.battery` → `BluetoothLauncher.qml`'s
`BtJs.batteryLabel()` is not picking the wrong component — it is reading the only
component BlueZ publishes. Two follow-on facts from the same investigation:

- **No GATT route either.** BlueZ exposes no `GattService1` / `GattCharacteristic1`
  objects for this device — the only children of the device node are the three
  classic RFCOMM profile sockets (`0x110b` Audio Sink, with an `fd0` A/V Remote
  Control descriptor under `sep2`), which carry no readable characteristics. So
  there is no `ReadValue()` target. `gatttool` was removed from BlueZ years ago,
  `btmgmt` has no GATT commands, and BlueZ 5.87's `bluetoothctl-gatt` is not
  packaged on Arch (`bluez-utils` ships `btgatt-client`, an interactive raw-HCI
  client that needs root and its own ACL connection). Dead end without new
  tooling.
- **Quickshell's Bluetooth service has no UUID or GATT surface at all.** Per
  `/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes`,
  `BluetoothDevice` exposes `address`, `dbusPath`, `name`, `deviceName`, `icon`,
  `state`, `battery`, `batteryAvailable`, `connected`, `paired`, `bonded`,
  `pairing`, `blocked`, `trusted`, `wakeAllowed`, plus `connect`/`disconnect`/
  `pair`/`cancelPair`/`forget`. `battery` is the single percentage above. So
  there is nothing to extend on the kmDot side.

## 2. Where the three values actually live: the Maestro profile

Pixel Buds publish a proprietary RPC profile over RFCOMM SPP:

- **UUID `25e97ff7-24ce-4c4c-8951-f764a708f7b5`** (this is in the device's own
  advertised `UUIDs` list, so the buds in hand do support it), plus five other
  vendor UUIDs (`25e97ff7-…b4`, `74c34f02-…`, `81c2e72a-…`, `df21fe2c-…`,
  `f8d1fbe4-…`).
- The client subscribes to a runtime-info event and gets protobuf
  `RuntimeInfo { int64 timestamp_ms = 2; int32 unknown3 = 3; BatteryInfo
  battery_info = 6; PlacementInfo placement = 7; }`, where
  `BatteryInfo { DeviceBatteryInfo case = 1; left = 2; right = 3; }` and
  `DeviceBatteryInfo { int32 level = 1; BatteryState state = 2; }` with
  `BATTERY_STATE_UNKNOWN / NOT_CHARGING / CHARGING`. `PlacementInfo` carries
  `right_bud_in_case` / `left_bud_in_case`.

Sources: `qzed/pbpctrl` — `libmaestro/src/lib.rs` (the UUID),
`libmaestro/proto/maestro_pw.proto` (the message shapes),
`libmaestro/examples/maestro_get_battery.rs` and `cli/src/main.rs`
(`cmd_show_battery`, `cmd_show_runtime`) for consumption.

Two behavioural caveats that matter for the requested semantics:

- **The case has no Bluetooth radio of its own.** Its level is only reported
  while at least one bud is docked (pbpctrl README, "Notes on Battery
  Information"). So "the case **when it is available**" is literally how the
  protocol behaves — there is nothing to poll for when both buds are out.
- **A docked bud is not a connected bud.** `PlacementInfo` is what distinguishes
  "left earbud when they are connected" from "left earbud is charging in the
  case"; a naive level render would show a docked bud as an in-use one.

## 3. Why a first-party implementation is not proportionate

Getting at Maestro from a script means being an RFCOMM **client**, and BlueZ will
only hand the socket to a process that registers a profile via D-Bus
`org.bluez.Profile1` with `Role::Client` and accepts the `NewConnection` fd —
`libmaestro/examples/common/mod.rs::connect_maestro_rfcomm` does exactly that.
On top of it sit CRC-framed HDLC packets, protobuf varint encoding, and a
hand-rolled `RuntimeInfo` decoder.

Reference size for exactly that, from the reference implementation:

| Path | Lines | Bytes |
|---|---|---|
| `libmaestro/src` (hdlc, protocol, pwrpc, service) | 3 652 | 107 861 |
| `libmaestro/proto/*.proto` | 388 | 10 564 |
| **libmaestro total** | **4 040** | **118 425** |
| …minus `service/settings.rs` (828 lines, settings not needed for battery) | 3 212 | — |

Against that, kmDot's runtime rule (AGENTS.md) is bash, or **zero-dependency**
Node — `calendar-events.mjs` implements its own iCal/RRULE expansion and TZ
resolution rather than pull a library. A faithful Node port would additionally
need hand-written D-Bus client marshalling *with Unix fd passing* on the system
bus, which is well outside anything the repo has today. Verdict: disproportionate,
and fragile against a proprietary protocol that Google can change.

## 4. The options

### Option A — `qzed/pbpctrl` as the data source (the only cheap path)

`pbpctrl` (AUR) wraps the protocol and prints exactly the numbers wanted:

```
$ pbpctrl -d AC:3E:B1:84:42:65 show battery
case:      85% (not charging)
left bud:  70% (not charging)
right bud: 65% (not charging)
```

`show runtime` additionally prints `placement:` per bud plus the connection
addresses. It also auto-discovers the device when `-d` is omitted
(`cli/src/bt.rs::find_maestro_device`), so it needs no address plumbing.

Costs and risks:

1. **Hard runtime dependency**, for a bar/dropdown detail. `install.sh` would
   need it, and every view must degrade silently to today's single percentage
   when the binary is absent.
2. **Rust toolchain.** `pbpctrl` is AUR-source-only (no GitHub release assets;
   v0.1.8 latest). There is no `cargo`/`rustc` on this machine, so this pulls
   `rust` (~1–1.5 GB) to build. Note this collides head-on with the known-red
   Rust source-build path already tracked in **issue #99** (zen-browser fails at
   `configure` on minimal Arch with `Don't know how to translate
   x86_64-pc-linux-gnu for rustc`). Adding a *second* mandatory Rust source
   build to `install.sh` should not be done while #99 is open.
3. **Not a free poll.** Each invocation opens and tears down an RFCOMM session.
   Fine on launcher open and on a slow 3–5 s timer while open; **not** viable on
   the 2 s background cadence `BluetoothStore` uses for device state, because it
   would spam the radio.

### Option B — Reimplement Maestro in Node

Section 3. Rejected: ~3 200 lines of protocol plus a D-Bus server-side profile
implementation, zero-dependency, against an undocumented protocol. Not a
proportionate trade for a battery line, and it would be the only place in the
repo violating the dependency-free-Node rule.

### Option C — BlueZ experimental AVCPR battery

BlueZ has experimental AVCPR (Apple Continuity) battery support, which pbpctrl's
README notes the Pixel Buds also speak. It requires `Experimental = true` in
`/etc/bluetooth/main.conf` (or `--experimental` on the daemon) and — per the same
README — "will only provide a single battery meter for both buds combined, and
none for the case". **Rejected: it does not answer the request.** Worth recording
only so nobody re-derives it.

## 5. What the kmDot change would look like, if Option A is ever taken

Noted for the eventual ticket; deliberately not implemented.

- `config/quickshell/scripts/pixel-buds-battery.sh` — thin wrapper over
  `pbpctrl show battery` (+ `show runtime` for `placement`), emitting
  `key=value` lines in the same shape as the existing
  `scripts/battery-history.sh`, and exiting quietly when `pbpctrl` is missing.
- `BluetoothStore.qml` — a `Process` filling per-component fields onto the
  matching mapped entry (match on `d.address`, which *is* available on
  `BluetoothDevice`), keeping BlueZ's single `battery` as the fallback for every
  other device and for buds when the probe fails. Refresh it from the launcher's
  `onOpenedChange()` plus a slow timer while open — **not** from the 2 s poll.
- `BluetoothLauncher.qml` / `BluetoothDropdown.qml` — render the extra line
  through the existing `itemBody` seam (`LauncherBase`'s optional third line; the
  delegate already grows the row for it), so `LauncherBase` itself needs no
  change. `BluetoothDropdown` would need the same seam treatment.

## 6. Recommendation

**Do not implement now.** Keep the single percentage, which is correct for every
non-Pixel device and is the only number BlueZ publishes. If the L/R/case line is
wanted later, the gating decision is not technical but a dependency decision:
whether kmDot is willing to carry a Rust source build from the AUR while #99 is
open. That is a maintainer call, so this is parked rather than scheduled.

## Sources

Primary:

- Live D-Bus/GATT inspection on this machine — `busctl --system tree org.bluez`,
  `gdbus introspect --system --dest org.bluez --object-path
  /org/bluez/hci0/dev_AC_3E_B1_84_42_65 --xml`, `bluetoothctl info`,
  `bluetoothctl devices` (BlueZ 5.87-2.1).
- `/usr/lib/qt6/qml/Quickshell/Bluetooth/quickshell-bluetooth.qmltypes`
  (quickshell 0.3.1-1.1) — the complete `BluetoothDevice` property set.
- `qzed/pbpctrl` — `libmaestro/src/lib.rs`,
  `libmaestro/proto/maestro_pw.proto`, `libmaestro/examples/common/mod.rs`,
  `libmaestro/examples/maestro_get_battery.rs`, `cli/src/main.rs`,
  `cli/src/bt.rs`, `README.md`.

Secondary, consulted only to locate the primary source:

- Home Assistant community thread "Bluetooth Battery Levels (Android)" — the
  observation that a Pixel Buds Pro reports a single level on Android too, which
  is what pointed at the standard Battery service being the wrong place to look.
- 9to5Google / AndroidPolice on Pixel Buds Pro 2 firmware 4.467 broadcasting
  per-component battery — confirms Google treats the three levels as distinct
  but is Android/Google-side, not a Linux path.

No claim in sections 1–3 rests on a write-up; each is traced to a command run on
this machine or to the `pbpctrl` source that defines the protocol.