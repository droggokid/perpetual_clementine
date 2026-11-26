const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../FruitModel.js'), 'utf8'), model);

// Check every input to the production bite transition using sets of wedge numbers.
const wedges = Array.from({ length: 8 }, (_, i) => i);
const wedgeSets = Array.from({ length: 2 ** wedges.length }, (_, mask) =>
  new Set(wedges.filter(i => Math.floor(mask / 2 ** i) % 2 === 1)));
const maskOf = indices => indices.reduce((mask, index) => mask + 2 ** index, 0);
for (const [eaten, previous] of wedgeSets.entries()) {
  assert.equal(model.count(eaten), previous.size);
  for (const [selection, selected] of wedgeSets.entries()) {
    const added = wedges.filter(i => selected.has(i) && !previous.has(i));
    const after = [...previous, ...added];
    const expected = [maskOf(added), maskOf(after), previous.size < wedges.length && after.length === wedges.length];
    const bite = model.bite(eaten, selection);
    assert.deepEqual([bite.taken, bite.eaten, bite.completed], expected,
      `bite from eaten mask ${eaten} and selection ${selection}`);
  }
}
console.log('All 65,536 bite transitions match set difference, union, and one-time completion.');

const quips = vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../session/QuipDeck.js'), 'utf8') + '\ndraw');
const english = JSON.parse(fs.readFileSync(path.join(__dirname, '../i18n/en.json'), 'utf8'));
const quipKeys = Object.keys(english).filter(key => key.startsWith('peeled')).sort();
for (const sample of [0, 0.3, 0.6, 1 - Number.EPSILON]) {
  let remaining = [], previous = '';
  for (let round = 0; round < 3; round++) {
    const seen = [];
    for (let i = 0; i < quipKeys.length; i++) {
      const draw = quips(quipKeys, remaining, previous, () => sample);
      assert.notEqual(draw.key, previous, 'the last quip must not repeat across decks');
      seen.push(draw.key);
      previous = draw.key;
      remaining = draw.remaining;
    }
    assert.deepEqual(seen.sort(), quipKeys, 'each quip should appear once per deck');
    assert.equal(remaining.length, 0);
  }
}
console.log('Quips cycle through every entry without repeating between decks.');

const modelMath = vm.runInContext('Math', model);
const jitterSamples = [0, 0.5, 1 - Number.EPSILON];
function checkSplashOrigins(variant, index) {
  const piece = model.lobes[variant][index];
  const [left, top, right, bottom] = piece.bounds;
  const originX = (left + right) / 2 + piece.dx;
  const originY = top + (bottom - top) * 0.30 + piece.dy;
  const random = modelMath.random;
  try {
    for (const horizontal of jitterSamples) {
      for (const vertical of jitterSamples) {
        let sample = 0;
        // The count uses the first draw, then each droplet draws its x and y offsets.
        modelMath.random = () => sample++ % 2 === 0 ? vertical : horizontal;
        const drops = model.juiceDrops(1 << index, variant);
        assert.equal(drops.length, vertical < 0.5 ? 2 : 3);
        for (const drop of drops) {
          const label = `splash for variant ${variant}, wedge ${index}, jitter (${horizontal}, ${vertical})`;
          assert(Math.abs(drop.x - originX) <= 10 && Math.abs(drop.y - originY) <= 6, label);
          assert(model.inside(piece.points, drop.x - piece.dx, drop.y - piece.dy), label);
        }
      }
    }
  } finally {
    modelMath.random = random;
  }
}

