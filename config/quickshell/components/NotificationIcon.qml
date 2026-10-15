import QtQuick
import Quickshell
import qs

// Desktop-entry lookup is asynchronous at shell startup. Reading values keeps
// already-visible icons reactive when the installed application index arrives.
Item {
  id: root
  property string desktopEntry: ""
  property string appIcon: ""
  property string appName: ""
  width: 24
  height: 24
  readonly property var applications: DesktopEntries.applications.values
  readonly property var entry: {
    const ready = applications.length
    return desktopEntry ? DesktopEntries.byId(desktopEntry.replace(/\.desktop$/, ""))
      : DesktopEntries.heuristicLookup(appName)
  }
  readonly property string deviceIcon: /mouse|tablet/.test(appIcon) ? "mouse"
    : /keyboard/.test(appIcon) ? "keyboard"
    : /audio|headphone|headset/.test(appIcon) ? "headphones" : ""
  readonly property string category: {
    const name = appName.toLowerCase()
    if (/bluetooth|blueman/.test(name)) return "bluetooth"
    if (/wi-?fi|network/.test(name)) return "wifi"
    if (/hyprshot|grim|screenshot|flameshot/.test(name)) return "camera-photo"
    return "bell"
  }
  // Typed device notifications must not be replaced by the manager app's logo.
  readonly property var candidates: deviceIcon ? [] : [entry ? entry.icon : "", appIcon]
  property int candidate: 0
  onCandidatesChanged: candidate = 0
  readonly property var resolved: {
    for (let i = candidate; i < candidates.length; i++) {
      const name = String(candidates[i] || "")
      if (!name || name.startsWith("\\u")) continue
      const url = /^(\/|file:|image:)/.test(name) ? name : Quickshell.iconPath(name, true)
      if (url) return { index: i, url: url }
    }
    return { index: candidates.length, url: "" }
  }
  Image {
    id: image
    anchors.fill: parent
    source: root.resolved.url
    sourceSize: Qt.size(24, 24)
    fillMode: Image.PreserveAspectFit
    visible: status === Image.Ready
    onStatusChanged: if (status === Image.Error && root.candidate < root.candidates.length)
      root.candidate = root.resolved.index + 1
  }
  R1Icon {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready
    iconName: root.deviceIcon || (root.category === "camera-photo" ? "" : root.category)
    glyph: root.category === "camera-photo" ? "\uf030" : ""
    font.pixelSize: 24
    color: Colors.text_alt
  }
}
