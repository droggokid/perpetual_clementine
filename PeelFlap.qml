import QtQuick
import QtQuick.Shapes

// The same folded sheet is used while pulling, falling, and resting in the pile.
Item {
  id: root
  property color rindColor: "#f6a548"
  property var frame: null
  property real fibreOpacity: 1
  property real groundContact: 0
  width: 200
  height: 200

  Shape {
    x: 1 - root.groundContact * 0.6
    y: root.frame ? (1.5 + root.frame.lift * 2.5) * (1 - root.groundContact) + 0.7 * root.groundContact : 0
    opacity: root.frame ? 0.16 - root.frame.lift * 0.055 + 0.07 * root.groundContact : 0
    ShapePath {
      fillColor: "#68452d"; strokeColor: "transparent"
      PathSvg { path: root.frame ? root.frame.underside : "" }
    }
    ShapePath {
      fillColor: "#68452d"; strokeColor: "transparent"
      PathSvg { path: root.frame ? root.frame.pinch : "" }
    }
  }
  Shape {
    ShapePath {
      fillGradient: LinearGradient {
        x1: root.frame ? root.frame.cx - 24 : 0; y1: root.frame ? root.frame.cy - 20 : 0
        x2: x1 + 48; y2: y1 + 40
        GradientStop { position: 0; color: "#fff1d4" }
        GradientStop { position: 0.54; color: "#f9e5bd" }
        GradientStop { position: 1; color: "#e6be88" }
      }
      strokeColor: Qt.darker(root.rindColor, 1.08); strokeWidth: 1.8
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.frame ? root.frame.underside : "" }
    }
    ShapePath {
      fillColor: "transparent"; strokeColor: "#d6ae7c"; strokeWidth: 1.3
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.marks : "" }
    }
    ShapePath {
      fillColor: "transparent"; strokeColor: "#fff0ce"; strokeWidth: 2
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.rim : "" }
    }
    ShapePath {
      fillColor: Qt.lighter(root.rindColor, 1.08)
      strokeColor: Qt.darker(root.rindColor, 1.1); strokeWidth: 0.7
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.frame ? root.frame.pinch : "" }
    }
    ShapePath {
      fillColor: "transparent"; strokeColor: "#ffe2ad"; strokeWidth: 1.5
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.lip : "" }
    }
  }
  Shape {
    opacity: root.fibreOpacity
    ShapePath {
      fillColor: "transparent"; strokeColor: "#fff0ce"; strokeWidth: root.frame && root.frame.taut ? 1.65 : 0.9
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.fibres : "" }
    }
  }
}
