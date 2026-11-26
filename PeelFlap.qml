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

  Item {
    x: 1 - root.groundContact * 0.6
    y: root.frame ? (1.5 + root.frame.lift * 2.5) * (1 - root.groundContact) + 0.7 * root.groundContact : 0
    opacity: root.frame ? 0.16 - root.frame.lift * 0.055 + 0.07 * root.groundContact : 0
    Repeater {
      model: 2
      delegate: Shape {
        required property int index
        ShapePath {
          fillColor: "#68452d"; strokeColor: "transparent"
          PathSvg { path: root.frame ? root.frame.bands[index].path : "" }
        }
      }
    }
  }
  // The curled inner face lies above the section leading into the crease.
  Repeater {
    model: 2
    delegate: Shape {
      id: strip
      required property int index
      readonly property var band: root.frame ? root.frame.bands[index] : null
      readonly property bool pale: band ? band.pith : false
      ShapePath {
        fillGradient: LinearGradient {
          x1: root.frame ? root.frame.cx - 24 : 0; y1: root.frame ? root.frame.cy - 20 : 0
          x2: x1 + 48; y2: y1 + 40
          GradientStop { position: 0; color: strip.pale ? "#fff1d4" : Qt.lighter(root.rindColor, 1.13) }
          GradientStop { position: 1; color: strip.pale ? "#e6be88" : Qt.darker(root.rindColor, 1.12) }
        }
        strokeColor: "transparent"
        PathSvg { path: strip.band ? strip.band.path : "" }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: strip.pale ? "#e6be88" : Qt.darker(root.rindColor, 1.08); strokeWidth: 0.65
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: strip.band ? strip.band.rim : "" }
      }
      ShapePath {
        fillColor: "#d88739"; strokeColor: "transparent"
        PathSvg { path: strip.band ? strip.band.pores : "" }
      }
      ShapePath {
        fillColor: "#ffd28b"; strokeColor: "transparent"
        PathSvg { path: strip.band ? strip.band.lights : "" }
      }
      ShapePath {
        fillColor: "transparent"; strokeColor: "#d6ae7c"; strokeWidth: 1
        PathSvg { path: strip.band ? strip.band.marks : "" }
      }
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