const patternSizes = [3, 4, 5, 4, 4];
for (let pattern = 0; pattern < patternSizes.length; pattern++) {
  for (let variant = 0; variant < model.fruitShapes.length; variant++) {
    const body = model.bodyPoints(variant);
    const pieces = model.peelPieces(pattern, variant);
    assert.equal(pieces.length, patternSizes[pattern]);
    assert(pieces.every(p => p.points.length >= 3 && p.points.every(v => v.every(Number.isFinite))));
    // Every interior sample belongs to the continuous rind before peeling.
    for (let x = 23.37; x < 178; x += 4.13) {
      for (let y = 45.71; y < 171; y += 4.27) {
        if (!model.inside(body, x, y)) continue;
        const id = model.hitPeel(pieces, 0, x, y);
        assert(id >= 0, 'peel pieces must cover the fruit without gaps');
        assert.notEqual(model.hitPeel(pieces, 1 << id, x, y), id, 'removed peel cannot intercept input');
      }
    }
    assert.equal(model.hitPeel(pieces, (1 << pieces.length) - 1, 100, 108), -1);
  }
}
for (let variant = 0; variant < model.fruitShapes.length; variant++) {
  for (let column = 0; column < 4; column++) {
    const x = [42, 82, 115, 156][column];
    assert.equal(model.hitSegment(x, 110, 0, variant), column + 4);
    assert.equal(model.hitSegment(x, 110, 1 << (column + 4), variant), column);
  }
  assert.equal(model.juiceDrops(0, variant).length, 0);
  const sweepDrops = model.juiceDrops(model.all, variant).length;
  assert(sweepDrops === 2 || sweepDrops === 3, 'a sweep must emit two or three droplets total');
  for (let i = 0; i < model.segments; i++) {
    checkSplashOrigins(variant, i);
    // Isolated wedges must still be solid across both the belly and shoulders.
    for (const y of [84, 110, 134]) {
      let width = 0;
      for (let x = 20; x <= 180; x++) {
        if (model.hitSegment(x, y, model.all ^ (1 << i), variant) === i) width++;
      }
      assert(width >= 28, `isolated wedge ${i} is hollow or too thin at y=${y}`);
    }
  }
}
const selected = model.sweep(35, 118, 165, 118, 0, 0);
assert(model.count(selected) >= 2, 'a quick sweep must include intervening pieces');
assert.equal(model.sweep(35, 118, 165, 118, model.all, 0), 0);
const originalRandom = modelMath.random;
try {
  // Cover both a single row and the front and back rows together.
  for (const mask of [selected, model.all]) {
    const origins = model.lobes[0].filter((_, i) => mask & (1 << i)).map(piece =>
      (piece.bounds[0] + piece.bounds[2]) / 2 + piece.dx).sort((a, b) => a - b);
    for (const count of [2, 3]) {
      let first = true;
      modelMath.random = () => {
        if (!first) return 0.5; // Keep subsequent draws centred on their slices.
        first = false;
        return count === 2 ? 0 : 0.5;
      };
      const drops = model.juiceDrops(mask, 0);
      assert.equal(drops.length, count);
      assert.equal(drops[0].x, origins[0]);
      assert.equal(drops.at(-1).x, origins.at(-1));
      if (count === 3) assert(drops[1].x > drops[0].x && drops[1].x < drops[2].x);
    }
  }
} finally {
  modelMath.random = originalRandom;
}
const hitSegment = model.hitSegment;
const horizontal = model.sweep(199, 118, 1, 118, 0, 0);
const vertical = model.sweep(100, 1, 100, 199, 0, 0);
let samples = 0;
model.hitSegment = (...args) => { samples++; return hitSegment(...args); };
assert.equal(model.sweep(2050, 118, -1850, 118, 0, 0), horizontal);
assert(samples < 70, 'a sweep across the screen should only sample near the fruit');
assert.equal(model.sweep(100, -1850, 100, 2050, 0, 0), vertical);
assert.equal(model.sweep(-1850, 300, 2050, 300, 0, selected), selected);
model.hitSegment = hitSegment;
console.log('Continuous rind coverage, pattern variety, segment picking, and sweep checks passed.');

function unclippedSweep(from, to, eaten, selected, variant) {
  const dx = to[0] - from[0], dy = to[1] - from[1];
  const steps = Math.max(1, Math.ceil(Math.hypot(dx, dy) / 3));
  for (let step = 0; step <= steps; step++) {
    const fraction = step / steps;
    const id = model.hitSegment(from[0] + dx * fraction, from[1] + dy * fraction, eaten, variant);
    if (id >= 0) selected |= 1 << id;
  }
  return selected;
}

