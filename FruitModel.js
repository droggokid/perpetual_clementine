// Orthographic geometry shared by painting and picking. Positive z faces you.
var segments = 10;
var all = (1 << segments) - 1;
var tau = Math.PI * 2;

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }

function count(mask) {
  var result = 0;
  for (var i = 0; i < segments; i++) if (mask & (1 << i)) result++;
  return result;
}

function freshPeel() {
  var result = [];
  for (var i = 0; i < segments; i++) result.push(0);
  return result;
}

function peeled(peel) {
  return peel.every(function(value) { return value >= 1; });
}

function rotate(point, yaw, pitch) {
  var x = point[0] * Math.cos(yaw) + point[2] * Math.sin(yaw);
  var z = point[2] * Math.cos(yaw) - point[0] * Math.sin(yaw);
  return [x, point[1] * Math.cos(pitch) - z * Math.sin(pitch),
    point[1] * Math.sin(pitch) + z * Math.cos(pitch)];
}

function surface(angle, latitude, radius) {
  var r = Math.cos(latitude) * radius;
  return [Math.sin(angle) * r, Math.sin(latitude) * 0.84 * radius,
    Math.cos(angle) * r];
}

function peelPoint(angle, latitude, amount) {
  var top = latitude / Math.PI + 0.5;
  var bend = amount * (0.2 + 0.8 * top);
  var radius = 1.025 + Math.sin(bend * Math.PI * 0.8) * 0.9;
  var point = surface(angle, latitude, radius);
  // The tip rolls outward first while the lower end stays near the fruit.
  point[1] = Math.sin(latitude) * 0.86 - amount * (0.35 + 1.45 * top);
  return point;
}

function tint(base, light) {
  return "rgb(" + base.map(function(c) {
    return Math.round(clamp(c * light, 0, 255));
  }).join(",") + ")";
}

function scene(yaw, pitch, peel, eaten, fading, fade) {
  var faces = [];

  function add(points, normal, id, kind, base, grain, alpha) {
    var bit = 1 << id;
    var disappearing = kind !== "peel" && (fading & bit);
    var turned = points.map(function(point) {
      if (disappearing) {
        point = [point[0] * (1 - fade * 0.16),
          point[1] * (1 - fade * 0.16) + fade * 0.25, point[2]];
      }
      return rotate(point, yaw, pitch);
    });
    var n = rotate(normal, yaw, pitch);
    // Back faces cannot be picked through a gap in the remaining fruit.
    if (n[2] < -0.02) return;
    var light = 0.68 + Math.max(0, -n[0] * 0.36 + n[1] * 0.48 + n[2] * 0.7) * 0.34;
    var z = turned.reduce(function(sum, p) { return sum + p[2]; }, 0) / turned.length;
    faces.push({ points: turned, z: z, id: id, kind: kind,
      color: tint(base, light + grain), grain: grain,
      alpha: alpha * (disappearing ? 1 - fade : 1) });
  }

  for (var id = 0; id < segments; id++) {
    var bit = 1 << id;
    if ((eaten & bit) && !(fading & bit)) continue;
    var start = id * tau / segments;
    var end = (id + 1) * tau / segments;
    var middle = (start + end) / 2;
    var amount = peel[id];
    for (var row = 0; row < 16; row++) {
      var low = -Math.PI / 2 + row * Math.PI / 16;
      var high = low + Math.PI / 16;
      var lat = (low + high) / 2;
      for (var col = 0; col < 6; col++) {
        var a = start + 0.012 + col * (end - start - 0.024) / 6;
        var b = start + 0.012 + (col + 1) * (end - start - 0.024) / 6;
        var angle = (a + b) / 2;
        var normal = [Math.sin(angle) * Math.cos(lat), Math.sin(lat), Math.cos(angle) * Math.cos(lat)];
        var grain = Math.sin(row * 43 + col * 17 + id * 71) * 0.025;
        var radius = 0.965 + Math.sin((angle - start) / (end - start) * Math.PI) * 0.018;
        add([surface(a, low, radius), surface(b, low, radius),
          surface(b, high, radius), surface(a, high, radius)],
          normal, id, "flesh", [255, 166, 64], grain, 1);
        if (amount < 1) {
          // Finer seams on the rind than between the exposed segments.
          var pa = start + 0.002 + col * (end - start - 0.004) / 6;
          var pb = start + 0.002 + (col + 1) * (end - start - 0.004) / 6;
          add([peelPoint(pa, low, amount), peelPoint(pb, low, amount),
            peelPoint(pb, high, amount), peelPoint(pa, high, amount)],
            normal, id, "peel", [246, 119, 24], grain, Math.min(1, (1 - amount) * 4));
        }
      }
      // Membranes close the wedge, so eating a segment exposes its neighbours.
      for (var side = 0; side < 2; side++) {
        var edge = side === 0 ? start + 0.012 : end - 0.012;
        var sign = side === 0 ? -1 : 1;
        add([[0, Math.sin(low) * 0.81, 0], surface(edge, low, 0.965),
          surface(edge, high, 0.965), [0, Math.sin(high) * 0.81, 0]],
          [Math.cos(edge) * sign, 0, -Math.sin(edge) * sign],
          id, "membrane", [255, 214, 151], Math.sin(row * 13) * 0.018, 1);
      }
    }
  }

  if (peel[0] < 0.05 && eaten === 0) {
    // A small calyx and leaf make the silhouette read as citrus at a glance.
    for (var leaf = 0; leaf < 5; leaf++) {
      var angle = leaf * tau / 5;
      add([[0, 0.87, 0], [Math.sin(angle) * 0.13, 0.85, Math.cos(angle) * 0.13],
        [Math.sin(angle + 0.45) * 0.06, 0.88, Math.cos(angle + 0.45) * 0.06]],
        [0, 1, 0], 0, "leaf", [81, 112, 40], 0, 1);
    }
    add([[0.01, 0.88, 0], [0.17, 1.03, 0.06], [0.43, 1.01, 0.02],
      [0.25, 0.89, -0.04]], [0, 0.8, 0.6], 0, "leaf", [89, 137, 53], 0, 1);
  }

  faces.sort(function(a, b) { return a.z - b.z; });
  return faces;
}

function inside(points, x, y) {
  var result = false;
  for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    var a = points[i], b = points[j];
    if (((a[1] > y) !== (b[1] > y)) &&
        x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) result = !result;
  }
  return result;
}

function hit(faces, x, y) {
  for (var i = faces.length - 1; i >= 0; i--) {
    var face = faces[i];
    if (face.alpha > 0.05 && inside(face.points, x, y)) return face;
  }
  return null;
}

function frontmost(faces, peelOnly) {
  for (var i = faces.length - 1; i >= 0; i--) {
    if (peelOnly ? faces[i].kind === "peel" : faces[i].kind !== "peel") return faces[i].id;
  }
  return -1;
}

function sweep(faces, fromX, fromY, toX, toY, selected) {
  // Interpolate sparse mouse events so a quick sweep cannot skip a segment.
  var steps = Math.max(1, Math.ceil(Math.hypot(toX - fromX, toY - fromY) / 0.035));
  for (var i = 0; i <= steps; i++) {
    var t = i / steps;
    var face = hit(faces, fromX + (toX - fromX) * t, fromY + (toY - fromY) * t);
    if (face && face.kind !== "peel") selected |= 1 << face.id;
  }
  return selected;
}
