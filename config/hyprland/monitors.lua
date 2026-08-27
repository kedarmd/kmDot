-- Load display settings overrides (written by kmDot Display module).
-- Falls back to hardcoded defaults if the file doesn't exist or is empty.
local ok, overrides = pcall(require, "display-settings")
if ok and type(overrides) == "table" and #overrides > 0 then
    for _, rule in ipairs(overrides) do hl.monitor(rule) end
else
    -- Internal display on the left (at origin 0,0)
    hl.monitor({
        output   = "eDP-1",
        mode     = "1920x1080@60",
        position = "0x0",
        scale    = 1,
    })

    -- External display on the right (offset by 1920 pixels)
    hl.monitor({
        output   = "HDMI-A-1",
        mode     = "1920x1080@60",
        position = "1920x0",
        scale    = 1,
    })
end
