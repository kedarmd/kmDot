// libnotify can put named icons in image-path while leaving app_icon empty.
// Keep named source icons; image attachments/paths remain notification content.
function sourceIcon(notification) {
  if (notification.appIcon) return String(notification.appIcon)
  const hints = notification.hints || {}
  const path = String(hints["image-path"] || hints.image_path || "")
  return path && !/[/:]/.test(path) ? path : ""
}
