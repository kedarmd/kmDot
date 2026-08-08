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
