import QtQuick
import QtQuick.Shapes
import "FruitModel.js" as Model

Item {
  id: root

  property int animationDuration: 0
  property int renewDelay: 1400
  property real arrival: 1
  property var peelAxis: null
  property int dropping: -1
  property real dropProgress: 0
  property var dropFrame: null
  property var landed: []
  property bool interactive: true
  property string accessibleName: ""
  property string accessibleDescription: ""
  property int pattern: -1
  property int variant: Model.nextVariant(-1, Math.random())
  property point startPoint: Qt.point(100, 62)
  property point previewStart: Qt.point(100, 62)
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
  readonly property bool patternChosen: pattern >= 0
  readonly property var pieces: patternChosen ? Model.peelPieces(pattern, variant, startPoint.x, startPoint.y) : []
  readonly property bool fullyPeeled: patternChosen && peeledMask === (1 << pieces.length) - 1
  readonly property int remaining: Model.segments - Model.count(eaten)
  readonly property int peelRemaining: pieces.length - Model.count(peeledMask)
  readonly property bool busy: peelSettle.running || eatAnimation.running || dropAnimation.running || arriveAnimation.running
  readonly property var peelFrame: activePeel >= 0 && peelAxis
    ? Model.peelFrame(pieces[activePeel], peelProgress, peelAxis) : null
  readonly property real artScale: Math.max(0.1, Math.min(1, width / 220, height / 220))
  readonly property real centerX: width / 2
  readonly property real centerY: height / 2
  readonly property var bodyOutline: Model.bodyPoints()
  readonly property string bodyPath: Model.path(bodyOutline)
  readonly property var bodyTexture: Model.rindTexture(bodyOutline)

  Accessible.role: Accessible.Button
  Accessible.name: accessibleName
  Accessible.description: accessibleDescription
  Accessible.onPressAction: keyboardAction()

  function artPoint(x, y) {
    return Qt.point((x - centerX) / artScale + 100, (y - centerY) / artScale + 100);
  }
  function hitAt(x, y) {
    var p = artPoint(x, y);
    if (!patternChosen) return Model.inside(bodyOutline, p.x, p.y) ? 0 : -1;
    return fullyPeeled ? Model.hitSegment(p.x, p.y, eaten)
      : Model.hitPeel(pieces, peeledMask, p.x, p.y);
  }
  function beginPeel(index, x, y) {
    if (!patternChosen) {
      startPoint = Qt.point(x, y);
      pattern = Model.patternAtStart(x, y);
      index = Model.hitPeel(pieces, 0, x, y);
      if (index < 0) { pattern = -1; return false; }
    }
    activePeel = index;
    peelAxis = Model.peelAxis(pieces[index], x, y);
    peelProgress = 0;
    return true;
  }
  function finishDrop() {
    if (dropping >= 0) {
      var next = landed.slice();
      next[dropping] = dropFrame;
      landed = next;
    }
    dropping = -1;
    dropFrame = null;
    dropProgress = 0;
  }
  function finishPeel() {
    if (activePeel >= 0 && peelTarget === 1) {
      dropFrame = Model.peelFrame(pieces[activePeel], 1, peelAxis);
      dropping = activePeel;
      dropProgress = 0;
      peeledMask |= 1 << activePeel;
    }
    activePeel = -1;
    peelProgress = 0;
    hovered = -1;
    keyboardIndex = -1;
    // A cancelled first tug leaves the whole rind free to start elsewhere.
    if (peeledMask === 0 && dropping < 0) pattern = -1;
    if (dropping >= 0) {
      if (animationDuration === 0 || !interactive) finishDrop();
      else dropAnimation.restart();
    }
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
    dropAnimation.stop();
    arriveAnimation.stop();
    finishDrop();
    arrival = 1;
    finishEating();
  }
  function reset() {
    renewTimer.stop();
    peelSettle.stop();
    eatAnimation.stop();
    dropAnimation.stop();
    arriveAnimation.stop();
    dropping = -1;
    dropFrame = null;
    dropProgress = 0;
    landed = [];
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
    pattern = -1;
    startPoint = Qt.point(100, 62);
    previewStart = startPoint;
    variant = Model.nextVariant(variant, Math.random());
    arrival = 1;
    if (interactive && animationDuration > 0) { arrival = 0; arriveAnimation.restart(); }
  }
  function available(index) {
    if (!patternChosen) return index >= 0 && index < Model.starts.length;
    return index >= 0 && index < (fullyPeeled ? Model.segments : pieces.length)
      && !((fullyPeeled ? eaten : peeledMask) & (1 << index));
  }
  function moveCursor(direction) {
    if (gesture !== "" || busy) return;
    var total = !patternChosen ? Model.starts.length : fullyPeeled ? Model.segments : pieces.length;
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
    if (!patternChosen) {
      var start = Model.starts[keyboardIndex];
      if (beginPeel(-1, start[0], start[1])) animatePeel(1);
      return;
    }
    if (fullyPeeled) { selected = 1 << keyboardIndex; eatSelection(); }
    else {
      var piece = pieces[keyboardIndex];
      beginPeel(keyboardIndex, piece.cx, piece.cy - 100);
      animatePeel(1);
    }
  }

  onInteractiveChanged: if (!interactive) {
    cancelGesture();
    finishTransition();
    hovered = -1;
  }
  onAnimationDurationChanged: if (animationDuration === 0) finishTransition()

  Timer {
    id: renewTimer
    interval: root.renewDelay
    running: root.interactive && root.remaining === 0 && !root.busy
    onTriggered: root.reset()
  }
  NumberAnimation {
    id: arriveAnimation
    target: root; property: "arrival"; from: 0; to: 1
    duration: Math.min(180, root.animationDuration)
    easing.type: Easing.OutCubic
  }
  NumberAnimation {
    id: dropAnimation
    target: root; property: "dropProgress"; from: 0; to: 1
    duration: Math.min(180, root.animationDuration)
    easing.type: Easing.OutCubic
    onFinished: root.finishDrop()
  }
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
    scale: root.artScale * (0.96 + root.arrival * 0.04)
    opacity: root.arrival
    // Tiny compression acknowledges a tug without moving the fruit's anchor.
    transform: Scale {
      origin.x: 100; origin.y: 110
      xScale: root.gesture === "peel" ? 1.025 : 1
      yScale: root.gesture === "peel" ? 0.98 : 1
      Behavior on xScale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
      Behavior on yScale { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
    }

    // Padding leaves room for curling sheets without rescaling their hit targets.
    Item {
      x: -45; y: -35
      width: 290; height: 270
      layer.enabled: true
      layer.textureSize: Qt.size(186, 174)
      layer.smooth: false
      layer.mipmap: false

      Item {
        x: 45; y: 35
        width: 200; height: 200

        Rectangle {
          x: 48; y: 179; width: 104; height: 10; radius: 52
          color: "#18000000"
          visible: root.remaining > 0 || root.fading !== 0
        }

        Repeater {
          model: root.pieces
          delegate: PeelFlap {
            id: fallen
            required property var modelData
            required property int index
            frame: root.landed[index] || null
            fibreOpacity: 0
            visible: frame !== null
            x: frame ? 55 + (index % 3) * 39 - frame.cx : 0
            y: frame ? 181 + (index % 2) * 5 - frame.cy : 0
            transform: [
              Scale { origin.x: fallen.frame ? fallen.frame.cx : 0; origin.y: fallen.frame ? fallen.frame.cy : 0; xScale: 0.4; yScale: 0.4 },
              Rotation { origin.x: fallen.frame ? fallen.frame.cx : 0; origin.y: fallen.frame ? fallen.frame.cy : 0; angle: fallen.index % 2 ? -12 : 10 }
            ]
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
              strokeColor: "#fbe3ae"; strokeWidth: 2.8
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
            required property var modelData
            required property int index
            visible: !(root.peeledMask & (1 << index))
            ShapePath {
              fillColor: "#f6a548"; strokeColor: "#f6a548"; strokeWidth: 0.8
              joinStyle: ShapePath.RoundJoin
              PathSvg {
                path: root.activePeel === index && root.peelFrame
                  ? root.peelFrame.attached : modelData.path
              }
            }
            ShapePath {
              fillColor: "#d88739"; strokeColor: "transparent"
              PathSvg { path: root.activePeel === index ? "" : modelData.texture.pores }
            }
            ShapePath {
              fillColor: "#ffd28b"; strokeColor: "transparent"
              PathSvg { path: root.activePeel === index ? "" : modelData.texture.lights }
            }
          }
        }

        Shape {
          visible: root.activePeel >= 0
          ShapePath {
            fillColor: "#44fff0ce"; strokeColor: "transparent"
            PathSvg { path: root.peelFrame ? root.peelFrame.exposed : "" }
          }
        }

        Shape {
          visible: root.peeledMask === 0 && root.activePeel < 0
          ShapePath {
            fillColor: "#f6a548"; strokeColor: "#b87438"; strokeWidth: 2.2
            PathSvg { path: root.bodyPath }
          }
          ShapePath {
            fillColor: "#d88739"; strokeColor: "transparent"
            PathSvg { path: root.bodyTexture.pores }
          }
          ShapePath {
            fillColor: "#ffd28b"; strokeColor: "transparent"
            PathSvg { path: root.bodyTexture.lights }
          }
          ShapePath {
            fillColor: "transparent"; strokeColor: "#ffd99a"; strokeWidth: 4.5
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 43 87 Q 47 74 58 69" }
          }
          ShapePath {
            fillColor: "transparent"; strokeColor: "#ffd99a"; strokeWidth: 3
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M 63 67 Q 65 66 67 66" }
          }
        }

        Item {
          visible: root.peeledMask === 0
          opacity: root.activePeel >= 0 ? 1 - root.peelProgress : 1
          Rectangle { x: 82; y: 110; width: 4.5; height: 6; radius: 2; color: "#70462c" }
          Rectangle { x: 113; y: 110; width: 4.5; height: 6; radius: 2; color: "#70462c" }
          Rectangle { x: 83; y: 110; width: 1.5; height: 1.5; color: "#fff0cc" }
          Rectangle { x: 114; y: 110; width: 1.5; height: 1.5; color: "#fff0cc" }
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
            fillColor: "#95b75b"; strokeColor: "#688742"; strokeWidth: 1.8
            PathSvg { path: "M 0 0 C 2 -8 8 -18 21 -21 Q 31 -23 34 -18 C 31 -8 18 2 7 2 Q 2 2 0 0 Z" }
          }
          ShapePath {
            fillColor: "#b9cc75"; strokeColor: "transparent"
            PathSvg { path: "M 8 -6 Q 15 -17 28 -17 Q 20 -15 13 -8 Q 10 -5 8 -6 Z" }
          }
          ShapePath {
            fillColor: "transparent"; strokeColor: "#6f944f"; strokeWidth: 1.2
            PathSvg { path: "M 2 -1 Q 14 -9 26 -15" }
          }
        }

        PeelFlap {
          id: folded
          frame: root.dropping >= 0 ? root.dropFrame : root.peelFrame
          readonly property real fall: root.dropping >= 0 ? root.dropProgress : 0
          fibreOpacity: 1 - fall
          visible: frame !== null
          x: frame && root.dropping >= 0 ? (55 + (root.dropping % 3) * 39 - frame.cx) * fall : 0
          y: frame && root.dropping >= 0 ? (181 + (root.dropping % 2) * 5 - frame.cy) * fall : 0
          transform: [
            Scale { origin.x: folded.frame ? folded.frame.cx : 0; origin.y: folded.frame ? folded.frame.cy : 0; xScale: 1 - folded.fall * 0.6; yScale: xScale },
            Rotation { origin.x: folded.frame ? folded.frame.cx : 0; origin.y: folded.frame ? folded.frame.cy : 0; angle: (root.dropping % 2 ? -12 : 10) * folded.fall }
          ]
        }

        // A tiny raised edge points out the next keyboard-accessible peel.
        Shape {
          readonly property int nextPeel: {
            if (!root.patternChosen || root.fullyPeeled || root.activePeel >= 0) return -1;
            if (root.available(root.keyboardIndex)) return root.keyboardIndex;
            for (var i = 0; i < root.pieces.length; i++) if (root.available(i)) return i;
            return -1;
          }
          readonly property point tabPoint: {
            if (root.patternChosen) return nextPeel >= 0 ? Qt.point(root.pieces[nextPeel].cx, root.pieces[nextPeel].cy) : Qt.point(0, 0);
            if (root.keyboardIndex >= 0) {
              var start = Model.starts[root.keyboardIndex];
              return Qt.point(start[0], start[1]);
            }
            return root.hovered >= 0 ? root.previewStart : Qt.point(100, 62);
          }
          visible: !root.fullyPeeled && root.activePeel < 0 && (nextPeel >= 0 || !root.patternChosen)
          x: tabPoint.x - 5
          y: tabPoint.y - 3
          ShapePath {
            fillColor: "#ffe3aa"; strokeColor: "#b87438"; strokeWidth: 1.1
            PathSvg { path: "M 0 0 Q 5 -6 10 0 Q 5 -1 0 0 Z" }
          }
        }
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
      else {
        var p = root.artPoint(mouse.x, mouse.y);
        if (root.beginPeel(id, p.x, p.y)) root.gesture = "peel";
      }
    }
    onPositionChanged: function(mouse) {
      root.hovered = root.hitAt(mouse.x, mouse.y);
      if (!root.patternChosen && root.hovered >= 0) root.previewStart = root.artPoint(mouse.x, mouse.y);
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
