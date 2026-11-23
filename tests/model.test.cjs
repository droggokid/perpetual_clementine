const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../FruitModel.js'), 'utf8'), model);

const body = model.bodyPoints();
for (let pattern = 0; pattern < 3; pattern++) {
  for (let variant = 0; variant < 6; variant++) {
    const pieces = model.peelPieces(pattern, variant);
    assert.equal(pieces.length, pattern + 3);
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
for (let i = 0; i < model.segments; i++) {
  const part = model.segment(i);
  const x = 100 + part.dx * 43, y = 108 + part.dy * 35;
  assert.equal(model.hitSegment(x, y, 0), i);
  assert.notEqual(model.hitSegment(x, y, 1 << i), i);
}
const selected = model.sweep(35, 118, 165, 118, 0, 0);
assert(model.count(selected) >= 2, 'a quick sweep must include intervening pieces');
assert.equal(model.sweep(35, 118, 165, 118, model.all, 0), 0);
assert.equal(model.hitSegment(100, 108, 0), -1, 'the centre gap is not an edible segment');
console.log('Continuous rind coverage, pattern variety, segment picking, and sweep checks passed.');

function area(points) {
  return Math.abs(points.reduce((sum, p, i) => {
    const q = points[(i + 1) % points.length];
    return sum + p[0] * q[1] - q[0] * p[1];
  }, 0)) / 2;
}
for (let pattern = 0; pattern < 3; pattern++) {
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
        for (const name of ['attached', 'underside', 'outside', 'rim', 'fibres', 'marks']) {
          assert(!/NaN|Infinity|undefined/.test(frame[name]));
        }
        if (progress === 0) assert.equal(frame.underside, '');
        if (progress === 1) {
          assert.equal(frame.attached, '');
          assert(frame.underside.length > 0);
          assert.equal(frame.fibres, '');
        }
      }
    }
  }
}
console.log('Progressive tear, curled surfaces, pith release, and complete detachment checks passed.');

const starts = [[100, 62, 1], [36, 108, 0], [164, 108, 0], [100, 153, 2], [100, 108, 2]];
for (const [x, y, expected] of starts) {
  assert.equal(model.patternAtStart(x, y), expected);
  for (let variant = 0; variant < 6; variant++) {
    const pieces = model.peelPieces(expected, variant, x, y);
    assert.equal(pieces.length, expected + 3);
    assert(model.hitPeel(pieces, 0, x, y) >= 0, 'the first grab must land in its selected pattern');
    for (let px = 25.13; px < 178; px += 5.37) {
      for (let py = 46.31; py < 171; py += 5.23) {
        if (!model.inside(body, px, py)) continue;
        assert(model.hitPeel(pieces, 0, px, py) >= 0, 'anchored patterns must still cover the whole rind');
      }
    }
  }
}
for (let previous = 0; previous < 6; previous++) {
  for (const random of [0, 0.1, 0.5, 0.99, 1]) {
    const next = model.nextVariant(previous, random);
    assert(next !== previous && next >= 0 && next < 6);
  }
}
for (const [a, b] of [[[36, 105], [36, 112]], [[96, 62], [104, 62]], [[94, 147], [106, 147]]]) {
  const family = model.patternAtStart(...a);
  assert.equal(model.patternAtStart(...b), family);
  const first = model.peelPieces(family, 1, ...a).map(p => p.path).join('');
  const second = model.peelPieces(family, 1, ...b).map(p => p.path).join('');
  assert.notEqual(first, second, 'the precise starting point should shape the layout within its family');
}
console.log('Start-selected families, anchored rind coverage, and variation checks passed.');
