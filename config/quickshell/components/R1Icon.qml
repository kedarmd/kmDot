import QtQuick
import qs
import "nerdicons.js" as NerdIcons

// Shared Nerd Font renderer for kmDot's symbolic UI icons. Keep semantic
// names at call sites, but resolve every symbol to a glyph in the installed
// JetBrainsMono Nerd Font so icons share one rendering path.
Text {
  id: root
  property string glyph: ""
  property string iconName: ""
  text: NerdIcons.normalizeGlyph(root.glyph || NerdIcons.glyph(root.iconName))
  font.family: "JetBrainsMono Nerd Font Propo"
  font.pixelSize: 16
  color: Colors.text
  horizontalAlignment: root.horizontalAlignment
  verticalAlignment: root.verticalAlignment
}
