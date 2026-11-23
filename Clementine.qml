import QtQuick
import QtQuick.Shapes
import "FruitModel.js" as Model

Item {
  id: root

  signal fruitEaten()

  property int animationDuration: 0
  property int renewDelay: 1400
  property real arrival: 1
  property var peelAxis: null
  property int dropping: -1
  property real dropProgress: 0
  property point dropDirection: Qt.point(0, 0)
  property var dropFrame: null
  property var landed: []
  property bool interactive: true
  property string accessibleName: ""
  property string accessibleDescription: ""
  property int pattern: -1
  property int variant: Model.nextVariant(-1, Math.random())
  property point startPoint: Qt.point(100, 62)
  property int peeledMask: 0
  property int activePeel: -1
  property point peelGrab: Qt.point(0, 0)
  property var pullPose: ({ amount: 0, distance: 0, x: 0, y: 0, ready: false })
  property real settleProgress: 0
  readonly property real peelProgress: gesture === "peel" ? pullPose.amount : settleProgress
  property real peelTarget: 0
  property int eaten: 0
  property int selected: 0
  property int fading: 0
  property real fade: 0
  property int hovered: -1
  property int keyboardIndex: -1
  readonly property var keyboardStarts: [[100, 62], [36, 108], [46, 134],
    [100, 153], [154, 134], [164, 108], [100, 108]]
  readonly property var fruitStyle: Model.fruits[variant]
  property string gesture: ""
  property point origin: Qt.point(0, 0)
  property point previous: Qt.point(0, 0)
  readonly property bool patternChosen: pattern >= 0
  readonly property var pieces: patternChosen ? Model.peelPieces(pattern, variant, startPoint.x, startPoint.y) : []
  readonly property bool fullyPeeled: patternChosen && peeledMask === (1 << pieces.length) - 1
  readonly property string corePath: fullyPeeled ? Model.remainingCorePath(variant, eaten) : ""
  readonly property int remaining: Model.segments - Model.count(eaten)
  readonly property int peelRemaining: pieces.length - Model.count(peeledMask)
  readonly property bool inputBlocked: peelSettle.running || eatAnimation.running || arriveAnimation.running
  readonly property bool busy: inputBlocked || dropAnimation.running
  readonly property var peelFrame: {
    if (activePeel < 0 || !peelAxis) return null;
    var pose = pullPose;
    var amount = gesture === "peel" ? pose.amount : settleProgress;
    return amount > 0 ? Model.peelFrame(pieces[activePeel], amount, peelAxis, pose) : null;
  }
  readonly property real artScale: Math.max(0.1, Math.min(1, width / 220, height / 250))
  readonly property real centerX: width / 2
  readonly property real centerY: height / 2 - 14 * artScale
  readonly property var bodyOutline: Model.bodyPoints(variant)
  readonly property string bodyPath: Model.path(bodyOutline)
  readonly property var bodyTexture: Model.rindTexture(bodyOutline)
  readonly property string bodyShine: Model.rindDetails(bodyOutline, []).shinePath
  readonly property bool showingWhole: peeledMask === 0 && peelProgress === 0
  readonly property int crownPiece: patternChosen ? Model.hitPeel(pieces, 0, 100, 56) : -1

  component RindSurface: ShapePath {
    fillGradient: RadialGradient {
      centerX: 76; centerY: 84; focalX: 76; focalY: 84
      centerRadius: 103
      GradientStop { position: 0.0; color: Qt.lighter(root.fruitStyle.skin, 1.13) }
      GradientStop { position: 0.48; color: Qt.lighter(root.fruitStyle.skin, 1.10) }
      GradientStop { position: 0.51; color: root.fruitStyle.skin }
      GradientStop { position: 0.83; color: root.fruitStyle.skin }
      GradientStop { position: 0.86; color: Qt.darker(root.fruitStyle.skin, 1.10) }
      GradientStop { position: 1.0; color: Qt.darker(root.fruitStyle.skin, 1.15) }
    }
  }

  component FleshSurface: ShapePath {
    id: surface
    property bool highlighted: false
    property real offsetX: 0
    property real offsetY: 0
    fillGradient: LinearGradient {
      x1: 56 - surface.offsetX; y1: 55 - surface.offsetY
      x2: 123 - surface.offsetX; y2: 165 - surface.offsetY
      GradientStop { position: 0; color: surface.highlighted ? "#ffda97" : "#ffd28b" }
      GradientStop { position: 0.58; color: surface.highlighted ? "#ffc06d" : "#f9af57" }
      GradientStop { position: 1; color: surface.highlighted ? "#efa04f" : "#e99240" }
    }
  }

  Accessible.role: Accessible.Button
  Accessible.name: accessibleName
  Accessible.description: accessibleDescription
  Accessible.onPressAction: keyboardAction()

  function artPoint(x, y) {
    return Qt.point((x - centerX) / (artScale * fruitStyle.width) + 100, (y - centerY) / (artScale * fruitStyle.height) + 100);
  }
  function hitAt(x, y) {
    var p = art.mapFromItem(root, x, y);
    if (!patternChosen) return Model.inside(bodyOutline, p.x, p.y) ? 0 : -1;
    return fullyPeeled ? Model.hitSegment(p.x, p.y, eaten, variant)
      : Model.hitPeel(pieces, peeledMask, p.x, p.y);
  }
  function extendSelection(x, y) {
    if (x === previous.x && y === previous.y) return;
    var a = art.mapFromItem(root, previous.x, previous.y);
    var b = art.mapFromItem(root, x, y);
    selected = Model.sweep(a.x, a.y, b.x, b.y, eaten, selected, variant);
  }
  function beginPeel(index, x, y) {
    if (!patternChosen) {
      startPoint = Qt.point(x, y);
      pattern = Model.patternAtStart(x, y);
      index = Model.hitPeel(pieces, 0, x, y);
      if (index < 0) { pattern = -1; return false; }
    }
    peelGrab = Qt.point(x, y);
    pullPose = { amount: 0, distance: 0, x: 0, y: 0, ready: false };
    peelAxis = null;
    peelTarget = 0;
    settleProgress = 0;
    activePeel = index;
    return true;
  }
  function updatePull(x, y) {
    var start = artPoint(origin.x, origin.y);
    var current = artPoint(x, y);
    var dx = current.x - start.x, dy = current.y - start.y;
    var distance = Math.hypot(dx, dy);
    if (distance <= 4) {
      peelAxis = null;
      pullPose = { amount: 0, distance: 0, x: 0, y: 0, ready: false };
      return;
    }
    if (!peelAxis && distance < 6) return;
    var xDirection = dx / distance, yDirection = dy / distance;
    // The tear stays on the same seam. The free end can turn with the mouse.
    if (!peelAxis)
      peelAxis = Model.peelAxis(pieces[activePeel], peelGrab.x, peelGrab.y, xDirection, yDirection);
    pullPose = Model.pullPose(peelAxis, distance, xDirection, yDirection);
  }
  function refreshHover() {
    hovered = interactive && pointer.containsMouse && gesture === ""
      ? hitAt(pointer.mouseX, pointer.mouseY) : -1;
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
    var detached = activePeel >= 0 && peelTarget === 1;
    if (detached) {
      var frame = settleProgress === 1 ? peelFrame
        : Model.peelFrame(pieces[activePeel], 1, peelAxis, pullPose);
      if (dropping >= 0) {
        dropAnimation.stop();
        finishDrop();
      }
      dropFrame = frame;
      dropDirection = Qt.point(pullPose.x, pullPose.y);
      dropping = activePeel;
      dropProgress = 0;
      peeledMask |= 1 << activePeel;
    }
    activePeel = -1;
    peelAxis = null;
    settleProgress = 0;
    // A cancelled first tug leaves the whole rind free to start elsewhere.
    if (peeledMask === 0 && dropping < 0) pattern = -1;
    refreshHover();
    if (detached) {
      if (animationDuration === 0 || !interactive) finishDrop();
      else dropAnimation.restart();
    }
  }
  function animatePeel(target) {
    if (activePeel < 0) return;
    settleProgress = peelProgress;
    gesture = "";
    peelTarget = target;
    if (animationDuration === 0 || settleProgress === target) {
      settleProgress = target;
      finishPeel();
    } else {
      peelSettle.from = settleProgress;
      peelSettle.to = target;
      peelSettle.duration = Math.round(animationDuration * (target === 1 ? 0.34 : 0.25 + 0.4 * settleProgress));
      peelSettle.restart();
    }
  }
  function finishEating() { fading = 0; fade = 0; refreshHover(); }
  function eatSelection() {
    var take = selected & ~eaten;
    selected = 0;
    if (!take) return;
    fading = take;
    eaten |= take;
    if (remaining === 0) fruitEaten();
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
    peelAxis = null;
    settleProgress = 0;
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
    variant = Model.nextVariant(variant, Math.random());
    arrival = 1;
    if (interactive && animationDuration > 0) { arrival = 0; arriveAnimation.restart(); }
  }
  function moveCursor(direction) {
    if (!interactive || inputBlocked || gesture !== "") return;
    var total = !patternChosen ? keyboardStarts.length : fullyPeeled ? Model.segments : pieces.length;
    var index = keyboardIndex >= 0 ? keyboardIndex : (direction > 0 ? -1 : 0);
    for (var step = 0; step < total; step++) {
      index = (index + direction + total) % total;
      if (fullyPeeled) {
        if (eaten & (1 << index)) continue;
        if (index < 4 && !(eaten & (1 << (index + 4)))) continue;
      } else if (peeledMask & (1 << index)) continue;
      keyboardIndex = index;
      return;
    }
  }
  function keyboardAction() {
    if (!interactive || inputBlocked || gesture !== "") return;
    if (keyboardIndex < 0) moveCursor(1);
    var index = keyboardIndex;
    if (index < 0) return;
    keyboardIndex = -1;
    if (fullyPeeled) {
      selected = 1 << index;
      eatSelection();
      return;
    }
    var start = patternChosen ? [pieces[index].cx, pieces[index].cy] : keyboardStarts[index];
    if (!beginPeel(index, start[0], start[1])) return;
    peelAxis = Model.peelAxis(pieces[activePeel], peelGrab.x, peelGrab.y);
    pullPose = Model.pullPose(peelAxis, 60, -peelAxis.ux, -peelAxis.uy);
    animatePeel(1);
  }
  onInteractiveChanged: if (!interactive) {
    cancelGesture();
    finishTransition();
    hovered = -1;
    keyboardIndex = -1;
  }
  onAnimationDurationChanged: if (animationDuration === 0 && gesture !== "peel") finishTransition()

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
    duration: Math.min(155, root.animationDuration)
    easing.type: Easing.OutCubic
    onFinished: root.finishDrop()
  }
  NumberAnimation {
    id: peelSettle
    target: root; property: "settleProgress"
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
      origin.x: 100; origin.y: 100
      xScale: root.fruitStyle.width * (root.gesture === "peel" ? 1.025 : 1)
      yScale: root.fruitStyle.height * (root.gesture === "peel" ? 0.98 : 1)
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
          x: 49; y: root.fullyPeeled ? 161 : 171; width: 102; height: 8; radius: 51
          color: "#18000000"
          visible: root.remaining > 0 || root.fading !== 0
        }

        Repeater {
          model: root.pieces.length
          delegate: PeelFlap {
            id: fallen
            required property int index
            frame: root.landed[index] || null
            rindColor: root.fruitStyle.skin
            fibreOpacity: 0
            visible: frame !== null
            readonly property var pose: Model.pilePose(index)
            x: frame ? pose[0] - frame.cx : 0
            y: frame ? pose[1] - frame.cy : 0
            transform: [
              Scale { origin.x: fallen.frame ? fallen.frame.cx : 0; origin.y: fallen.frame ? fallen.frame.cy : 0; xScale: 0.51; yScale: 0.39 },
              Rotation { origin.x: fallen.frame ? fallen.frame.cx : 0; origin.y: fallen.frame ? fallen.frame.cy : 0; angle: fallen.pose[2] }
            ]
          }
        }

        Shape {
          visible: !root.fullyPeeled && !root.showingWhole
          ShapePath {
            fillColor: "#f7dba5"; strokeColor: "transparent"
            PathSvg { path: root.bodyPath }
          }
        }

        Shape {
          visible: root.corePath !== ""
          FleshSurface {
            strokeColor: "transparent"
            PathSvg { path: root.corePath }
          }
        }

        Repeater {
          model: Model.segments
          delegate: Shape {
            id: segmentArt
            required property int index
            readonly property var piece: Model.lobes[root.variant][index]
            readonly property bool picked: (root.selected & (1 << index)) !== 0
            readonly property bool keyboardTarget: root.fullyPeeled && root.keyboardIndex === index
            readonly property bool leaving: (root.fading & (1 << index)) !== 0
            readonly property bool front: index >= 4
            readonly property int column: index % 4
            readonly property bool uncovered: !front && (root.eaten & (1 << (index + 4))) !== 0
            readonly property bool edgeLeft: uncovered || (column > 0 && (root.eaten & (1 << (index - 1))) !== 0)
            readonly property bool edgeRight: uncovered || (column < 3 && (root.eaten & (1 << (index + 1))) !== 0)
            visible: !root.showingWhole && (!(root.eaten & (1 << index)) || leaving)
            x: root.fullyPeeled ? piece.dx : 0
            y: (root.fullyPeeled ? piece.dy : 0) - (leaving ? root.fade * 13 : 0)
            opacity: leaving ? 1 - root.fade : 1
            transform: Scale {
              origin.x: 100; origin.y: 108
              xScale: segmentArt.leaving ? 1 - root.fade * 0.2 : 1
              yScale: xScale
            }
            FleshSurface {
              highlighted: segmentArt.picked || segmentArt.keyboardTarget
                || (root.keyboardIndex < 0 && root.hovered === segmentArt.index)
              offsetX: segmentArt.x
              offsetY: segmentArt.y
              strokeColor: segmentArt.picked || segmentArt.keyboardTarget ? "#ffd776" : "#35b4672d"
              strokeWidth: segmentArt.picked || segmentArt.keyboardTarget ? 2 : 0.8
              joinStyle: ShapePath.RoundJoin
              PathSvg { path: segmentArt.piece.path }
            }
            ShapePath {
              fillColor: "#58ffe6b4"
              strokeColor: "transparent"
              PathSvg { path: segmentArt.piece.pulp }
            }
            ShapePath {
              fillColor: "#96c2773c"; strokeColor: "transparent"
              PathSvg { path: segmentArt.edgeLeft ? segmentArt.piece.membraneLeft : "" }
            }
            ShapePath {
              fillColor: "#9dffe3af"; strokeColor: "transparent"
              PathSvg { path: segmentArt.edgeRight ? segmentArt.piece.membraneRight : "" }
            }
          }
        }

        Repeater {
          model: root.pieces
          delegate: Shape {
            required property var modelData
            required property int index
            readonly property var movingFrame: root.activePeel === index ? root.peelFrame : null
            visible: !root.showingWhole && !(root.peeledMask & (1 << index))
            RindSurface {
              strokeColor: root.keyboardIndex === index ? "#fff5d3" : root.fruitStyle.skin
              strokeWidth: root.keyboardIndex === index ? 2 : 0.7
              joinStyle: ShapePath.RoundJoin
              PathSvg {
                path: movingFrame ? movingFrame.attached : modelData.path
              }
            }
            ShapePath {
              fillColor: "#d88739"; strokeColor: "transparent"
              PathSvg { path: movingFrame ? movingFrame.pores : modelData.texture.pores }
            }
            ShapePath {
              fillColor: "#ffd28b"; strokeColor: "transparent"
              PathSvg { path: movingFrame ? movingFrame.lights : modelData.texture.lights }
            }
            ShapePath {
              fillColor: "transparent"; strokeColor: "#b96a30"; strokeWidth: 1.7
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              PathSvg { path: movingFrame ? movingFrame.rindRim : modelData.details.rimPath }
            }
            ShapePath {
              fillColor: "transparent"; strokeColor: "#ffd99a"; strokeWidth: 3.6
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              PathSvg { path: movingFrame ? movingFrame.rindShine : modelData.details.shinePath }
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
          visible: root.showingWhole
          RindSurface {
            strokeColor: "#b96a30"; strokeWidth: 1.7
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
            fillColor: "transparent"; strokeColor: "#ffd99a"; strokeWidth: 3.6
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.bodyShine }
          }
        }

        Shape {
          x: 100; y: 49
          visible: root.crownPiece < 0 ? root.peeledMask === 0 : !(root.peeledMask & (1 << root.crownPiece))
          opacity: root.activePeel >= 0 && root.activePeel === root.crownPiece ? 1 - root.peelProgress : 1
          transform: Scale { xScale: root.fruitStyle.leafX; yScale: root.fruitStyle.leafY }
          rotation: root.fruitStyle.tilt + (root.activePeel >= 0 && root.activePeel === root.crownPiece
            ? -root.peelProgress * 24 : 0)
          Behavior on rotation { NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
          ShapePath {
            fillColor: "#737a3e"; strokeColor: "transparent"
            PathSvg { path: "M -12 2 Q -9 -1 -4 -1 Q -7 -5 -5 -6 L -1 -3 Q -2 -9 1 -11 Q 4 -11 4 -8 L 3 -3 Q 10 -5 12 -2 L 6 0 Q 9 2 9 4 Q 3 3 0 2 Q -6 5 -12 2 Z" }
          }
          ShapePath {
            fillColor: root.variant === 0 ? "#6f9451" : "transparent"
            strokeColor: "transparent"
            PathSvg { path: "M 2 0 C -5 -1 -14 -8 -17 -18 C -7 -20 0 -10 2 0 Z" }
          }
          ShapePath {
            fillColor: root.fruitStyle.leafColor; strokeColor: "#688742"; strokeWidth: 1.8
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

        Rectangle {
          visible: !root.patternChosen && root.keyboardIndex >= 0
          readonly property var start: visible ? root.keyboardStarts[root.keyboardIndex] : [0, 0]
          x: start[0] - width / 2
          y: start[1] - height / 2
          width: 11; height: 11; radius: width / 2
          color: "transparent"
          border.color: "#fff5d3"; border.width: 2
        }

        PeelFlap {
          id: falling
          frame: root.dropFrame
          readonly property real fall: root.dropProgress
          readonly property real flick: 4 * fall * (1 - fall)
          readonly property var pose: Model.pilePose(Math.max(0, root.dropping))
          rindColor: root.fruitStyle.skin
          fibreOpacity: 0
          visible: frame !== null
          x: frame ? (pose[0] - frame.cx) * fall * fall + root.dropDirection.x * 12 * flick : 0
          y: frame ? (pose[1] - frame.cy) * fall * fall + (root.dropDirection.y * 8 - 7) * flick : 0
          transform: [
            Scale { origin.x: falling.frame ? falling.frame.cx : 0; origin.y: falling.frame ? falling.frame.cy : 0; xScale: 1 - falling.fall * 0.49; yScale: 1 - falling.fall * 0.61 },
            Rotation { origin.x: falling.frame ? falling.frame.cx : 0; origin.y: falling.frame ? falling.frame.cy : 0; angle: falling.pose[2] * falling.fall }
          ]
        }

        PeelFlap {
          frame: root.peelProgress > 0 ? root.peelFrame : null
          visible: frame !== null
          rindColor: root.fruitStyle.skin
        }
      }
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    enabled: root.interactive
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    preventStealing: true
    cursorShape: root.gesture !== "" ? Qt.ClosedHandCursor
      : root.hovered >= 0 ? (root.fullyPeeled ? Qt.PointingHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
    onExited: root.hovered = -1
    onCanceled: root.cancelGesture()
    onPressed: function(mouse) {
      if (root.inputBlocked || root.gesture !== "") return;
      var id = root.hitAt(mouse.x, mouse.y);
      if (id < 0) return;
      root.keyboardIndex = -1;
      root.origin = Qt.point(mouse.x, mouse.y);
      root.previous = root.origin;
      if (root.fullyPeeled) { root.gesture = "eat"; root.selected = 1 << id; }
      else {
        var p = art.mapFromItem(root, mouse.x, mouse.y);
        if (root.beginPeel(id, p.x, p.y)) root.gesture = "peel";
      }
    }
    onPositionChanged: function(mouse) {
      if (root.gesture === "peel") {
        root.updatePull(mouse.x, mouse.y);
      } else if (root.gesture === "eat") {
        root.extendSelection(mouse.x, mouse.y);
      } else {
        root.keyboardIndex = -1;
        root.hovered = root.hitAt(mouse.x, mouse.y);
      }
      root.previous = Qt.point(mouse.x, mouse.y);
    }
    onReleased: function(mouse) {
      if (root.gesture === "peel") {
        root.updatePull(mouse.x, mouse.y);
        root.animatePeel(root.pullPose.ready ? 1 : 0);
      } else if (root.gesture === "eat") {
        root.extendSelection(mouse.x, mouse.y);
        root.eatSelection();
      }
      root.gesture = "";
      root.refreshHover();
    }
  }
}
