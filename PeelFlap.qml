import QtQuick
import QtQuick.Shapes

// The same folded sheet is used while pulling, falling, and resting in the pile.
Item {
  id: root
  property var frame: null
  property real fibreOpacity: 1
  width: 200
  height: 200

  Shape {
    x: 1.5; y: 3
    opacity: 0.13
    ShapePath {
      fillColor: "#68452d"; strokeColor: "transparent"
      PathSvg { path: root.frame ? root.frame.underside : "" }
    }
  }
  Shape {
    ShapePath {
      fillColor: "#ffebc2"; strokeColor: "#d99c5a"; strokeWidth: 1.2
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.frame ? root.frame.underside : "" }
    }
    ShapePath {
      fillColor: "#f6a548"; strokeColor: "#c17c38"; strokeWidth: 1.2
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.frame ? root.frame.outside : "" }
    }
    ShapePath {
      fillColor: "transparent"; strokeColor: "#e8c991"; strokeWidth: 1.1
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.marks : "" }
    }
    ShapePath {
      fillColor: "transparent"; strokeColor: "#fff0ce"; strokeWidth: 2.3
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.rim : "" }
    }
  }
  Shape {
    opacity: root.fibreOpacity
    ShapePath {
      fillColor: "transparent"; strokeColor: "#fff0ce"; strokeWidth: 0.9
      capStyle: ShapePath.RoundCap
      PathSvg { path: root.frame ? root.frame.fibres : "" }
    }
  }
}
