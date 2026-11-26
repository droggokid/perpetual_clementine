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
var fruitShapes = [
  { width: 1.04, height: 0.86, sliceOffsets: [0, -1, 2, 0] },
  { width: 0.90, height: 1.04, sliceOffsets: [1, 4, 0, -2] },
  { width: 1.00, height: 0.98, sliceOffsets: [-2, -3, 1, 1] },
  { width: 0.93, height: 0.90, sliceOffsets: [0, 3, 4, 2] }
];
var rindColors = ["#e99531", "#f38d39", "#e77e35", "#f4ab3b"];
var stemStyles = [
  { leafX: 1.14, leafY: 0.84, leafColor: "#7ba95b", tilt: 12, secondLeaf: true },
  { leafX: -1.18, leafY: 0.58, leafColor: "#75965a", tilt: -23 },
  { leafX: 0.52, leafY: 0.66, leafColor: "#a1b45c", tilt: -27 },
  { leafX: -1.10, leafY: 1.20, leafColor: "#91ab59", tilt: 22 }
];
function patternAtStart(x, y) {
  if (y < 83) return 1; // Open the crown in broad flaps.
  if (x < 68 || x > 132) return y > 116 ? 4 : 0; // Diagonal strips from the lower shoulders.
  if (y >= 137) return 3; // A wide skirt comes off the base.
  return 2; // A lower or central start makes smaller torn patches.
}
function nextVariant(previous, length, random) {
  var roll = clamp(random, 0, 0.999999);
  return previous < 0 ? Math.floor(roll * length)
    : (previous + 1 + Math.floor(roll * (length - 1))) % length;
}
function nextFruitVariation(previous, random) {
  var shape = nextVariant(previous ? previous.shape : -1, fruitShapes.length, random());
  var remainingRinds = previous && previous.remainingRinds.length ? previous.remainingRinds.slice()
    : rindColors.map(function(color, index) { return index; });
  var rind = remainingRinds.splice(Math.floor(random() * remainingRinds.length), 1)[0];
  var stem = nextVariant(previous ? previous.stem : -1, stemStyles.length, random());
  return {
    shape: shape,
    rind: rind,
    stem: stem,
    remainingRinds: remainingRinds,
    tearSeed: random()
  };
}
function bodyPoints(variant) {
  var shape = variant || 0;
  var points = [];
  for (var i = 0; i < 96; i++) {
    var a = i * tau / 96;
    var side = Math.cos(a), vertical = Math.sin(a);
    // Broad shoulders, a flatter base and a small off-centre stem hollow.
    var x = 100 + 78 * side * (1 - vertical * (0.045 + shape * 0.017))
      + vertical * (shape - 1.5) * 2;
    var y = 108 + 63 * Math.sign(vertical) * Math.pow(Math.abs(vertical), 0.84)
      + 1.4 * Math.sin(3 * a + shape);
    if (vertical < 0) y += 7 * Math.exp(-Math.pow((x - 100) / 20, 2));
    else y -= 3 * Math.exp(-Math.pow((x - 101) / 24, 2));
    points.push([x, y]);
  }
  return points;
}
function curvedEdges(points) {
  var out = [];
  for (var i = 0; i < points.length; i++) {
    var a = points[i], b = points[(i + 1) % points.length];
    var dx = b[0] - a[0], dy = b[1] - a[1];
    var lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 0.0001) continue;
    if (lengthSquared <= 196) { out.push(a); continue; }
    var length = Math.hypot(dx, dy), steps = Math.ceil(length / 8);
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
  return splinePath(curve);
}
function splinePath(curve) {
  if (curve.length < 3) return "";
  function p(point) { return point[0].toFixed(2) + " " + point[1].toFixed(2); }
  function mid(a, b) { return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]; }
  var result = "M " + p(mid(curve[curve.length - 1], curve[0]));
  // A closed quadratic spline gives every tear a continuous, rounded tangent.
  for (var i = 0; i < curve.length; i++)
    result += " Q " + p(curve[i]) + " " + p(mid(curve[i], curve[(i + 1) % curve.length]));
  return result + " Z";
}
function organicPoints(points, body, variant, tearX, tearY) {
  var outer = [];
  var warped = curvedEdges(points).map(function(p) {
    var distanceSquared = 24 * 24;
    for (var i = 0; i < body.length; i++) {
      var a = body[i], b = body[(i + 1) % body.length];
      var dx = b[0] - a[0], dy = b[1] - a[1];
      var t = clamp(((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy), 0, 1);
      var ex = p[0] - a[0] - dx * t, ey = p[1] - a[1] - dy * t;
      distanceSquared = Math.min(distanceSquared, ex * ex + ey * ey);
    }
    // Pin the silhouette, while softly warping all shared interior boundaries.
    outer.push(distanceSquared < 0.0001);
    var fade = Math.sqrt(distanceSquared) / 24;
    fade = fade * fade * (3 - 2 * fade);
    return [p[0] + fade * (Math.sin(p[1] / 18 + variant * 0.7) * 4.5 + tearX),
      p[1] + fade * (Math.sin(p[0] / 22 + variant * 0.6) * 5.5 + tearY)];
  });
  return { points: warped, outer: outer };
}
function linePoint(point) {
  return point[0].toFixed(2) + " " + point[1].toFixed(2);
}
function linePath(lines) {
  var result = "", previous = null;
  for (var i = 0; i < lines.length; i++) {
    var a = lines[i][0], b = lines[i][1];
    if (!previous || a[0] !== previous[0] || a[1] !== previous[1]) result += " M " + linePoint(a);
    result += " L " + linePoint(b);
    previous = b;
  }
  return result;
}

var shineStrokes = [[[43, 87], [44.3, 83.4], [46.2, 80.1], [48.5, 77.1],
  [51.2, 74.3], [54.4, 71.6], [58, 69]], [[63, 67], [65, 66.3], [67, 66]]];

function rindDetails(points, outer) {
  var rim = [], shine = [];
  for (var i = 0; i < points.length; i++) {
    var next = (i + 1) % points.length;
    if (outer[i] && outer[next]) rim.push([points[i], points[next]]);
  }
  for (var i = 0; i < shineStrokes.length; i++) {
    var stroke = shineStrokes[i];
    for (var j = 1; j < stroke.length; j++) {
      var a = stroke[j - 1], b = stroke[j];
      if (inside(points, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2)) shine.push([a, b]);
    }
  }
  return { rim: rim, shine: shine, rimPath: linePath(rim), shinePath: linePath(shine) };
}

function stipple(x, y, size) {
  return " M " + x.toFixed(1) + " " + y.toFixed(1)
    + " h " + size + " v " + size + " h -" + size + " Z";
}
function rindTexture(points) {
  var pores = "", lights = "", marks = [];
  for (var x = 32; x < 176; x += 9) {
    for (var y = 55; y < 170; y += 9) {
      var hash = (Math.sin(x * 1.37 + y * 0.83) + 1) / 2;
      var dark = hash > 0.92 || (y > 139 && hash > 0.72);
      if (!dark && hash >= 0.045) continue;
      var px = x + Math.sin(y) * 1.5, py = y + Math.cos(x) * 1.5;
      if (!inside(points, px - 2, py - 2) || !inside(points, px + 3, py + 3)) continue;
      if (dark) {
        marks.push([px, py, 1.8]);
        pores += stipple(px, py, 1.8);
      } else {
        marks.push([px, py, 2]);
        lights += stipple(px, py, 2);
      }
    }
  }
  return { pores: pores, lights: lights, marks: marks };
}
function pithSamples(points) {
  var samples = [];
  for (var x = 35; x < 175; x += 12) {
    for (var y = 52; y < 170; y += 13) {
      var px = x + 3 * Math.sin(y), py = y + 3 * Math.cos(x);
      if (inside(points, px, py)) samples.push([px, py]);
    }
  }
  return samples;
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
function peelPieces(pattern, variant, startX, startY, tearSeed) {
  var body = bodyPoints(variant), polygons = [];
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
  } else if (pattern === 4) {
    var diagonal = sx < 100 ? 0.72 : -0.72;
    var middle = 108 + diagonal * 100 + (sy - 124) * 0.16 + (variant - 1.5) * 1.7;
    var edges = [-1000, middle - 37, middle + 2, middle + 40, 1000];
    for (var strip = 0; strip < 4; strip++)
      polygons.push(clip(clip(body, diagonal, 1, edges[strip + 1]), -diagonal, -1, -edges[strip]));
  } else if (pattern === 3) {
    var skirtLean = clamp((sx - 100) / 160 + (variant - 1.5) * 0.04, -0.27, 0.27);
    var hem = 128 + skirtLean * 100 + (sy - 150) * 0.16;
    var top = clip(body, skirtLean, 1, hem);
    var offset = (sx - 100) * 0.22 + (variant - 1.5) * 2;
    var seams = [-1000, 93 + offset, 147 + offset, 1000];
    var skirt = clip(body, -skirtLean, -1, -hem);
    // Share both junctions with the upper flaps before rounding the seam.
    for (var i = 0; i < skirt.length; i++) {
      var a = skirt[i], b = skirt[(i + 1) % skirt.length];
      if (Math.abs(a[0] * skirtLean + a[1] - hem) > 0.001 ||
          Math.abs(b[0] * skirtLean + b[1] - hem) > 0.001) continue;
      var junctions = seams.slice(1, -1).map(function(seam) {
        var x = (seam - 0.17 * hem) / (1 - 0.17 * skirtLean);
        return [x, hem - skirtLean * x];
      }).filter(function(p) {
        return p[0] > Math.min(a[0], b[0]) && p[0] < Math.max(a[0], b[0]);
      });
      if (a[0] > b[0]) junctions.reverse();
      skirt.splice.apply(skirt, [i + 1, 0].concat(junctions));
      break;
    }
    polygons.push(skirt);
    for (var flap = 0; flap < 3; flap++)
      polygons.push(clip(clip(top, 1, 0.17, seams[flap + 1]), -1, -0.17, -seams[flap]));
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
  // Move shared seam points together while keeping their ends on the silhouette.
  var tearX = tearSeed === undefined ? 0 : 5 * Math.cos(tearSeed * tau);
  var tearY = tearSeed === undefined ? 0 : 4 * Math.sin(tearSeed * tau);
  return polygons.map(function(points) {
    var rind = organicPoints(points, body, variant, tearX, tearY);
    points = rind.points;
    var cx = 0, cy = 0;
    for (var i = 0; i < points.length; i++) { cx += points[i][0]; cy += points[i][1]; }
    cx /= points.length; cy /= points.length;
    return { points: points, path: path(points), texture: rindTexture(points), pith: pithSamples(points),
      details: rindDetails(points, rind.outer), cx: cx, cy: cy, side: cx < 100 ? -1 : 1 };
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
// Four far lobes sit behind four near ones. Each seam follows the curved
// surface from stem to base. Eating a near lobe reveals its far neighbour.
function segment(index, variant) {
  var front = index >= 4, column = index % 4;
  var outer = column === 0 || column === 3, direction = column < 2 ? -1 : 1;
  var rhythm = fruitShapes[variant].sliceOffsets[column];
  var tip = (front ? [66, 90, 109, 140] : [61, 94, 117, 144])[column] + rhythm;
  var half = (front ? [26, 25, 25, 22] : [24, 27, 23, 21])[column] + rhythm * 0.4;
  var height = (front ? [47, 53, 52, 44] : [45, 54, 50, 45])[column];
  var curve = (outer ? 15 : 10) + rhythm * 0.5;

  function surface(across, latitude) {
    var belly = Math.pow(Math.max(0, Math.sin(latitude)), 0.74), pole = Math.cos(latitude);
    return [100 + (tip - 100 + direction * (curve * belly - 5 * pole) + across * half * belly) * 0.94,
      108 + ((front ? 3 : -3) - height * pole + across * 3 * belly) * 0.95];
  }
  function strip(left, right, start, end) {
    var points = [];
    for (var i = 0; i <= 16; i++) points.push(surface(left, start + (end - start) * i / 16));
    for (var j = 16; j >= 0; j--) points.push(surface(right, start + (end - start) * j / 16));
    return points;
  }
  function at(across, latitude) {
    return surface(across, latitude).map(function(v) { return v.toFixed(1); }).join(" ");
  }
  var outline = softenSheet(curvedEdges(strip(-1, 1, 0, Math.PI)), 3);
  var membraneLeft = path(strip(-0.92, -0.70, 0.26, 2.86), 2);
  var membraneRight = path(strip(0.69, 0.91, 0.28, 2.84), 2);
  var pulp = "";
  for (var row = 0; row < 5; row++) {
    for (var cell = 0; cell < 3; cell++) {
      var u = -0.60 + cell * 0.44 + 0.10 * Math.sin(row * 5 + cell * 3 + index);
      var v = 0.53 + row * 0.42 + 0.13 * Math.cos(cell * 3 + row + index);
      pulp += " M " + at(u, v) + " Q " + at(u + 0.13, v + 0.11) + " " + at(u + 0.09, v + 0.23)
        + " Q " + at(u - 0.04, v + 0.14) + " " + at(u, v) + " Z";
    }
  }
  // Sample the same rounded silhouette used by the SVG path for mouse picking.
  var points = [];
  for (var i = 0; i < outline.length; i++) {
    var prev = outline[(i + outline.length - 1) % outline.length];
    var here = outline[i], next = outline[(i + 1) % outline.length];
    points.push([(prev[0] + here[0]) / 2, (prev[1] + here[1]) / 2],
      [(prev[0] + 6 * here[0] + next[0]) / 8, (prev[1] + 6 * here[1] + next[1]) / 8]);
  }
  var bounds = [Infinity, Infinity, -Infinity, -Infinity];
  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    bounds[0] = Math.min(bounds[0], p[0]); bounds[1] = Math.min(bounds[1], p[1]);
    bounds[2] = Math.max(bounds[2], p[0]); bounds[3] = Math.max(bounds[3], p[1]);
  }
  return { points: points, bounds: bounds, path: splinePath(outline), pulp: pulp,
    membraneLeft: membraneLeft, membraneRight: membraneRight, dx: direction * (outer ? 1.6 : 0.5), dy: front ? 1.6 : -2 };
}
var lobes = fruitShapes.map(function(shape, variant) {
  var pieces = [];
  for (var i = 0; i < segments; i++) pieces.push(segment(i, variant));
  return pieces;
});

function bite(eaten, selection) {
  var taken = selection & ~eaten;
  var next = eaten | taken;
  return { taken: taken, eaten: next, completed: taken !== 0 && next === all };
}

function splashOriginX(piece) {
  return (piece.bounds[0] + piece.bounds[2]) / 2 + piece.dx;
}

function juiceDrops(mask, variant) {
  var bitten = lobes[variant].filter(function(piece, index) { return (mask & (1 << index)) !== 0; });
  if (!bitten.length) return [];
  bitten.sort(function(a, b) { return splashOriginX(a) - splashOriginX(b); });
  var flights = [
    { travelX: -34, lift: 84, size: 4.8 },
    { travelX: 9, lift: 102, size: 5.8 },
    { travelX: 36, lift: 76, size: 4.4 }
  ];
  var total = 2 + Math.floor(Math.random() * 2);
  var drops = [];
  for (var i = 0; i < total; i++) {
    var piece = bitten[Math.round(i * (bitten.length - 1) / (total - 1))];
    var bounds = piece.bounds;
    var x = splashOriginX(piece);
    var y = bounds[1] + (bounds[3] - bounds[1]) * 0.30 + piece.dy;
    var dropX = x + (Math.random() - 0.5) * 20;
    var dropY = y + (Math.random() - 0.5) * 12;
    if (!inside(piece.points, dropX - piece.dx, dropY - piece.dy)) {
      dropX = x;
      dropY = y;
    }
    var flight = flights[i % flights.length];
    drops.push({
      x: dropX,
      y: dropY,
      travelX: flight.travelX + (x - 100) * 0.16,
      lift: flight.lift,
      size: flight.size
    });
  }
  return drops;
}

// A little central pith holds the lobes together before the first bite.
var fleshCores = fruitShapes.map(function(shape, variant) {
  var points = bodyPoints(variant).map(function(p) {
    return [100 + (p[0] - 100) * 0.78, 108 + (p[1] - 108) * 0.86];
  });
  return { points: points, path: path(points) };
});

var coreCuts = [0, 76, 100, 124, 200];
function coreColumn(x) {
  if (x < coreCuts[1]) return 0;
  if (x < coreCuts[2]) return 1;
  return x < coreCuts[3] ? 2 : 3;
}
function remainingCorePath(variant, eaten) {
  var core = fleshCores[variant];
  if (!eaten) return core.path;
  var missing = (eaten | (eaten >> 4)) & 15;
  var result = "", column = 0;
  while (column < 4) {
    if (missing & (1 << column)) { column++; continue; }
    var left = column++;
    while (column < 4 && !(missing & (1 << column))) column++;
    var section = clip(clip(core.points, -1, 0, -coreCuts[left]), 1, 0, coreCuts[column]);
    if (section.length >= 3) {
      result += " M " + section.map(function(p) {
        return p[0].toFixed(2) + " " + p[1].toFixed(2);
      }).join(" L ") + " Z";
    }
  }
  return result;
}

function hitSegment(x, y, eaten, variant) {
  variant = variant || 0;
  for (var i = segments - 1; i >= 0; i--) {
    var s = lobes[variant][i];
    if (eaten & (1 << i)) continue;
    var px = x - s.dx, py = y - s.dy, box = s.bounds;
    if (px < box[0] || py < box[1] || px > box[2] || py > box[3]) continue;
    if (inside(s.points, px, py)) return i;
  }
  // Keep the pith pickable only under columns where both lobes remain.
  var column = coreColumn(x);
  if (!((eaten | (eaten >> 4)) & (1 << column)) && inside(fleshCores[variant].points, x, y)) {
    if (eaten) return column + 4;
    if (y !== 108) return hitSegment(x, 108, eaten, variant);
  }
  return -1;
}
function sweep(fromX, fromY, toX, toY, eaten, selected, variant) {
  var dx = toX - fromX, dy = toY - fromY;
  var steps = Math.max(1, Math.ceil(Math.hypot(dx, dy) / 3));
  var first = 0, last = steps;
  var axes = [[fromX, dx], [fromY, dy]];
  // Keep the sampling grid and visit only the part near the 200×200 artwork.
  for (var axis of axes) {
    var start = axis[0], delta = axis[1];
    if (delta === 0) {
      if (start < 0 || start > 200) return selected;
      continue;
    }
    var a = -start / delta, b = (200 - start) / delta;
    first = Math.max(first, Math.floor(Math.min(a, b) * steps));
    last = Math.min(last, Math.ceil(Math.max(a, b) * steps));
  }
  for (var i = first; i <= last; i++) {
    var t = i / steps;
    var id = hitSegment(fromX + dx * t, fromY + dy * t, eaten, variant);
    if (id >= 0) selected |= 1 << id;
  }
  return selected;
}

function peelAxis(piece, grabX, grabY, pullX, pullY) {
  var tip = piece.points[0], best = Infinity, alongPull = Infinity;
  var pullLength = Math.hypot(pullX || 0, pullY || 0);
  var aimed = pullLength > 0;
  if (aimed) { pullX /= pullLength; pullY /= pullLength; }
  for (var i = 0; i < piece.points.length; i++) {
    var a = piece.points[i], b = piece.points[(i + 1) % piece.points.length];
    var dx = b[0] - a[0], dy = b[1] - a[1];
    var t = clamp(((grabX - a[0]) * dx + (grabY - a[1]) * dy) / Math.max(0.001, dx * dx + dy * dy), 0, 1);
    var p = [a[0] + dx * t, a[1] + dy * t];
    var distance = Math.hypot(p[0] - grabX, p[1] - grabY);
    if (distance < best) { best = distance; tip = p; }
    if (aimed) {
      var cross = pullX * dy - pullY * dx;
      if (Math.abs(cross) < 0.001) continue;
      var ax = a[0] - grabX, ay = a[1] - grabY;
      var ray = (ax * dy - ay * dx) / cross;
      var edge = (ax * pullY - ay * pullX) / cross;
      if (ray >= 0 && edge >= 0 && edge <= 1) alongPull = Math.min(alongPull, ray);
    }
  }
  // Prefer an edge in the direction of the pull when it is still near the grab.
  if (alongPull <= best + 18) tip = [grabX + pullX * alongPull, grabY + pullY * alongPull];
  var ux = grabX - tip[0], uy = grabY - tip[1];
  if (Math.hypot(ux, uy) < 1 || !inside(piece.points, grabX, grabY)) {
    ux = piece.cx - tip[0]; uy = piece.cy - tip[1];
  }
  var length = Math.hypot(ux, uy);
  if (length < 0.001) { ux = 0; uy = 1; length = 1; }
  ux /= length; uy /= length;

  // In these coordinates a shallow V-shaped front cuts around the grab.
  // Split edges crossing the V's apex before shearing so both halves meet.
  var local = [], slope = 0.65;
  function project(p) {
    var x = p[0] - tip[0], y = p[1] - tip[1];
    return [x * ux + y * uy, -x * uy + y * ux];
  }
  function shear(p) { return [p[0] + slope * Math.abs(p[1]), p[1]]; }
  function markLines(lines) {
    var previous = null;
    return lines.map(function(line) {
      var stroke = {
        start: shear(project(line[0])), end: shear(project(line[1])),
        move: " M " + linePoint(line[0]), draw: " L " + linePoint(line[1]),
        continuous: previous === line[0]
      };
      previous = line[1];
      return stroke;
    });
  }
  var projected = piece.points.map(project);
  for (var j = 0; j < projected.length; j++) {
    var p = projected[j], q = projected[(j + 1) % projected.length];
    local.push(shear(p));
    if (p[1] * q[1] < 0) local.push([(p[0] * q[1] - q[0] * p[1]) / (q[1] - p[1]), 0]);
  }
  var projections = local.map(function(p) { return p[0]; });
  var pith = piece.pith.map(project).map(shear);
  var rind = piece.texture.marks.map(function(mark) {
    return { dark: mark[2] < 2, attached: stipple(mark[0], mark[1], mark[2]),
      bent: shear(project(mark)) };
  });
  // Keep the attachment axis local to the grab, but translate the lifted
  // material along the pull, including when the nearest seam faces away.
  var along = aimed ? 0.43 * (pullX * ux + pullY * uy) : -0.43;
  var across = aimed ? 0.43 * (-pullX * uy + pullY * ux) : 0;
  return { ux: ux, uy: uy, tip: tip, slope: slope, local: local, pith: pith, rind: rind,
    grab: shear(project([grabX, grabY])),
    rim: markLines(piece.details.rim), shine: markLines(piece.details.shine),
    along: along, across: across,
    min: Math.min.apply(null, projections), max: Math.max.apply(null, projections) };
}
function pullPose(axis, distance, dx, dy) {
  var reach = clamp((axis.max - axis.min) * 0.5, 26, 48);
  var pull = Math.max(0, distance - 4) / reach;
  // Open the lip quickly, then let the tear feel firmer as it reaches the hinge.
  var amount = pull < 0.24 ? pull * 1.12
    : pull < 1 ? 0.269 + 0.571 * (pull - 0.24) / 0.76
    : 0.84 + 0.07 * clamp((pull - 1) / 0.28, 0, 1);
  return { amount: amount, distance: distance, x: dx, y: dy, ready: pull >= 1 };
}

function pilePose(index) {
  return [[58, 198, -24], [91, 204, 15], [132, 200, 25], [78, 209, -9], [116, 207, -17]][index];
}

function peelFrame(piece, amount, axis, pose) {
  amount = clamp(amount, 0, 1);
  var ux = axis.ux, uy = axis.uy, vx = -uy, vy = ux;
  var along = axis.along, across = axis.across;
  var alongPull = pose ? pose.x * ux + pose.y * uy : 0;
  var acrossPull = pose ? pose.x * vx + pose.y * vy : 0;
  if (pose) {
    along = 0.43 * alongPull;
    across = 0.43 * acrossPull;
  }
  var length = (axis.max - axis.min) * amount;
  var front = axis.min + length;
  var attached = amount >= 1 ? [] : clip(axis.local, -1, 0, -front);
  var lifted = amount <= 0 ? [] : clip(axis.local, 1, 0, front);
  function world(s, v) {
    var u = s - axis.slope * Math.abs(v);
    return [axis.tip[0] + u * ux + v * vx, axis.tip[1] + u * uy + v * vy];
  }
  function unfold(points) {
    var out = [];
    for (var i = 0; i < points.length; i++) {
      var a = points[i], b = points[(i + 1) % points.length];
      out.push(world(a[0], a[1]));
      if (a[1] * b[1] < 0) out.push(world((a[0] * b[1] - b[0] * a[1]) / (b[1] - a[1]), 0));
    }
    return out;
  }
  // A shallow bend can flatten or lengthen with the pull. Its free edge
  // always stays beyond the hinge in sheet coordinates.
  var bow = 0.12 + amount * 0.08;
  var extension = 1.10 - along * 0.6;
  var gripDepth = front - axis.grab[0];
  var gripTravel = pose && pose.distance > 4
    ? (pose.distance - 4) * Math.min(1, amount / pose.amount) : 0;
  if (gripTravel > 0 && gripDepth > 3) {
    // Once the tear reaches the grab, bias the free sheet toward that same point
    // on the mouse path. Taper by depth so the attached edge never slides.
    var follow = Math.min(gripTravel * 0.68, 22);
    var desiredV = axis.grab[1] + acrossPull * follow;
    var desiredS = axis.grab[0] + alongPull * follow
      + axis.slope * (Math.abs(desiredV) - Math.abs(axis.grab[1]));
    var desiredExtension = (front - desiredS) / gripDepth + bow * gripDepth / length;
    var weight = clamp((gripDepth - 3) / 18, 0, 0.96);
    extension += (clamp(desiredExtension, 0.65, 1.65) - extension) * weight;
    across += (clamp((desiredV - axis.grab[1]) / gripDepth, -0.55, 0.55) - across) * weight;
  }
  function xy(p) { return p[0].toFixed(2) + " " + p[1].toFixed(2); }
  // Leave the fruit and hinge alone, easing only excursions past its edges.
  function softBound(value, low, high, min, max) {
    if (value < low) return low - (low - value) / (1 + (low - value) / (low - min));
    if (value > high) return high + (value - high) / (1 + (value - high) / (max - high));
    return value;
  }
  function bend(p) {
    var d = Math.max(0, front - p[0]);
    // Even at full depth the bow cannot reverse the order of material points.
    var depth = length > 0 ? clamp(d / length, 0, 1) : 0;
    var position = front - d * (extension - bow * depth);
    var screen = world(position, p[1] + across * d);
    return [softBound(screen[0], 14, 186, -24, 224),
      softBound(screen[1], 36, 174, 15, 203)];
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
        if (a[1] * b[1] < 0) {
          var centre = a[1] / (a[1] - b[1]);
          if (centre > t && centre < (j + 1) / steps)
            out.push(bend([a[0] + (b[0] - a[0]) * centre, 0]));
        }
      }
    }
    return out;
  }
  var flap = curled(lifted);
  var seam = [];
  for (var i = 0; i < axis.local.length; i++) {
    var a = axis.local[i], b = axis.local[(i + 1) % axis.local.length];
    var da = a[0] - front, db = b[0] - front;
    if ((da <= 0) !== (db <= 0)) {
      var t = da / (da - db);
      seam.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
    }
  }
  var rim = "", fibres = "", marks = "";
  var taut = Boolean(pose && pose.ready && amount < 0.99);
  seam.sort(function(a, b) { return a[1] - b[1]; });
  var nearestStrand = -1, strandDistance = Infinity;
  if (taut) {
    for (var i = 0; i + 1 < seam.length; i += 2) {
      var distance = Math.abs((seam[i][1] + seam[i + 1][1]) / 2 - axis.grab[1]);
      if (distance < strandDistance) { nearestStrand = i; strandDistance = distance; }
    }
  }
  function seamPath(a, b) {
    var edge = [world(a[0], a[1])];
    if (a[1] * b[1] < 0) edge.push(world(a[0], 0));
    edge.push(world(b[0], b[1]));
    return " M " + edge.map(xy).join(" L ");
  }
  for (var i = 0; i + 1 < seam.length && amount > 0 && amount < 1; i += 2) {
    var start = seam[i], end = seam[i + 1];
    rim += seamPath(start, end);
    // Gather the pith into a single bright strand as the last hinge stretches.
    if (taut && i === nearestStrand) {
      var v = start[1] + (end[1] - start[1]) * 0.5;
      var depth = Math.min(22, length * 0.42);
      var under = world(front - depth * 0.24, v), above = bend([front - depth, v]);
      fibres += " M " + xy(under) + " Q " + xy([(under[0] + above[0]) / 2,
        (under[1] + above[1]) / 2 + 1]) + " " + xy(above);
    } else if (!(pose && pose.ready) && amount < 0.85) {
      for (var strand = 0; strand < 2; strand++) {
        var t = 0.27 + strand * 0.46;
        var v = start[1] + (end[1] - start[1]) * t;
        var u = front - Math.min(9, length * 0.43);
        var under = world(u, v), above = bend([u, v]);
        fibres += " M " + xy(under) + " Q " + xy([(under[0] + above[0]) / 2 - vx * 2,
          (under[1] + above[1]) / 2 - vy * 2]) + " " + xy(above);
      }
    }
  }
  for (var mark = 0; mark < axis.pith.length; mark++) {
    var sample = axis.pith[mark];
    var d = front - sample[0];
    if (d <= 1 || d >= length - 2) continue;
    var p = bend(sample), q = bend([sample[0] + 2.5, sample[1] + 1]);
    marks += " M " + xy(p) + " L " + xy(q);
  }
  function attachedLines(lines) {
    var result = "", connected = false;
    for (var i = 0; i < lines.length; i++) {
      var stroke = lines[i], a = stroke.start, b = stroke.end;
      var hasStart = a[0] >= front, hasEnd = b[0] >= front;
      if (!hasStart && !hasEnd) { connected = false; continue; }
      var cut;
      if (hasStart !== hasEnd) {
        var t = (front - a[0]) / (b[0] - a[0]);
        cut = linePoint(world(front, a[1] + (b[1] - a[1]) * t));
      }
      if (!hasStart) result += " M " + cut;
      else if (!connected || !stroke.continuous) result += stroke.move;
      result += hasEnd ? stroke.draw : " L " + cut;
      connected = hasEnd;
    }
    return result;
  }
  var pores = "", lights = "";
  for (var i = 0; i < axis.rind.length; i++) {
    var mark = axis.rind[i];
    if (mark.bent[0] > front + 3) {
      if (mark.dark) pores += mark.attached;
      else lights += mark.attached;
    }
  }
  var cx = piece.cx, cy = piece.cy;
  if (flap.length) {
    cx = flap.reduce(function(sum, p) { return sum + p[0]; }, 0) / flap.length;
    cy = flap.reduce(function(sum, p) { return sum + p[1]; }, 0) / flap.length;
  }
  var pinch = "", lip = "";
  var pinchLift = Math.min(12, gripTravel * 0.8) * clamp((7 - gripDepth) / 10, 0, 1);
  if (pinchLift >= 1 && amount < 0.95) {
    // A little buckle lifts at the press point before the moving tear reaches it.
    var grab = world(axis.grab[0], axis.grab[1]);
    var half = 2.6 + pinchLift * 0.22;
    var left = [grab[0] - pose.y * half, grab[1] + pose.x * half];
    var right = [grab[0] + pose.y * half, grab[1] - pose.x * half];
    var tip = [grab[0] + pose.x * pinchLift, grab[1] + pose.y * pinchLift];
    var high = [tip[0] - pose.y * half * 0.48, tip[1] + pose.x * half * 0.48];
    var low = [tip[0] + pose.y * half * 0.48, tip[1] - pose.x * half * 0.48];
    lip = "M " + xy(high) + " Q " + xy([tip[0] + pose.x * 2, tip[1] + pose.y * 2]) + " " + xy(low);
    pinch = lip + " Q " + xy([right[0] + pose.x * 2, right[1] + pose.y * 2]) + " " + xy(right)
      + " Q " + xy(grab) + " " + xy(left) + " Q " + xy([left[0] + pose.x * 2,
        left[1] + pose.y * 2]) + " " + xy(high) + " Z";
  }
  attached = unfold(attached);
  lifted = unfold(lifted);
  return { attached: attached.length >= 3 ? path(attached, 2.5) : "",
    exposed: lifted.length >= 3 ? path(lifted, 2.5) : "",
    underside: flap.length >= 3 ? path(flap, 2.5) : "",
    rim: rim, fibres: fibres, marks: marks, pores: pores, lights: lights,
    rindRim: amount < 1 ? attachedLines(axis.rim) : "",
    rindShine: amount < 1 ? attachedLines(axis.shine) : "", cx: cx, cy: cy,
    attachedPoints: attached, flapPoints: flap, pinch: pinch, lip: lip, taut: taut,
    lift: clamp(amount * 1.4, 0, 1) };
}