const sweepPaths = [
  [[-800.2, 109.4], [900.6, 109.4]],
  [[101.3, -500.7], [101.3, 450.2]],
  [[-350, -500], [400, 510]],
  [[-230, 415], [520, -300]],
  [[95, 111], [320, 210]],
  [[-8, -3], [150, -3]],
  [[-2, 205], [196, 220]],
  [[129.4, 109.6], [129.4, 109.6]],
  [[62.7, 87.2], [63.1, 87.3]],
];
for (let variant = 0; variant < model.fruitShapes.length; variant++) {
  for (const eaten of [0, 0b10100000, 0b11110000, 0b11011111, model.all]) {
    const alreadySelected = (1 << 4) & ~eaten;
    for (const [start, end] of sweepPaths) {
      for (const [from, to] of [[start, end], [end, start]]) {
        assert.equal(model.sweep(...from, ...to, eaten, alreadySelected, variant),
          unclippedSweep(from, to, eaten, alreadySelected, variant),
          `sweep ${from} → ${to}, variant ${variant}, eaten mask ${eaten}`);
      }
    }
  }
}
console.log('Clipped sweeps agree with the original sampling grid in both directions.');

function area(points) {
  return Math.abs(points.reduce((sum, p, i) => {
    const q = points[(i + 1) % points.length];
    return sum + p[0] * q[1] - q[0] * p[1];
  }, 0)) / 2;
}
for (let pattern = 0; pattern < patternSizes.length; pattern++) {
  for (const piece of model.peelPieces(pattern, 1)) {
    for (const grab of [[piece.cx, piece.cy - 100], [piece.cx + 100, piece.cy]]) {
      const axis = model.peelAxis(piece, ...grab);
      let previousArea = area(piece.points) + 0.001;
      for (const progress of [0, 0.1, 0.35, 0.65, 0.85, 1]) {
        const frame = model.peelFrame(piece, progress, axis);
        const attachedArea = area(frame.attachedPoints);
        assert(attachedArea <= previousArea + 0.001, 'the attached skin must recede as peeling advances');
        previousArea = attachedArea;
        assert(Number.isFinite(frame.cx) && Number.isFinite(frame.cy));
        assert(frame.flapPoints.every(p => p.every(Number.isFinite)));
        for (const name of ['attached', 'underside', 'rim', 'fibres', 'marks', 'pores', 'lights', 'rindRim', 'rindShine']) {
          assert(!/NaN|Infinity|undefined/.test(frame[name]));
        }
        if (progress === 0) assert.equal(frame.underside, '');
        if (progress === 1) {
          assert.equal(frame.attached, '');
          assert(frame.underside.length > 0);
          assert.equal(frame.fibres, '');
          assert.equal(frame.rindRim, '');
          assert.equal(frame.rindShine, '');
        }
      }
    }
  }
}
console.log('Progressive tear, curled surfaces, pith release, and complete detachment checks passed.');

const starts = [[100, 62, 1], [36, 108, 0], [164, 108, 0], [100, 153, 3], [100, 108, 2],
  [74, 147, 3], [46, 134, 4], [154, 134, 4]];
