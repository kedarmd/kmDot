// Shared geometry helpers for top-bar dropdown cards. Popup windows are
// fullscreen PanelWindows pinned to one screen; the card inside is centered
// under the global center X of the bar module that opened it (the anchorItem
// seam) and clamped to the screen edges.

function globalCenterX(item) {
  if (!item) return -1
  try {
    return item.mapToGlobal(item.width / 2, 0).x
  } catch (e) {
    const win = item.Window && item.Window.window ? item.Window.window : null
    if (!win) return -1
    const pos = item.mapToItem(win.contentItem, item.width / 2, 0)
    return (win.x || 0) + pos.x
  }
}

function screenFor(screens, x) {
  for (let i = 0; i < screens.length; i++) {
    const s = screens[i]
    if (x >= s.x && x < s.x + s.width) return s
  }
  return null
}

function cardXFor(centerGX, cardWidth, screen) {
  const sX = screen ? screen.x : 0
  const sW = screen ? screen.width : 0
  const cx = centerGX - sX - cardWidth / 2
  if (sW < cardWidth + 20) return Math.max(10, cx)
  return Math.max(10, Math.min(sW - cardWidth - 10, cx))
}
