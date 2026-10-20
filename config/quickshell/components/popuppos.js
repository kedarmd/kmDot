// Shared geometry helpers for top-bar dropdown cards. Popup windows are
// fullscreen PanelWindows pinned to one screen; the card inside is centered
// under the anchor module in that window's local coordinates and clamped to
// the screen edges.

function anchorForItem(item, screens, owningWindow) {
  if (!item) return null
  try {
    const win = owningWindow
    if (win && win.screen) {
      const local = item.mapToItem(win.contentItem, item.width / 2, 0)
      return { screen: win.screen, centerX: local.x }
    }
  } catch (e) {
    // Fall through to the coordinate-based fallback for unusual item types.
  }
  const x = globalCenterX(item)
  if (x === null || !isFinite(x)) return null
  return { screen: screenFor(screens, x), centerX: x, global: true }
}

function globalCenterX(item) {
  if (!item) return null
  try {
    return item.mapToGlobal(item.width / 2, 0).x
  } catch (e) {
    return null
  }
}

function screenFor(screens, x) {
  for (let i = 0; i < screens.length; i++) {
    const s = screens[i]
    if (x >= s.x && x < s.x + s.width) return s
  }
  return null
}

// Primary screen for PanelWindow `screen:` bindings. Indexed access, not
// .values — the .values snapshot does not track the model (see PopupBase).
function primaryScreen(screens) {
  return screens.length > 0 ? screens[0] : null
}

function cardXFor(centerX, cardWidth, screen, global = false) {
  const sX = global && screen ? screen.x : 0
  const sW = screen ? screen.width : 0
  const cx = centerX - sX - cardWidth / 2
  if (sW < cardWidth + 32) return Math.max(16, cx)
  return Math.max(16, Math.min(sW - cardWidth - 16, cx))
}
