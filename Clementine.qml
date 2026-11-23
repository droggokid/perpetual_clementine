import QtQuick
import QtQuick.Shapes
import "FruitModel.js" as Model

Item {
  id: root

  property int animationDuration: 0
  property bool interactive: true
  property string accessibleName: ""
  property string accessibleDescription: ""
  property int pattern: Model.nextPattern(-1, Math.random())
  property int variant: Math.floor(Math.random() * 6)
  property int peeledMask: 0
  property int activePeel: -1
  property real peelProgress: 0
  property real peelTarget: 0
  property int eaten: 0
  property int selected: 0
  property int fading: 0
  property real fade: 0
  property int hovered: -1
  property int keyboardIndex: -1
  property string gesture: ""
  property point origin: Qt.point(0, 0)
  property point previous: Qt.point(0, 0)
  readonly property var pieces: Model.peelPieces(pattern, variant)
  readonly property bool fullyPeeled: peeledMask === (1 << pieces.length) - 1
  readonly property int remaining: Model.segments - Model.count(eaten)
  readonly property int peelRemaining: pieces.length - Model.count(peeledMask)
  readonly property bool busy: peelSettle.running || eatAnimation.running
  readonly property real artScale: Math.max(0.1, Math.min(1, width / 220, height / 220))
  readonly property real centerX: width / 2
  readonly property real centerY: height / 2
  readonly property string bodyPath: Model.path(Model.bodyPoints())

  Accessible.role: Accessible.Button
  Accessible.name: accessibleName
  Accessible.description: accessibleDescription
  Accessible.onPressAction: keyboardAction()

  function artPoint(x, y) {
    return Qt.point((x - centerX) / artScale + 100, (y - centerY) / artScale + 100);
  }
  function hitAt(x, y) {
    var p = artPoint(x, y);
    return fullyPeeled ? Model.hitSegment(p.x, p.y, eaten)
      : Model.hitPeel(pieces, peeledMask, p.x, p.y);
  }
  function finishPeel() {
    if (activePeel >= 0 && peelTarget === 1) peeledMask |= 1 << activePeel;
    activePeel = -1;
    peelProgress = 0;
    hovered = -1;
    keyboardIndex = -1;
  }
  function animatePeel(target) {
    if (activePeel < 0) return;
    peelTarget = target;
    if (animationDuration === 0) { peelProgress = target; finishPeel(); }
    else { peelSettle.from = peelProgress; peelSettle.to = target; peelSettle.restart(); }
  }
  function finishEating() { fading = 0; fade = 0; keyboardIndex = -1; }
  function eatSelection() {
    var take = selected & ~eaten;
    selected = 0;
    if (!take) return;
    fading = take;
    eaten |= take;
    fade = 0;
    if (animationDuration === 0) finishEating();
    else eatAnimation.restart();
  }
  function cancelGesture() {
    if (gesture === "peel") animatePeel(0);
    selected = 0;
    gesture = "";
  }
  function finishTransition() {
    peelSettle.stop();
    eatAnimation.stop();
    if (activePeel >= 0) finishPeel();
    finishEating();
  }
  function reset() {
    peelSettle.stop();
    eatAnimation.stop();
    gesture = "";
    activePeel = -1;
    peelProgress = 0;
    peelTarget = 0;
    peeledMask = 0;
    eaten = 0;
    selected = 0;
    fading = 0;
    fade = 0;
    hovered = -1;
    keyboardIndex = -1;
    pattern = Model.nextPattern(pattern, Math.random());
    variant = Math.floor(Math.random() * 6);
  }
  function available(index) {
    return index >= 0 && index < (fullyPeeled ? Model.segments : pieces.length)
      && !((fullyPeeled ? eaten : peeledMask) & (1 << index));
  }
  function moveCursor(direction) {
    if (gesture !== "" || busy) return;
    var total = fullyPeeled ? Model.segments : pieces.length;
    for (var step = 1; step <= total; step++) {
      var next = ((keyboardIndex < 0 ? (direction > 0 ? -1 : 0) : keyboardIndex)
        + direction * step + total * 2) % total;
      if (available(next)) { keyboardIndex = next; return; }
    }
  }
  function keyboardAction() {
    if (!interactive || busy || gesture !== "") return;
    if (!available(keyboardIndex)) { keyboardIndex = -1; moveCursor(1); }
    if (!available(keyboardIndex)) return;
    if (fullyPeeled) { selected = 1 << keyboardIndex; eatSelection(); }
    else { activePeel = keyboardIndex; peelProgress = 0; animatePeel(1); }
  }

  onInteractiveChanged: if (!interactive) {
    cancelGesture();
    finishTransition();
    hovered = -1;
  }
  onAnimationDurationChanged: if (animationDuration === 0) finishTransition()

  NumberAnimation {
    id: peelSettle
    target: root; property: "peelProgress"
    duration: root.animationDuration
    easing.type: Easing.OutCubic
    onFinished: root.finishPeel()
  }
  NumberAnimation {
    id: eatAnimation
    target: root; property: "fade"; from: 0; to: 1
    duration: Math.min(160, root.animationDuration)
    easing.type: Easing.OutCubic
    onFinished: root.finishEating()
  }

  Item {
    id: art
    width: 200; height: 200
    x: root.centerX - 100; y: root.centerY - 100
    scale: root.artScale
    // Tiny compression acknowledges a tug without moving the fruit's anchor.
    transform: Scale {
      origin.x: 100; origin.y: 110
      xScale: root.gesture === "peel" ? 1.025 : 1
      yScale: root.gesture === "peel" ? 0.98 : 1
      Behavior on xScale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
      Behavior on yScale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      x: 48; y: 179; width: 104; height: 10; radius: 52
      color: "#18000000"
      visible: root.remaining > 0 || root.fading !== 0
    }

    Repeater {
      model: root.pieces
      delegate: Shape {
        required property var modelData
        required property int index
        visible: (root.peeledMask & (1 << index)) !== 0
        x: 55 + (index % 3) * 39; y: 181 + (index % 2) * 4
        rotation: index % 2 ? -12 : 10
        ShapePath {
          fillColor: "transparent"; strokeColor: "#df8b3c"; strokeWidth: 8
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M -15 0 C -7 12 13 11 17 -3" }
        }
        ShapePath {
          fillColor: "transparent"; strokeColor: "#ffe0aa"; strokeWidth: 3
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M -15 0 C -7 12 13 11 17 -3" }
        }
      }
    }

    Repeater {
      model: Model.segments
      delegate: Shape {
        id: segmentArt
        required property int index
        readonly property var piece: Model.segment(index)
        readonly property bool picked: (root.selected & (1 << index)) !== 0
        readonly property bool leaving: (root.fading & (1 << index)) !== 0
        readonly property real spread: root.fullyPeeled ? (picked || root.hovered === index || root.keyboardIndex === index ? 8 : 5) : 0
        visible: !(root.eaten & (1 << index)) || leaving
        x: piece.dx * spread
        y: piece.dy * spread - (leaving ? root.fade * 13 : 0)
        opacity: leaving ? 1 - root.fade : 1
        transform: Scale {
          origin.x: 100; origin.y: 108
          xScale: segmentArt.leaving ? 1 - root.fade * 0.2 : 1
          yScale: xScale
        }
        Behavior on x { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
        ShapePath {
          fillColor: segmentArt.picked || root.keyboardIndex === segmentArt.index ? "#ffdc9d"
            : segmentArt.index % 2 ? "#ffbb68" : "#ffc77c"
          strokeColor: "#ffe8ba"; strokeWidth: 2.5
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: segmentArt.piece.path }
        }
        ShapePath {
          fillColor: "transparent"; strokeColor: "#ffe0a9"; strokeWidth: 1.6
          capStyle: ShapePath.RoundCap
          PathSvg { path: segmentArt.piece.fibre }
        }
      }
    }

    Repeater {
      model: root.pieces
      delegate: Shape {
        id: rind
        required property var modelData
        required property int index
        readonly property real pull: root.activePeel === index ? root.peelProgress : 0
        visible: !(root.peeledMask & (1 << index))
        x: modelData.side * pull * (root.pattern === 0 ? 43 : 30)
        y: pull * (root.pattern === 0 ? 37 : 44)
        opacity: 1 - Math.max(0, pull - 0.8) * 5
        transform: [
          Scale { origin.x: rind.modelData.cx; origin.y: rind.modelData.cy; xScale: 1 - rind.pull * 0.12; yScale: 1 - rind.pull * 0.65 },
          Rotation { origin.x: rind.modelData.cx; origin.y: rind.modelData.cy; angle: rind.modelData.side * rind.pull * 30 }
        ]
        ShapePath {
          // Identical fills conceal every boundary until a piece is pulled.
          fillColor: "#f5a44b"; strokeColor: "#f5a44b"; strokeWidth: 0.8
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: rind.modelData.path }
        }
        ShapePath {
          fillColor: "#ffe4ad"; strokeColor: "#f0bf7a"; strokeWidth: 1
          PathSvg { path: rind.pull > 0.32 ? rind.modelData.path : "" }
        }
      }
    }

    Shape {
      visible: root.peeledMask === 0 && root.activePeel < 0
      ShapePath {
        fillColor: "#f5a44b"; strokeColor: "#cf853b"; strokeWidth: 1.5
        PathSvg { path: root.bodyPath }
      }
      ShapePath {
        fillColor: "transparent"; strokeColor: "#ffd18b"; strokeWidth: 5
        capStyle: ShapePath.RoundCap
        PathSvg { path: "M 45 86 Q 49 70 64 65" }
      }
    }

    Item {
      visible: root.peeledMask === 0
      opacity: root.activePeel >= 0 ? 1 - root.peelProgress : 1
      Rectangle { x: 82; y: 110; width: 4; height: 6; radius: 2; color: "#80512e" }
      Rectangle { x: 113; y: 110; width: 4; height: 6; radius: 2; color: "#80512e" }
      Rectangle { x: 71; y: 121; width: 11; height: 5; radius: 5; color: "#e9956a" }
      Rectangle { x: 119; y: 121; width: 11; height: 5; radius: 5; color: "#e9956a" }
      Shape {
        ShapePath {
          fillColor: "transparent"; strokeColor: "#80512e"; strokeWidth: 1.8
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M 96 123 Q 100 128 104 123" }
        }
      }
    }

    Shape {
      x: 100; y: 49
      visible: root.peeledMask === 0
      opacity: root.activePeel >= 0 ? 1 - root.peelProgress : 1
      rotation: root.gesture === "peel" ? -12 - root.peelProgress * 18 : root.hovered >= 0 ? -7 : 0
      Behavior on rotation { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
      ShapePath {
        fillColor: "#91b66b"; strokeColor: "#6f944f"; strokeWidth: 1.3
        PathSvg { path: "M 0 0 C 4 -19 26 -25 34 -18 C 28 -4 12 4 0 0 Z" }
      }
      ShapePath {
        fillColor: "transparent"; strokeColor: "#6f944f"; strokeWidth: 1.2
        PathSvg { path: "M 2 -1 Q 14 -9 26 -15" }
      }
    }

    // A tiny raised edge points out the next keyboard-accessible peel.
    Shape {
      readonly property int nextPeel: {
        if (root.fullyPeeled || root.activePeel >= 0) return -1;
        if (root.available(root.keyboardIndex)) return root.keyboardIndex;
        for (var i = 0; i < root.pieces.length; i++) if (root.available(i)) return i;
        return -1;
      }
      visible: nextPeel >= 0
      x: nextPeel >= 0 ? root.pieces[nextPeel].cx - 5 : 0
      y: nextPeel >= 0 ? root.pieces[nextPeel].cy - 3 : 0
      ShapePath {
        fillColor: "#ffe3aa"; strokeColor: "#cf853b"; strokeWidth: 1.1
        PathSvg { path: "M 0 0 Q 5 -6 10 0 Q 5 -1 0 0 Z" }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    preventStealing: true
    cursorShape: root.gesture !== "" ? Qt.ClosedHandCursor
      : root.hovered >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    onExited: root.hovered = -1
    onCanceled: root.cancelGesture()
    onPressed: function(mouse) {
      if (root.busy || root.gesture !== "") return;
      var id = root.hitAt(mouse.x, mouse.y);
      if (id < 0) return;
      root.keyboardIndex = -1;
      root.origin = Qt.point(mouse.x, mouse.y);
      root.previous = root.origin;
      if (root.fullyPeeled) { root.gesture = "eat"; root.selected = 1 << id; }
      else { root.gesture = "peel"; root.activePeel = id; root.peelProgress = 0; }
    }
    onPositionChanged: function(mouse) {
      root.hovered = root.hitAt(mouse.x, mouse.y);
      if (root.gesture === "peel") {
        var distance = Math.hypot(mouse.x - root.origin.x, mouse.y - root.origin.y);
        root.peelProgress = Math.min(0.96, distance / (root.artScale * 72));
      } else if (root.gesture === "eat") {
        var a = root.artPoint(root.previous.x, root.previous.y), b = root.artPoint(mouse.x, mouse.y);
        root.selected = Model.sweep(a.x, a.y, b.x, b.y, root.eaten, root.selected);
      }
      root.previous = Qt.point(mouse.x, mouse.y);
    }
    onReleased: function(mouse) {
      if (root.gesture === "peel") root.animatePeel(root.peelProgress >= 0.5 ? 1 : 0);
      else if (root.gesture === "eat") {
        var a = root.artPoint(root.previous.x, root.previous.y), b = root.artPoint(mouse.x, mouse.y);
        root.selected = Model.sweep(a.x, a.y, b.x, b.y, root.eaten, root.selected);
        root.eatSelection();
      }
      root.gesture = "";
    }
  }
}
