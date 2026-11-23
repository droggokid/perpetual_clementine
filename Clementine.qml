import QtQuick
import "FruitModel.js" as Model

Item {
  id: root

  property int animationDuration: 0
  property bool interactive: true
  property string accessibleName: ""
  property string accessibleDescription: ""
  property var peel: Model.freshPeel()
  property int eaten: 0
  property int selected: 0
  property int hoveredSegment: -1
  property real yaw: 0.12
  property real pitch: 0.4
  property string gesture: ""
  property int grabbed: -1
  property point origin: Qt.point(0, 0)
  property point previous: Qt.point(0, 0)
  property int fading: 0
  property real fade: 0
  property int settling: -1
  property real settleFrom: 0
  property real settleTo: 0
  property double startedAt: 0
  readonly property bool busy: settling >= 0 || fading !== 0
  readonly property bool fullyPeeled: Model.peeled(peel)
  readonly property int remaining: Model.segments - Model.count(eaten)
  readonly property int peelRemaining: peel.filter(function(p) { return p < 1; }).length
  readonly property real radius: Math.min(width / 3.1, height / 2.8)
  readonly property real centerX: width / 2
  readonly property real centerY: height * 0.46
  readonly property var faces: Model.scene(yaw, pitch, peel, eaten, fading, fade)

  Accessible.role: Accessible.Button
  Accessible.name: accessibleName
  Accessible.description: accessibleDescription
  Accessible.onPressAction: keyboardAction()

  function setPeel(index, amount) {
    var next = peel.slice();
    next[index] = Model.clamp(amount, 0, 1);
    peel = next;
  }

  function normalPoint(x, y) {
    return Qt.point((x - centerX) / radius, (centerY - y) / radius);
  }

  function hitAt(x, y) {
    var p = normalPoint(x, y);
    return Model.hit(faces, p.x, p.y);
  }

  function finishTransition() {
    if (settling >= 0) setPeel(settling, settleTo);
    settling = -1;
    fading = 0;
    fade = 0;
    transition.stop();
  }

  function animatePeel(index, target) {
    settling = index;
    settleFrom = peel[index];
    settleTo = target;
    startedAt = Date.now();
    if (animationDuration === 0) finishTransition();
    else transition.restart();
  }

  function eatSelection() {
    var take = selected & ~eaten;
    selected = 0;
    if (!take) return;
    fading = take;
    eaten |= take;
    fade = 0;
    startedAt = Date.now();
    if (animationDuration === 0) finishTransition();
    else transition.restart();
  }

  function cancelGesture() {
    if (gesture === "peel" && grabbed >= 0) animatePeel(grabbed, 0);
    selected = 0;
    grabbed = -1;
    gesture = "";
  }

  function reset() {
    transition.stop();
    gesture = "";
    grabbed = -1;
    settling = -1;
    fading = 0;
    fade = 0;
    eaten = 0;
    selected = 0;
    hoveredSegment = -1;
    peel = Model.freshPeel();
    yaw = 0.12;
    pitch = 0.4;
  }

  function turn(dx, dy) {
    if (gesture !== "") cancelGesture();
    yaw = (yaw + dx) % Model.tau;
    pitch = Model.clamp(pitch + dy, -1.2, 1.2);
  }

  function keyboardAction() {
    if (!interactive || busy || gesture !== "") return;
    var id = Model.frontmost(faces, !fullyPeeled);
    if (id < 0) return;
    if (!fullyPeeled) animatePeel(id, 1);
    else { selected = 1 << id; eatSelection(); }
  }

  onInteractiveChanged: if (!interactive) {
    cancelGesture();
    finishTransition();
    hoveredSegment = -1;
  }
  onAnimationDurationChanged: if (animationDuration === 0) finishTransition()
  onFacesChanged: canvas.requestPaint()
  onSelectedChanged: canvas.requestPaint()
  onHoveredSegmentChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Timer {
    id: transition
    interval: 16
    repeat: true
    onTriggered: {
      var t = Math.min(1, (Date.now() - root.startedAt) / Math.max(1, root.animationDuration));
      var eased = 1 - Math.pow(1 - t, 3);
      if (root.settling >= 0) root.setPeel(root.settling, root.settleFrom + (root.settleTo - root.settleFrom) * eased);
      if (root.fading) root.fade = eased;
      if (t >= 1) root.finishTransition();
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      var r = root.radius;
      var cx = root.centerX, cy = root.centerY;
      if (root.remaining > 0 || root.fading) {
        ctx.save();
        ctx.translate(cx, cy + r * 1.02);
        ctx.scale(1, 0.16);
        var shadow = ctx.createRadialGradient(0, 0, 0, 0, 0, r * 0.95);
        shadow.addColorStop(0, "#38000000");
        shadow.addColorStop(1, "transparent");
        ctx.fillStyle = shadow;
        ctx.beginPath();
        ctx.arc(0, 0, r * 0.95, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }
      for (var i = 0; i < root.faces.length; i++) {
        var face = root.faces[i];
        var points = face.points;
        ctx.globalAlpha = face.alpha;
        ctx.beginPath();
        for (var j = 0; j < points.length; j++) {
          var x = cx + points[j][0] * r;
          var y = cy - points[j][1] * r;
          if (j === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.fillStyle = face.color;
        ctx.strokeStyle = face.color;
        ctx.lineWidth = 0.65;
        ctx.fill();
        ctx.stroke();
        if (face.kind !== "leaf") {
          var picked = (root.selected & (1 << face.id)) !== 0;
          if (picked || root.hoveredSegment === face.id) {
            ctx.fillStyle = picked ? "#80fff2ca" : "#18fff2ca";
            ctx.fill();
          }
          var px = 0, py = 0;
          for (var p = 0; p < points.length; p++) { px += points[p][0]; py += points[p][1]; }
          px = cx + px / points.length * r;
          py = cy - py / points.length * r;
          // Stable, surface-bound pores and juice fibres; no random repaint flicker.
          ctx.fillStyle = face.grain > 0 ? "#35fff1b0" : "#18933b0b";
          if (face.kind === "peel") {
            ctx.beginPath();
            ctx.arc(px, py, Math.max(0.35, r * 0.004), 0, Math.PI * 2);
            ctx.fill();
          } else {
            ctx.fillRect(px, py, Math.max(0.4, r * 0.003), r * 0.018);
          }
        }
      }
      ctx.globalAlpha = 1;
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    preventStealing: true
    cursorShape: root.gesture === "rotate" ? Qt.ClosedHandCursor
      : root.hoveredSegment >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor
    onExited: if (root.gesture === "") root.hoveredSegment = -1
    onCanceled: root.cancelGesture()
    onPressed: function(mouse) {
      if (root.busy) return;
      root.origin = Qt.point(mouse.x, mouse.y);
      root.previous = root.origin;
      var face = root.hitAt(mouse.x, mouse.y);
      if (mouse.button !== Qt.LeftButton || !face) root.gesture = "rotate";
      else if (!root.fullyPeeled && (face.kind === "peel" || face.kind === "leaf")) {
        root.gesture = "peel";
        root.grabbed = face.id;
      } else if (root.fullyPeeled) {
        root.gesture = "eat";
        root.selected = 1 << face.id;
      }
    }
    onPositionChanged: function(mouse) {
      var face = root.hitAt(mouse.x, mouse.y);
      root.hoveredSegment = face ? face.id : -1;
      if (root.gesture === "rotate") {
        root.yaw = (root.yaw + (mouse.x - root.previous.x) * 0.009) % Model.tau;
        root.pitch = Model.clamp(root.pitch + (mouse.y - root.previous.y) * 0.007, -1.2, 1.2);
      } else if (root.gesture === "peel") {
        var distance = Math.hypot(mouse.x - root.origin.x, mouse.y - root.origin.y);
        root.setPeel(root.grabbed, Math.min(0.96, distance / (root.radius * 0.9)));
      } else if (root.gesture === "eat") {
        var a = root.normalPoint(root.previous.x, root.previous.y);
        var b = root.normalPoint(mouse.x, mouse.y);
        root.selected = Model.sweep(root.faces, a.x, a.y, b.x, b.y, root.selected);
      }
      root.previous = Qt.point(mouse.x, mouse.y);
    }
    onReleased: function(mouse) {
      if (root.gesture === "peel") root.animatePeel(root.grabbed, root.peel[root.grabbed] >= 0.55 ? 1 : 0);
      else if (root.gesture === "eat") {
        var a = root.normalPoint(root.previous.x, root.previous.y);
        var b = root.normalPoint(mouse.x, mouse.y);
        root.selected = Model.sweep(root.faces, a.x, a.y, b.x, b.y, root.selected);
        root.eatSelection();
      }
      root.gesture = "";
      root.grabbed = -1;
    }
  }
}
