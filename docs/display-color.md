# Display color adjustment

Open **Display → Color adjustment** for the selected screen. Contrast,
saturation, and midtones (gamma) apply live, with 100% marking neutral.
Reset restores all three to neutral. Brightness remains a separate backlight
control. Tab focuses a slider; Left/Right adjust it in one-percent steps.

The view uses the existing panel, pill, slider, typography, and color roles.
Keeping color controls in a separate view avoids expanding the everyday
layout, resolution, brightness, and scale controls.

## Implementation and limits

`DisplayColorState.qml` coalesces slider changes and calls `scripts/display-color.sh`.
The bash helper uses the existing jq dependency, serializes updates with flock,
and saves per-connector values in `$XDG_STATE_HOME/kmdot/display-color.json`
(default `~/.local/state/kmdot/`). No additional packages are required.

Hyprland's final screen shader receives the monitor ID via `uniform int wl_output`.
The fragment shader explicitly uses GLSL ES 3.00 (`#version 300 es`), matching
Hyprland 0.56's vertex shader. Standalone fragment compilation is insufficient
validation: a GLES program link is required to catch version mismatches.
The helper regenerates routing from the current monitor inventory, including
hotplug ID changes, and only adjusts enabled SDR outputs. These software
adjustments work on internal and external screens; external DDC support is not
required. HDR outputs are left unchanged. Another configured screen shader
blocks these controls instead of being replaced. Neutral settings remove our
shader. A four-second reconciliation restores saved values after compositor
reloads and session starts while Quickshell is running.

This is appearance adjustment, not measured ICC calibration. Software filters
can clip highlights or shadows at strong settings and do not change the hardware
cursor. They add a final rendering pass when non-neutral. Mirroring and capture
paths may use an unmodified image; these settings belong to the physical output.

Upstream references (checked against the installed Hyprland 0.56.2):

- [Final shader application and wl_output monitor ID](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/OpenGL.cpp)
- [Uniform registration](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/Shader.cpp)
- [Color management: native SDR saturation only applies in HDR mode](https://wiki.hypr.land/configuring/core/monitors/colors/)
