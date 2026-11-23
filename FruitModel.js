// Flat artwork coordinates. Rind patterns are independent of the eight segments.
var segments = 8;
var all = (1 << segments) - 1;
var tau = Math.PI * 2;

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function count(mask) {
  var n = 0;
  for (var i = 0; i < 16; i++) if (mask & (1 << i)) n++;
  return n;
}
function nextPattern(previous, random) {
  return previous < 0 ? Math.floor(clamp(random, 0, 0.999999) * 3)
    : (previous + 1 + Math.floor(clamp(random, 0, 0.999999) * 2)) % 3;
}
function bodyPoints() {
  var points = [];
  for (var i = 0; i < 96; i++) {
    var a = i * tau / 96;
    var x = 100 + Math.cos(a) * 78;
    var y = 108 + Math.sin(a) * 63;
    // A shallow dimple under the stem softens the circular silhouette.
    if (Math.sin(a) < 0) y += 5 * Math.exp(-Math.pow((x - 100) / 18, 2));
    points.push([x, y]);
  }
  return points;
}
function path(points) {
  if (!points.length) return "";
  function p(point) { return point[0].toFixed(2) + " " + point[1].toFixed(2); }
  var result = "M " + p(points[0]);
  for (var i = 1; i <= points.length; i++) {
    var a = points[i - 1], b = points[i % points.length];
    var dx = b[0] - a[0], dy = b[1] - a[1], length = Math.hypot(dx, dy);
    if (length > 18) {
      // Both sides of a shared tear use the same gently uneven curve.
      var sign = dx > 0 || (dx === 0 && dy > 0) ? 1 : -1;
      var mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
      var bend = Math.sin(mx * 0.23 + my * 0.31) * 1.8 * sign;
      result += " Q " + p([mx + dy / length * bend, my - dx / length * bend]) + " " + p(b);
    } else result += " L " + p(b);
  }
  return result + " Z";
}
function clip(points, a, b, c) {
  var out = [];
  for (var i = 0; i < points.length; i++) {
    var p = points[i], q = points[(i + 1) % points.length];
    var dp = a * p[0] + b * p[1] - c, dq = a * q[0] + b * q[1] - c;
    if (dp <= 0) out.push(p);
    if ((dp <= 0) !== (dq <= 0)) {
      var t = dp / (dp - dq);
      out.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]);
    }
  }
  return out;
}
function peelPieces(pattern, variant) {
  var body = bodyPoints(), polygons = [];
  var lean = variant % 2 ? -0.12 : 0.12;
  if (pattern === 0) {
    // Three broad ribbons, rather than longitudinal fruit-shaped strips.
    var levels = [-1000, 89 + lean * 100, 131 + lean * 100, 1000];
    for (var row = 0; row < 3; row++)
      polygons.push(clip(clip(body, lean, 1, levels[row + 1]), -lean, -1, -levels[row]));
  } else if (pattern === 1) {
    // Four large asymmetric flaps sharing an off-centre tear.
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 2; x++) {
        var sx = x ? -1 : 1, sy = y ? -1 : 1;
        polygons.push(clip(clip(body, sx, sx * 0.24, sx * (121 + variant % 3 * 3)),
          -sy * 0.17, sy, sy * 91));
      }
    }
  } else {
    // Five Voronoi patches make a complete rind with irregular tear boundaries.
    var seeds = [[77, 67], [131, 79], [99, 108], [61, 134], [132, 143]];
    if (variant % 2) seeds = seeds.map(function(p) { return [200 - p[0], p[1]]; });
    for (var i = 0; i < seeds.length; i++) {
      var polygon = body.slice(), s = seeds[i];
      for (var j = 0; j < seeds.length; j++) {
        if (i === j) continue;
        var q = seeds[j];
        polygon = clip(polygon, q[0] - s[0], q[1] - s[1],
          (q[0] * q[0] + q[1] * q[1] - s[0] * s[0] - s[1] * s[1]) / 2);
      }
      polygons.push(polygon);
    }
  }
  return polygons.map(function(points) {
    var cx = 0, cy = 0;
    for (var i = 0; i < points.length; i++) { cx += points[i][0]; cy += points[i][1]; }
    cx /= points.length; cy /= points.length;
    return { points: points, path: path(points), cx: cx, cy: cy,
      side: cx < 100 ? -1 : 1 };
  });
}
function inside(points, x, y) {
  var result = false;
  for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
    var a = points[i], b = points[j];
    if ((a[1] > y) !== (b[1] > y) &&
        x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) result = !result;
  }
  return result;
}
function hitPeel(pieces, removed, x, y) {
  for (var i = pieces.length - 1; i >= 0; i--)
    if (!(removed & (1 << i)) && inside(pieces[i].points, x, y)) return i;
  return -1;
}
function segment(index) {
  var a = -Math.PI / 2 + index * tau / segments + 0.026;
  var b = a + tau / segments - 0.052, mid = (a + b) / 2;
  function p(angle, r) { return (100 + Math.cos(angle) * 74 * r).toFixed(2) + " " + (108 + Math.sin(angle) * 59 * r).toFixed(2); }
  return { dx: Math.cos(mid), dy: Math.sin(mid),
    path: "M " + p(a, 0.11) + " Q " + p(a, 0.56) + " " + p(a, 0.96)
      + " A 74 59 0 0 1 " + p(b, 0.96) + " Q " + p(b, 0.56) + " " + p(b, 0.11)
      + " Q 100 108 " + p(a, 0.11) + " Z",
    fibre: "M " + p(mid, 0.35) + " Q " + p(mid + 0.035, 0.57) + " " + p(mid, 0.8) };
}
function hitSegment(x, y, eaten) {
  for (var i = segments - 1; i >= 0; i--) {
    if (eaten & (1 << i)) continue;
    var s = segment(i);
    var px = (x - 100 - s.dx * 5) / 74, py = (y - 108 - s.dy * 5) / 59;
    var radius = Math.hypot(px, py);
    var angle = (Math.atan2(py, px) + Math.PI / 2 + tau) % tau;
    if (radius >= 0.1 && radius <= 0.99 && Math.floor(angle / (tau / segments)) === i) return i;
  }
  return -1;
}
function sweep(fromX, fromY, toX, toY, eaten, selected) {
  var steps = Math.max(1, Math.ceil(Math.hypot(toX - fromX, toY - fromY) / 3));
  for (var i = 0; i <= steps; i++) {
    var t = i / steps;
    var id = hitSegment(fromX + (toX - fromX) * t, fromY + (toY - fromY) * t, eaten);
    if (id >= 0) selected |= 1 << id;
  }
  return selected;
}
