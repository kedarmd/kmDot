import QtQuick
import QtQuick.Shapes
import qs

Item {
  id: root

  property bool isInput: false
  property bool muted: false
  property color color: Colors.text

  readonly property string glyphPath: root.isInput
    ? ("M12 2 C13.657 2 15 3.343 15 5 V12 C15 13.657 13.657 15 12 15 C10.343 15 9 13.657 9 12 V5 C9 3.343 10.343 2 12 2 Z "
      + "M5 11 C5 14.866 8.134 18 12 18 C15.866 18 19 14.866 19 11 M12 18 V22 M8 22 H16"
      + (root.muted ? " M4 4 L20 20" : ""))
    : ("M3 9 H7 L12 5 V19 L7 15 H3 V9 "
      + (root.muted
        ? "M16 9 L21 14 M21 9 L16 14"
        : "M16 8 C18.037 10.278 18.037 13.722 16 16 M19 5 C22.811 8.888 22.811 15.111 19 19"))

  Shape {
    anchors.fill: parent

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: 1.8
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      PathSvg { path: root.glyphPath }
    }
  }
}