const tearSeeds = [0, 0.25, 0.5, 0.75];
for (const [x, y, expected] of starts) {
  assert.equal(model.patternAtStart(x, y), expected);
  for (let variant = 0; variant < model.fruitShapes.length; variant++) {
    const body = model.bodyPoints(variant);
    const layouts = new Set();
    for (const seed of tearSeeds) {
      const label = `seed ${seed}, variant ${variant}, pattern ${expected}, grab (${x}, ${y})`;
      const pieces = model.peelPieces(expected, variant, x, y, seed);
      layouts.add(pieces.map(piece => piece.path).join(''));
      assert.deepEqual(model.peelPieces(expected, variant, x, y, seed), pieces, label);
      assert.equal(pieces.length, patternSizes[expected], label);
      assert(model.hitPeel(pieces, 0, x, y) >= 0, `${label}: initial grab missed`);
      let reachable = 0;
      for (let px = 25.13; px < 178; px += 5.37) {
        for (let py = 46.31; py < 171; py += 5.23) {
          if (!model.inside(body, px, py)) continue;
          const index = model.hitPeel(pieces, 0, px, py);
          assert(index >= 0, `${label}: bare rind at (${px.toFixed(2)}, ${py.toFixed(2)})`);
          reachable |= 1 << index;
        }
      }
      assert.equal(reachable, (1 << pieces.length) - 1, `${label}: unreachable peel piece`);
      for (const piece of pieces) {
        assert(model.inside(piece.points, piece.cx, piece.cy), `${label}: keyboard grab missed`);
      }
    }
    assert.equal(layouts.size, tearSeeds.length, 'different seeds should give different tears');
  }
}
let fruit = null;
const rindOrder = [0, 0, 0, 0, 0.99, 0, 0, 0].map(random => {
  const next = model.nextFruitVariation(fruit, () => random);
  if (fruit) {
    assert.notEqual(next.shape, fruit.shape);
    assert.notEqual(next.stem, fruit.stem);
  }
  fruit = next;
  return next.rind;
});
assert.deepEqual(rindOrder, [0, 1, 2, 3, 3, 0, 1, 2], 'each colour appears once per shuffle');
const lastChoices = model.nextFruitVariation(null, () => 0.99);
assert.equal(lastChoices.shape, model.fruitShapes.length - 1);
assert.equal(lastChoices.stem, model.stemStyles.length - 1);
assert.equal(lastChoices.rind, model.rindColors.length - 1);
for (let previous = 0; previous < model.fruitShapes.length; previous++) {
  for (const random of [0, 0.1, 0.5, 0.99, 1]) {
    const next = model.nextVariant(previous, model.fruitShapes.length, random);
    assert(next !== previous && next >= 0 && next < model.fruitShapes.length);
  }
}
for (const [a, b] of [[[36, 105], [36, 112]], [[96, 62], [104, 62]], [[94, 147], [106, 147]], [[45, 128], [50, 137]]]) {
  const family = model.patternAtStart(...a);
  assert.equal(model.patternAtStart(...b), family);
  const first = model.peelPieces(family, 1, ...a).map(p => p.path).join('');
  const second = model.peelPieces(family, 1, ...b).map(p => p.path).join('');
  assert.notEqual(first, second, 'the precise starting point should shape the layout within its family');
}
console.log('Start-selected families, anchored rind coverage, and variation checks passed.');

const grabXs = [28.4, 43.9, 57.2, 67.8, 68.2, 89.7, 112.9, 131.8, 132.2, 151.2, 172.8];
const grabYs = [58.7, 82.8, 83.2, 98.4, 115.8, 116.2, 136.8, 137.2, 154.7, 162.9];
for (let variant = 0; variant < model.fruitShapes.length; variant++) {
  const body = model.bodyPoints(variant);
  const probes = [];
  for (let x = 25.41; x < 178; x += 7.37) {
    for (let y = 46.73; y < 171; y += 7.19) {
      if (model.inside(body, x, y)) probes.push([x, y]);
    }
  }
  for (const x of grabXs) {
    for (const y of grabYs) {
      if (!model.inside(body, x, y)) continue;
      const pattern = model.patternAtStart(x, y);
      const label = `variant ${variant}, pattern ${pattern}, grab (${x}, ${y})`;
      const pieces = model.peelPieces(pattern, variant, x, y);
      assert.equal(pieces.length, patternSizes[pattern], label);
      assert(model.hitPeel(pieces, 0, x, y) >= 0, `${label}: initial grab missed`);
      let reachable = 0;
      for (const [px, py] of probes) {
        const index = model.hitPeel(pieces, 0, px, py);
        assert(index >= 0, `${label}: bare rind at (${px.toFixed(2)}, ${py.toFixed(2)})`);
        reachable |= 1 << index;
      }
      assert.equal(reachable, (1 << pieces.length) - 1, `${label}: unreachable peel piece`);
    }
  }
}
console.log('Starting near pattern boundaries preserves rind coverage and reachable peel pieces.');

for (let variant = 0; variant < model.fruitShapes.length; variant++) {
  for (const [x, y, pattern] of starts.concat([[140, 134, 2]])) {
    const pieces = model.peelPieces(pattern, variant, x, y);
    for (const piece of pieces) {
      const axis = model.peelAxis(piece, piece.cx, piece.cy);
      assert.equal(model.pullPose(axis, 0, 1, 0).amount, 0);
      const ready = model.pullPose(axis, 80, 1, 0);
      assert(ready.ready && ready.amount < 1);
      const held = model.peelFrame(piece, ready.amount, axis, ready);
      assert(held.attached.length > 0 && held.taut && held.fibres.length > 0);
      for (const progress of [0.25, 0.5, 0.75, 0.96, 1]) {
        const frame = model.peelFrame(piece, progress, axis);
        assert(frame.flapPoints.every(([px, py]) => px >= -24 && px <= 224 && py >= 15 && py <= 203),
          'the curl must fit inside the artwork layer with padding for its rim and shadow');
      }
    }
  }
}
console.log('Pull travel, shallow curl, and stage bounds checks passed.');

