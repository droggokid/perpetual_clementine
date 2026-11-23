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
  for (const random of [0, 0.1, 0.5, 0.99, 1]) {
    const next = model.nextPattern(pattern, random);
    assert(next !== pattern && next >= 0 && next < 3, 'fresh fruit must change the peel pattern');
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
