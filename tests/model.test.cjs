const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../FruitModel.js'), 'utf8'), model);

const peel = model.freshPeel();
const covered = model.scene(0.12, 0.4, peel, 0, 0, 0);
assert.equal(model.hit(covered, 0.1, 0).kind, 'peel');
assert.equal(model.hit(covered, 2, 2), null);
assert.equal(model.peeled(peel), false);

const bare = Array(10).fill(1);
assert.equal(model.peeled(bare), true);
for (const yaw of [0.12, 1.2, 3, 5.7]) {
  const faces = model.scene(yaw, 0.4, bare, 0, 0, 0);
  for (const face of faces) {
    assert(face.points.every(p => p.every(Number.isFinite)));
    assert(face.alpha >= 0 && face.alpha <= 1);
  }
  assert(faces.every((f, i) => i === 0 || f.z >= faces[i - 1].z));
  const picked = model.hit(faces, 0.12, 0.05);
  assert(picked && picked.kind !== 'peel');
  const removed = model.scene(yaw, 0.4, bare, 1 << picked.id, 0, 0);
  assert(removed.every(f => f.id !== picked.id), 'eaten segments must not render or intercept picks');
  const selected = model.sweep(faces, -0.8, 0.1, 0.8, 0.1, 0);
  assert(model.count(selected) >= 3, 'a fast sweep must include intervening segments');
}
assert.equal(model.scene(0, 0.4, bare, model.all, 0, 0).length, 0);
assert.equal(model.frontmost([], true), -1);
assert.equal(model.freshPeel().join(','), '0,0,0,0,0,0,0,0,0,0');
console.log('Geometry, picking, occlusion, rotation, and sweep checks passed.');