const oppositeGrab = [91, 70];
const crown = model.peelPieces(1, 3, ...oppositeGrab);
const grabbed = crown[model.hitPeel(crown, 0, ...oppositeGrab)];
const leftAxis = model.peelAxis(grabbed, ...oppositeGrab, -1, 0);
const rightAxis = model.peelAxis(grabbed, ...oppositeGrab, 1, 0);
assert(Math.hypot(leftAxis.tip[0] - rightAxis.tip[0], leftAxis.tip[1] - rightAxis.tip[1]) < 1);
const leftCurl = model.peelFrame(grabbed, 0.18, leftAxis);
const rightCurl = model.peelFrame(grabbed, 0.18, leftAxis, { x: 1, y: 0 });
assert(leftCurl.cx < rightCurl.cx - 3, 'the loose end should follow the pull even at the same tear edge');
assert(leftCurl.rindRim.length > 0, 'lifting a corner preserves the intact rind outline');

const centreGrab = [100, 108];
const patchLayout = model.peelPieces(2, 0, ...centreGrab);
const patch = patchLayout[model.hitPeel(patchLayout, 0, ...centreGrab)];
const patchAxis = model.peelAxis(patch, ...centreGrab, 1, 0);
const smallPull = model.pullPose(patchAxis, 10, 1, 0);
const liftedLip = model.peelFrame(patch, smallPull.amount, patchAxis, smallPull);
assert(!smallPull.ready && liftedLip.lip.length > 0 && liftedLip.pinch.length > 0);
const firstLipX = Number(liftedLip.lip.split(" ")[1]);
assert(firstLipX > centreGrab[0] && firstLipX < centreGrab[0] + 10, 'the lip should track the grab at first lift');
const stretched = model.pullPose(patchAxis, 80, 1, 0);
const released = model.peelFrame(patch, 1, patchAxis, stretched);
assert(!released.taut && released.fibres === '' && released.attached === '' && released.pinch === '');

const sideGrab = [38, 108];
const ribbons = model.peelPieces(0, 0, ...sideGrab);
const ribbon = ribbons[model.hitPeel(ribbons, 0, ...sideGrab)];
const ribbonAxis = model.peelAxis(ribbon, ...sideGrab, -1, 0);
const longPull = model.pullPose(ribbonAxis, 78, -1, 0);
const longCurl = model.peelFrame(ribbon, longPull.amount, ribbonAxis, longPull);
assert(Math.min(...longCurl.flapPoints.map(p => p[0])) < sideGrab[0] - 8,
  'a wide ribbon must stay on the pull side when fully stretched');

function crossesItself(points) {
  function side(a, b, p) {
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]);
  }
  for (let i = 0; i < points.length; i++) {
    const a = points[i], b = points[(i + 1) % points.length];
    for (let j = i + 2; j < points.length; j++) {
      if (i === 0 && j === points.length - 1) continue;
      const c = points[j], d = points[(j + 1) % points.length];
      if (side(a, b, c) * side(a, b, d) < -1e-5 && side(c, d, a) * side(c, d, b) < -1e-5)
        return true;
    }
  }
  return false;
}
for (let variant = 0; variant < model.fruitShapes.length; variant++) {
  for (const [x, y, pattern] of starts) {
    const pieces = model.peelPieces(pattern, variant, x, y);
    const piece = pieces[model.hitPeel(pieces, 0, x, y)];
    const axis = model.peelAxis(piece, x, y, -1, 0);
    // Turn in the middle of the pull while keeping the same hinge.
    for (const [dx, dy] of [[-1, 0], [0, -1], [1, 0], [0, 1]]) {
      for (const distance of [10, 24, 39, 60, 82]) {
        const pose = model.pullPose(axis, distance, dx, dy);
        const frame = model.peelFrame(piece, pose.amount, axis, pose);
        assert(!crossesItself(frame.flapPoints), 'one continuous peel sheet must not cross over itself');
      }
    }
  }
}
