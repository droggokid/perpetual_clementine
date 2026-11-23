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
var starts = [[100, 62], [36, 108], [164, 108], [100, 153], [100, 108]];
function patternAtStart(x, y) {
  if (y < 83) return 1; // Open the crown in broad flaps.
  if (x < 68 || x > 132) return 0; // Pull a ribbon from either side.
  return 2; // A lower or central start makes smaller torn patches.
}
function nextVariant(previous, random) {
  return previous < 0 ? Math.floor(clamp(random, 0, 0.999999) * 6)
    : (previous + 1 + Math.floor(clamp(random, 0, 0.999999) * 5)) % 6;
}
function bodyPoints() {
  var points = [];
  for (var i = 0; i < 96; i++) {
    var a = i * tau / 96;
    var x = 100 + Math.cos(a) * (78 + Math.sin(a * 3) * 1.2);
    var y = 108 + Math.sin(a) * 63 + Math.sin(a * 3) * 1.1;
    // A shallow dimple under the stem softens the circular silhouette.
    if (Math.sin(a) < 0) y += 5 * Math.exp(-Math.pow((x - 100) / 18, 2));
    points.push([x, y]);
  }
  return points;
}
function curvedEdges(points) {
  var out = [];
  for (var i = 0; i < points.length; i++) {
    var a = points[i], b = points[(i + 1) % points.length];
    var dx = b[0] - a[0], dy = b[1] - a[1], length = Math.hypot(dx, dy);
    if (length < 0.01) continue;
    var steps = length > 14 ? Math.ceil(length / 8) : 1;
    var sign = dx > 0 || (dx === 0 && dy > 0) ? 1 : -1;
    var phase = (a[0] + b[0]) * 0.115 + (a[1] + b[1]) * 0.155;
    for (var j = 0; j < steps; j++) {
      var t = j / steps, u = sign > 0 ? t : 1 - t;
      // The same tear curves match when traversed from either neighbouring piece.
      var wave = (Math.sin(phase) * 2.8 + Math.sin(u * Math.PI * 3) * 0.9)
        * Math.sin(t * Math.PI);
      out.push([a[0] + dx * t + dy / length * sign * wave,
        a[1] + dy * t - dx / length * sign * wave]);
    }
  }
  return out;
}
function softenSheet(points, radius) {
  return points.map(function(point, index) {
    var x = point[0], y = point[1], weight = 1;
    for (var direction = -1; direction <= 1; direction += 2) {
      var distance = 0, previous = point;
      for (var step = 1; step < Math.min(points.length, 12); step++) {
        var p = points[(index + direction * step + points.length) % points.length];
        distance += Math.hypot(p[0] - previous[0], p[1] - previous[1]);
        if (distance > radius * 2) break;
        var w = Math.exp(-distance * distance / (radius * radius * 2));
        x += p[0] * w; y += p[1] * w; weight += w;
        previous = p;
      }
    }
    return [x / weight, y / weight];
  });
}
function path(points, rounding) {
  var curve = curvedEdges(points);
  if (rounding > 0) curve = softenSheet(curve, rounding);
  if (curve.length < 3) return "";
  function p(point) { return point[0].toFixed(2) + " " + point[1].toFixed(2); }
  function mid(a, b) { return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]; }
  var result = "M " + p(mid(curve[curve.length - 1], curve[0]));
  // A closed quadratic spline gives every tear a continuous, rounded tangent.
  for (var i = 0; i < curve.length; i++)
    result += " Q " + p(curve[i]) + " " + p(mid(curve[i], curve[(i + 1) % curve.length]));
  return result + " Z";
}
function organicPoints(points, body, variant) {
  return curvedEdges(points).map(function(p) {
    var distance = Infinity;
    for (var i = 0; i < body.length; i++) {
      var a = body[i], b = body[(i + 1) % body.length];
      var dx = b[0] - a[0], dy = b[1] - a[1];
      var t = clamp(((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy), 0, 1);
      distance = Math.min(distance, Math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dy * t));
    }
    // Pin the silhouette, while softly warping all shared interior boundaries.
    var fade = clamp(distance / 24, 0, 1);
    fade = fade * fade * (3 - 2 * fade);
    return [p[0] + fade * (Math.sin(p[1] / 18 + variant * 0.7) * 4.5),
      p[1] + fade * (Math.sin(p[0] / 22 + variant * 0.6) * 5.5)];
  });
}
function rindTexture(points) {
  var pores = "", lights = "";
  function pixel(x, y, size) { return " M " + x.toFixed(1) + " " + y.toFixed(1)
    + " h " + size + " v " + size + " h -" + size + " Z"; }
  for (var x = 32; x < 176; x += 9) {
    for (var y = 55; y < 170; y += 9) {
      var hash = (Math.sin(x * 1.37 + y * 0.83) + 1) / 2;
      var px = x + Math.sin(y) * 1.5, py = y + Math.cos(x) * 1.5;
      if (!inside(points, px - 2, py - 2) || !inside(points, px + 3, py + 3)) continue;
      if (hash > 0.92 || (y > 139 && hash > 0.72)) pores += pixel(px, py, 1.8);
      else if (hash < 0.045) lights += pixel(px, py, 2);
    }
  }
  return { pores: pores, lights: lights };
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
function peelPieces(pattern, variant, startX, startY) {
  var body = bodyPoints(), polygons = [];
  var anchored = typeof startX === "number" && typeof startY === "number";
  var sx = anchored ? startX : 100, sy = anchored ? startY : 108;
  var lean = anchored ? clamp((sy - 108) / 160 + (variant - 2.5) * 0.025, -0.24, 0.24)
    * (sx < 100 ? -1 : 1) : variant % 2 ? -0.12 : 0.12;
  if (pattern === 0) {
    // Three broad ribbons, rather than longitudinal fruit-shaped strips.
    var shift = anchored ? (sy - 108) * 0.12 + (variant - 2.5) * 1.5 : 0;
    var levels = [-1000, 89 + lean * 100 + shift, 131 + lean * 100 + shift, 1000];
    for (var row = 0; row < 3; row++)
      polygons.push(clip(clip(body, lean, 1, levels[row + 1]), -lean, -1, -levels[row]));
  } else if (pattern === 1) {
    // Four large asymmetric flaps sharing an off-centre tear.
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 2; x++) {
        var sx = x ? -1 : 1, sy = y ? -1 : 1;
        polygons.push(clip(clip(body, sx, sx * 0.24,
          sx * (121 + variant % 3 * 3 + (anchored ? (startX - 100) * 0.25 : 0))),
          -sy * 0.17, sy, sy * (91 + (anchored ? (startY - 108) * 0.1 : 0))));
      }
    }
  } else {
    // Five Voronoi patches make a complete rind with irregular tear boundaries.
    var seeds = [[77, 67], [131, 79], [99, 108], [61, 134], [132, 143]];
    if (variant % 2) seeds = seeds.map(function(p) { return [200 - p[0], p[1]]; });
    if (anchored) {
      var nearest = 0, distance = Infinity;
      for (var seed = 0; seed < seeds.length; seed++) {
        var d = Math.hypot(seeds[seed][0] - startX, seeds[seed][1] - startY);
        if (d < distance) { nearest = seed; distance = d; }
      }
      seeds[nearest] = [clamp(startX, 40, 160), clamp(startY, 58, 158)];
      for (var seed = 0; seed < seeds.length; seed++) {
        if (seed === nearest) continue;
        seeds[seed] = [seeds[seed][0] + Math.sin(seed * 9 + variant) * 3,
          seeds[seed][1] + Math.cos(seed * 7 + variant) * 3];
      }
    }
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
    points = organicPoints(points, body, variant);
    var cx = 0, cy = 0;
    for (var i = 0; i < points.length; i++) { cx += points[i][0]; cy += points[i][1]; }
    cx /= points.length; cy /= points.length;
    return { points: points, path: path(points), texture: rindTexture(points), cx: cx, cy: cy,
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
  function point(angle, r) { return [100 + Math.cos(angle) * 74 * r, 108 + Math.sin(angle) * 59 * r]; }
  function p(angle, r) { var q = point(angle, r); return q[0].toFixed(2) + " " + q[1].toFixed(2); }
  var outline = [point(a, 0.17), point(a, 0.55), point(a, 0.9),
    point(a + (b - a) * 0.25, 1), point(mid, 1.02), point(b - (b - a) * 0.25, 1),
    point(b, 0.9), point(b, 0.55), point(b, 0.17), point(mid, 0.08)];
  return { dx: Math.cos(mid), dy: Math.sin(mid), path: path(outline),
    fibre: "M " + p(mid - 0.05, 0.3) + " Q " + p(mid + 0.055, 0.55) + " " + p(mid - 0.025, 0.82)
      + " M " + p(mid + 0.13, 0.48) + " Q " + p(mid + 0.08, 0.66) + " " + p(mid + 0.12, 0.77) };
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

function peelAxis(piece, grabX, grabY) {
  var tip = piece.points[0], best = Infinity;
  for (var i = 0; i < piece.points.length; i++) {
    var a = piece.points[i], b = piece.points[(i + 1) % piece.points.length];
    var dx = b[0] - a[0], dy = b[1] - a[1];
    var t = clamp(((grabX - a[0]) * dx + (grabY - a[1]) * dy) / Math.max(0.001, dx * dx + dy * dy), 0, 1);
    var p = [a[0] + dx * t, a[1] + dy * t];
    var distance = Math.hypot(p[0] - grabX, p[1] - grabY);
    if (distance < best) { best = distance; tip = p; }
  }
  var ux = piece.cx - tip[0], uy = piece.cy - tip[1], length = Math.hypot(ux, uy);
  if (length < 1) { ux = 0; uy = 1; length = 1; }
  ux /= length; uy /= length;
  var projections = piece.points.map(function(p) { return p[0] * ux + p[1] * uy; });
  var side = (-uy * (tip[0] - 100) + ux * (tip[1] - 108)) >= 0 ? 1 : -1;
  return { ux: ux, uy: uy, side: side,
    min: Math.min.apply(null, projections), max: Math.max.apply(null, projections) };
}
function peelFrame(piece, amount, axis) {
  amount = clamp(amount, 0, 1);
  var ux = axis.ux, uy = axis.uy, vx = -uy, vy = ux;
  var length = (axis.max - axis.min) * amount;
  var front = axis.min + length;
  var attached = amount >= 1 ? [] : clip(piece.points, -ux, -uy, -front);
  var lifted = amount <= 0 ? [] : clip(piece.points, ux, uy, front);
  var angle = Math.PI * (0.35 + amount * 0.8);
  var radius = Math.max(0.1, length / angle);
  function xy(p) { return p[0].toFixed(2) + " " + p[1].toFixed(2); }
  function bend(p) {
    var d = Math.max(0, front - p[0] * ux - p[1] * uy);
    var theta = d / radius;
    var along = front - radius * Math.sin(theta);
    var across = p[0] * vx + p[1] * vy + axis.side * radius * (1 - Math.cos(theta)) * 0.9;
    return [along * ux + across * vx, along * uy + across * vy];
  }
  function curled(points) {
    // Extra points follow the curved sheet instead of stretching its corners.
    var out = [];
    for (var i = 0; i < points.length; i++) {
      var a = points[i], b = points[(i + 1) % points.length];
      var steps = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / 4));
      for (var j = 0; j < steps; j++) {
        var t = j / steps;
        out.push(bend([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]));
      }
    }
    return out;
  }
  var flap = curled(lifted);
  // As the tip rolls over, its orange outside becomes visible again.
  var returnTip = length > 0 ? curled(clip(lifted, ux, uy, front - radius * Math.PI * 0.62)) : [];
  var seam = [];
  for (var i = 0; i < piece.points.length; i++) {
    var a = piece.points[i], b = piece.points[(i + 1) % piece.points.length];
    var da = a[0] * ux + a[1] * uy - front, db = b[0] * ux + b[1] * uy - front;
    if ((da <= 0) !== (db <= 0)) {
      var t = da / (da - db);
      seam.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
    }
  }
  var rim = "", fibres = "", marks = "";
  if (seam.length >= 2 && amount > 0 && amount < 1) {
    rim = "M " + xy(seam[0]) + " Q " + xy([(seam[0][0] + seam[1][0]) / 2 + ux * 2.5,
      (seam[0][1] + seam[1][1]) / 2 + uy * 2.5]) + " " + xy(seam[1]);
    // Fine pith strands bridge the opening, then release before detachment.
    if (amount < 0.85) {
      for (var strand = 0; strand < 3; strand++) {
        var t = 0.22 + strand * 0.27;
        var p = [seam[0][0] + (seam[1][0] - seam[0][0]) * t,
          seam[0][1] + (seam[1][1] - seam[0][1]) * t];
        var under = [p[0] - ux * Math.min(10, length * 0.6), p[1] - uy * Math.min(10, length * 0.6)];
        var above = bend(under);
        fibres += " M " + xy(under) + " Q " + xy([(under[0] + above[0]) / 2 - vx * 2,
          (under[1] + above[1]) / 2 - vy * 2]) + " " + xy(above);
      }
    }
  }
  for (var x = 35; x < 175; x += 17) {
    for (var y = 52; y < 170; y += 19) {
      var d = front - x * ux - y * uy;
      if (d <= 0 || d > radius * Math.PI * 0.6 || !inside(lifted, x, y)) continue;
      var p = bend([x, y]), q = bend([x + ux * 3, y + uy * 3]);
      marks += " M " + xy(p) + " L " + xy(q);
    }
  }
  var cx = piece.cx, cy = piece.cy;
  if (flap.length) {
    cx = flap.reduce(function(sum, p) { return sum + p[0]; }, 0) / flap.length;
    cy = flap.reduce(function(sum, p) { return sum + p[1]; }, 0) / flap.length;
  }
  return { attached: attached.length >= 3 ? path(attached, 2.5) : "",
    exposed: lifted.length >= 3 ? path(lifted, 2.5) : "",
    underside: flap.length >= 3 ? path(flap, 3 + amount * 2) : "",
    outside: returnTip.length >= 3 ? path(returnTip, 3.5) : "",
    rim: rim, fibres: fibres, marks: marks, cx: cx, cy: cy,
    attachedPoints: attached, flapPoints: flap };
}
