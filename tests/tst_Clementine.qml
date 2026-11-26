import QtQuick
import QtTest
import ".."
import "../FruitModel.js" as Model

Rectangle {
  id: testSurface
  width: 400
  height: 400
  color: "white"

  Clementine {
    id: fruit
    anchors.fill: parent
    animationDuration: 0
  }

  SignalSpy { id: completion; target: fruit; signalName: "fruitEaten" }
  SignalSpy { id: landing; target: fruit; signalName: "dropSettleChanged" }

  TestCase {
    name: "Clementine"
    when: windowShown

    function init() {
      testSurface.color = "white";
      fruit.anchors.margins = 0;
      fruit.animationDuration = 0;
      fruit.usingKeyboard = false;
      fruit.renewDelay = 1400;
      fruit.interactive = true;
      fruit.reset();
      completion.clear();
      landing.clear();
    }
    function setVariation(overrides) {
      fruit.variation = Object.assign({}, fruit.variation, overrides);
    }
    function pixel(x, y) {
      return Qt.point(fruit.centerX + (x - 100) * fruit.artScale * fruit.fruitStyle.width,
        fruit.centerY + (y - 100) * fruit.artScale * fruit.fruitStyle.height);
    }
    function takePiece() {
      if (!fruit.fullyPeeled) {
        if (!fruit.patternChosen) { pullFrom(100, 62, 70); return; }
        for (var i = 0; i < fruit.pieces.length; i++) {
          if (!(fruit.peeledMask & (1 << i))) {
            pullFrom(fruit.pieces[i].cx, fruit.pieces[i].cy, 70);
            return;
          }
        }
      }
      for (var x = 30; x <= 170; x += 3) {
        var p = pixel(x, 110);
        if (fruit.hitAt(Math.round(p.x), Math.round(p.y)) >= 0) {
          mouseClick(fruit, p.x, p.y, Qt.LeftButton);
          return;
        }
      }
      fail("No visible piece at the fruit's equator");
    }
    function expose() {
      takePiece();
      var count = fruit.peelRemaining;
      for (var i = 0; i < count; i++) takePiece();
      verify(fruit.fullyPeeled);
      compare(fruit.remaining, 8);
    }

    function test_pull_and_snapback() {
      var count = fruit.peelRemaining;
      pullFrom(110, 110, 5);
      compare(fruit.peelRemaining, count);
      compare(fruit.peelProgress, 0);
      pullFrom(110, 110, 80);
      compare(fruit.pattern, 2);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);
      compare(fruit.remaining, 8);
    }
    function test_fixed_pose() {
      var p = pixel(110, 110), count = fruit.peelRemaining;
      mouseDrag(fruit, p.x, p.y, 60, 25, Qt.RightButton);
      compare(fruit.peelRemaining, count);
      compare(fruit.gesture, "");
      compare(fruit.remaining, 8);
    }
    function test_fruit_appearance_parts_can_mix() {
      for (var shape = 0; shape < Model.fruitShapes.length; shape++) {
        for (var rind = 0; rind < Model.rindColors.length; rind++) {
          for (var stem = 0; stem < Model.stemStyles.length; stem++) {
            setVariation({ shape: shape, rind: rind, stem: stem });
            compare(fruit.fruitStyle, Model.fruitShapes[shape]);
            verify(Qt.colorEqual(fruit.rindColor, Model.rindColors[rind]));
            compare(fruit.stemStyle, Model.stemStyles[stem]);
          }
        }
      }
    }
    function test_reset_renews_fruit_variation() {
      setVariation({ remainingRinds: [] });
      var lastRinds = [];
      for (var cycle = 0; cycle < 6; cycle++) {
        var rinds = [];
        for (var draw = 0; draw < Model.rindColors.length; draw++) {
          var previous = fruit.variation;
          fruit.reset();
          var next = fruit.variation;
          verify(next.shape !== previous.shape);
          verify(next.stem !== previous.stem);
          verify(rinds.indexOf(next.rind) === -1);
          verify(lastRinds[0] !== next.rind || lastRinds[1] !== next.rind);
          lastRinds = [next.rind, lastRinds[0]];
          rinds.push(next.rind);
        }
        compare(fruit.variation.remainingRinds.length, 0);
      }
    }
    function test_click_eats_one() {
      expose();
      var p = pixel(122, 76);
      verify(fruit.hitAt(p.x, p.y) >= 0);
      mouseClick(fruit, p.x, p.y, Qt.LeftButton);
      compare(fruit.remaining, 7);
    }
    function test_stationary_seam_click_with_transformed_art_eats_one() {
      setVariation({ shape: 0 });
      expose();
      fruit.arrival = 0.25;
      for (var x = 45; x < 156; x += 0.5) {
        var p = pixel(x, 110);
        var displayed = fruit.hitAt(Math.round(p.x), Math.round(p.y));
        var restingX = (Math.round(p.x) - fruit.centerX) / (fruit.artScale * fruit.fruitStyle.width) + 100;
        var restingY = (Math.round(p.y) - fruit.centerY) / (fruit.artScale * fruit.fruitStyle.height) + 100;
        var resting = Model.hitSegment(restingX, restingY, 0, fruit.variant);
        if (displayed < 0 || resting < 0 || displayed === resting) continue;
        mouseClick(fruit, Math.round(p.x), Math.round(p.y), Qt.LeftButton);
        compare(fruit.eaten, 1 << displayed);
        return;
      }
      fail("The sample row should contain a seam shifted by the artwork transform");
    }
    function test_sweep_commits_on_release() {
      expose();
      fruit.animationDuration = 160;
      var splash = findChild(fruit, "juiceSplash");
      var a = pixel(35, 118), b = pixel(165, 118);
      mousePress(fruit, a.x, a.y, Qt.LeftButton);
      mouseMove(fruit, b.x, b.y);
      compare(fruit.remaining, 8);
      verify(fruit.selected !== 0);
      compare(splash.count, 0);
      mouseRelease(fruit, b.x, b.y, Qt.LeftButton);
      verify(fruit.remaining <= 6);
      compare(fruit.selected, 0);
      verify(splash.count === 2 || splash.count === 3);
    }
    function test_cancel_and_close() {
      expose();
      var p = pixel(122, 76);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      verify(fruit.selected !== 0);
      fruit.cancelGesture();
      mouseRelease(fruit, p.x, p.y, Qt.LeftButton);
      compare(fruit.remaining, 8);
      compare(fruit.selected, 0);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      fruit.interactive = false;
      compare(fruit.gesture, "");
      compare(fruit.remaining, 8);
      mouseRelease(fruit, p.x, p.y, Qt.LeftButton);
    }
    function test_close_during_tug() {
      var p = pixel(110, 110), count = fruit.peelRemaining;
      fruit.animationDuration = 80;
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      var end = pullTarget(110, 110, 25);
      mouseMove(fruit, end.x, end.y);
      fruit.interactive = false;
      compare(fruit.activePeel, -1);
      compare(fruit.peelRemaining, count);
      compare(fruit.busy, false);
      mouseRelease(fruit, end.x, end.y, Qt.LeftButton);
    }
    function test_interrupted_detachment_data() {
      return [{ tag: "close" }, { tag: "reduce-motion" }, { tag: "reset" }];
    }
    function test_interrupted_detachment(row) {
      fruit.animationDuration = 300;
      takePiece();
      verify(fruit.inputBlocked);
      var index = fruit.activePeel;
      verify(index >= 0);
      compare(fruit.peeledMask, 0);

      if (row.tag === "close") fruit.interactive = false;
      else if (row.tag === "reduce-motion") fruit.animationDuration = 0;
      else fruit.reset();

      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.activePeel, -1);
      compare(fruit.dropping, -1);
      compare(completion.count, 0);
      if (row.tag === "reset") {
        verify(!fruit.patternChosen);
        compare(fruit.peeledMask, 0);
        compare(fruit.landed.length, 0);
      } else {
        compare(fruit.peeledMask, 1 << index);
        compare(fruit.landed[0].piece, index);
        verify(fruit.landed[0].frame.bands.some(b => b.path.length > 0));
      }
      fruit.animationDuration = 0;
      fruit.interactive = true;
      takePiece();
      compare(Model.count(fruit.peeledMask), row.tag === "reset" ? 1 : 2);
    }
    function test_reset_during_sweep_discards_the_selection() {
      expose();
      var from = pixel(35, 118), to = pixel(165, 118);
      mousePress(fruit, from.x, from.y, Qt.LeftButton);
      mouseMove(fruit, to.x, to.y);
      verify(Model.count(fruit.selected) > 1);
      fruit.reset();
      mouseRelease(fruit, to.x, to.y, Qt.LeftButton);
      compare(fruit.selected, 0);
      compare(fruit.remaining, 8);
      compare(completion.count, 0);
      verify(!fruit.patternChosen);
    }
    function test_animation_finishes() {
      fruit.animationDuration = 80;
      takePiece();
      var count = fruit.pieces.length;
      verify(fruit.busy);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.peelRemaining, count - 1);
      compare(fruit.activePeel, -1);
      fruit.animationDuration = 0;
      while (!fruit.fullyPeeled) takePiece();
      fruit.animationDuration = 80;
      var splash = findChild(fruit, "juiceSplash");
      verify(splash);
      takePiece();
      verify(fruit.busy);
      verify(splash.count === 2 || splash.count === 3);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.remaining, 7);
      compare(fruit.fading, 0);
      tryCompare(splash, "count", 0, 2000);
      takePiece();
      verify(splash.count === 2 || splash.count === 3);
      fruit.animationDuration = 0;
      compare(splash.count, 0);
      takePiece();
      compare(fruit.remaining, 5);
      compare(splash.count, 0);
    }
    function test_finish_and_new_start() {
      expose();
      for (var i = 0; i < 7; i++) takePiece();
      compare(completion.count, 0);
      takePiece();
      compare(fruit.remaining, 0);
      compare(completion.count, 1);
      fruit.eatSelection();
      compare(completion.count, 1);
      var previous = fruit.variant;
      fruit.reset();
      verify(fruit.variant !== previous);
      verify(!fruit.patternChosen);
      compare(fruit.remaining, 8);
      compare(fruit.peelRemaining, 0);
      compare(completion.count, 1);
    }
    function test_close_during_final_bite_keeps_completion() {
      expose();
      for (var i = 0; i < 7; i++) takePiece();
      fruit.animationDuration = 220;
      takePiece();
      verify(fruit.busy);
      verify(fruit.fading !== 0);
      compare(completion.count, 1);

      fruit.interactive = false;
      compare(fruit.remaining, 0);
      compare(fruit.busy, false);
      compare(fruit.fading, 0);
      compare(findChild(fruit, "juiceSplash").count, 0);
      fruit.interactive = true;
      fruit.keyboardAction();
      compare(completion.count, 1);
    }
    function finishFruit() {
      expose();
      for (var i = 0; i < 8; i++) takePiece();
      compare(fruit.remaining, 0);
    }
    function test_progressive_fold() {
      var p = pixel(110, 110), count = fruit.peelRemaining;
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      var end = pullTarget(110, 110, 30);
      mouseMove(fruit, end.x, end.y);
      verify(fruit.peelFrame !== null);
      verify(fruit.peelFrame.attached.length > 0);
      verify(fruit.peelFrame.bands.some(b => b.path.length > 0));
      verify(fruit.peelFrame.fibres.length > 0);
      compare(fruit.peelRemaining, fruit.pieces.length);
      compare(fruit.peeledMask, 0);
      fruit.cancelGesture();
      mouseRelease(fruit, end.x, end.y, Qt.LeftButton);
      compare(fruit.peelRemaining, count);
    }
    function test_fold_lands_in_its_own_shape() {
      fruit.animationDuration = 120;
      takePiece();
      tryVerify(function() { return fruit.dropping >= 0; }, 2000);
      var id = fruit.dropping, shape = fruit.dropFrame.bands;
      verify(shape.length > 0);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.landed[0].piece, id);
      compare(fruit.landed[0].frame.bands, shape);
      compare(fruit.dropping, -1);
      verify(landing.count > 0, "The rind should settle after hitting the pile");
      fruit.animationDuration = 0;
      landing.clear();
      takePiece();
      compare(fruit.dropping, -1);
      compare(landing.count, 0);
    }
    function test_peel_pile_keeps_landing_order() {
      setVariation({ shape: 0 });
      fruit.startPoint = Qt.point(100, 108);
      fruit.pattern = Model.patternAtStart(100, 108);
      fruit.keyboardIndex = 1;
      fruit.keyboardAction();
      fruit.keyboardIndex = 0;
      fruit.keyboardAction();
      compare(fruit.landed.map(peel => peel.piece), [1, 0]);
    }
    function test_automatic_renewal() {
      fruit.renewDelay = 80;
      var variant = fruit.variant;
      finishFruit();
      wait(25);
      compare(fruit.remaining, 0);
      tryCompare(fruit, "remaining", 8, 1000);
      verify(fruit.variant !== variant);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);
      compare(fruit.landed.length, 0);
    }
    function test_renewal_waits_while_closed() {
      fruit.renewDelay = 70;
      finishFruit();
      fruit.interactive = false;
      wait(140);
      compare(fruit.remaining, 0);
      fruit.interactive = true;
      tryCompare(fruit, "remaining", 8, 1000);
    }
    function test_manual_reset_cancels_pending_renewal() {
      fruit.renewDelay = 70;
      finishFruit();
      fruit.reset();
      takePiece();
      var mask = fruit.peeledMask;
      verify(mask !== 0);
      wait(140);
      compare(fruit.peeledMask, mask);
    }

    function pullTarget(x, y, distance) {
      var axis = Model.peelAxis(fruit.pieces[fruit.activePeel], x, y);
      return pixel(x + axis.pullX * distance, y + axis.pullY * distance);
    }
    function pullFrom(x, y, distance) {
      var p = pixel(x, y);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      verify(fruit.activePeel >= 0);
      var end = pullTarget(x, y, distance);
      mouseMove(fruit, end.x, end.y);
      mouseRelease(fruit, end.x, end.y, Qt.LeftButton);
    }
    function test_initial_drag_sets_direction_and_reverses() {
      setVariation({ shape: 0, tearSeed: 0.25 });
      var p = pixel(36, 108);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      var inward = pixel(72, 108), outward = pixel(8, 108);
      mouseMove(fruit, inward.x, inward.y);
      verify(fruit.peelProgress > 0);
      mouseMove(fruit, p.x, p.y);
      compare(fruit.peelProgress, 0);
      mouseMove(fruit, outward.x, outward.y);
      compare(fruit.peelProgress, 0);
      mouseMove(fruit, p.x, p.y);
      compare(fruit.peelProgress, 0);
      mouseRelease(fruit, p.x, p.y, Qt.LeftButton);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);

      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      var fullPull = pixel(-44, 108);
      mouseMove(fruit, fullPull.x, fullPull.y);
      mouseRelease(fruit, fullPull.x, fullPull.y, Qt.LeftButton);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);
    }
    function test_outward_pull_works_near_crown_seam() {
      setVariation({ shape: 0, tearSeed: 0 });
      var grab = pixel(77, 74), inward = pixel(121, 139), outward = pixel(33, 9);
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      mouseMove(fruit, outward.x, outward.y);
      verify(fruit.pullPose.ready);
      mouseMove(fruit, inward.x, inward.y);
      compare(fruit.peelProgress, 0);
      mouseMove(fruit, outward.x, outward.y);
      mouseRelease(fruit, outward.x, outward.y, Qt.LeftButton);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);
    }
    function test_drag_can_turn_sideways_and_close_on_reversal() {
      setVariation({ shape: 0 });
      var grab = pixel(36, 108);
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      var points = [pixel(14, 108), pixel(36, 164), pixel(92, 108)];
      mouseMove(fruit, points[0].x, points[0].y);
      verify(fruit.peelProgress > 0);
      var hinge = fruit.peelAxis.tip;
      mouseMove(fruit, points[1].x, points[1].y);
      verify(fruit.peelProgress >= 0.72);
      mouseMove(fruit, points[2].x, points[2].y);
      compare(fruit.peelProgress, 0);
      mouseMove(fruit, grab.x, grab.y);
      mouseMove(fruit, points[2].x, points[2].y);
      compare(fruit.peelAxis.tip[0], hinge[0]);
      compare(fruit.peelAxis.tip[1], hinge[1]);
      compare(fruit.peelProgress, 0);
      verify(!fruit.pullPose.ready);
      mouseRelease(fruit, points[2].x, points[2].y, Qt.LeftButton);
      compare(fruit.peeledMask, 0);
      verify(!fruit.patternChosen);
    }
    function test_grip_lifts_at_cursor_and_ready_peel_waits_for_release() {
      setVariation({ shape: 0 });
      var grab = pixel(100, 108);
      var lift = pixel(110, 108);
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      mouseMove(fruit, lift.x, lift.y);
      verify(fruit.peelFrame.exposedPoints.length > 2);
      verify(!fruit.pullPose.ready);
      mouseRelease(fruit, lift.x, lift.y, Qt.LeftButton);
      compare(fruit.peeledMask, 0);

      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      var pull = pixel(178, 108);
      mouseMove(fruit, pull.x, pull.y);
      verify(fruit.pullPose.ready && fruit.peelFrame.taut);
      compare(fruit.hintKey, "releaseHint");
      mouseMove(fruit, lift.x, lift.y);
      compare(fruit.hintKey, "peelHint");
      mouseMove(fruit, pull.x, pull.y);
      compare(fruit.hintKey, "releaseHint");
      verify(fruit.peelFrame.fibres.length > 0 && fruit.peelFrame.attached.length > 0);
      compare(fruit.peeledMask, 0);
      var index = fruit.activePeel;
      mouseRelease(fruit, pull.x, pull.y, Qt.LeftButton);
      compare(fruit.peeledMask, 1 << index);
      compare(fruit.landed[0].piece, index);
      compare(fruit.landed[0].frame.fibres, "");
    }

    function test_can_grab_during_drop() {
      fruit.animationDuration = 220;
      setVariation({ shape: 0 });
      pullFrom(100, 62, 80);
      tryVerify(function() { return fruit.dropping >= 0 && fruit.dropProgress > 0.05; });
      var prior = fruit.dropProgress;
      var index = 0;
      while (fruit.peeledMask & (1 << index)) index++;
      var piece = fruit.pieces[index];
      var p = pixel(piece.cx, piece.cy);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      compare(fruit.activePeel, index);
      verify(fruit.dropping >= 0);
      mouseRelease(fruit, p.x, p.y, Qt.LeftButton);
      verify(fruit.dropping < 0 || fruit.dropProgress >= prior,
        "Cancelling the second grab must not rewind the falling peel");
      tryCompare(fruit, "busy", false);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);
    }
    function test_start_location_selects_pattern() {
      var starts = [[100, 62, 1], [36, 108, 0], [164, 108, 0], [100, 153, 3],
        [100, 108, 2], [46, 134, 4], [154, 134, 4]];
      for (var i = 0; i < starts.length; i++) {
        fruit.reset();
        verify(!fruit.patternChosen);
        pullFrom(starts[i][0], starts[i][1], 70);
        compare(fruit.pattern, starts[i][2]);
        verify(Math.abs(fruit.startPoint.x - starts[i][0]) < 1);
        verify(Math.abs(fruit.startPoint.y - starts[i][1]) < 1);
        compare(fruit.peelRemaining, fruit.pieces.length - 1);
      }
    }
    function test_seed_changes_peel_for_the_same_grab() {
      setVariation({ shape: 0, tearSeed: 0 });
      verify(fruit.beginPeel(0, 100, 62));
      var layout = JSON.stringify(fruit.pieces);
      var pattern = fruit.pattern;

      fruit.reset();
      setVariation({ shape: 0, tearSeed: 0.5 });
      verify(fruit.beginPeel(0, 100, 62));
      compare(fruit.pattern, pattern);
      verify(JSON.stringify(fruit.pieces) !== layout);
    }
    function test_bottom_grab_only_opens_near_the_hand() {
      setVariation({ shape: 0, rind: 0, stem: 0, tearSeed: 0.25 });
      var grab = pixel(100, 153), end = pixel(100, 135);
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      waitForRendering(fruit);
      var before = grabImage(fruit);
      mouseMove(fruit, end.x, end.y);
      verify(waitForRendering(fruit));
      var after = grabImage(fruit);
      mouseRelease(fruit, end.x, end.y, Qt.LeftButton);
      function changed(x, y) {
        var at = pixel(x, y);
        var px = Math.round(at.x), py = Math.round(at.y);
        return !Qt.colorEqual(before.pixel(px, py), after.pixel(px, py));
      }
      var localChanges = 0;
      for (var x = 90; x <= 110; x++)
        for (var y = 127; y <= 157; y++) if (changed(x, y)) localChanges++;
      verify(localChanges > 8, "The renderer must draw a visible opening at the bottom grab");
      for (var x = 84; x <= 128; x += 2)
        for (var y = 28; y <= 85; y += 2)
          verify(!changed(x, y), "The leaf and upper rind must stay still on first lift at " + x + ", " + y);
    }
    function test_grab_then_sweep_data() {
      return [{ tag: "bottom", x: 100, y: 153, dx: 0, dy: -1 },
        { tag: "top", x: 100, y: 62, dx: 0, dy: 1 },
        { tag: "left", x: 39, y: 108, dx: 1, dy: 0 },
        { tag: "right", x: 160, y: 108, dx: -1, dy: 0 }];
    }
    function test_grab_then_sweep(row) {
      setVariation({ shape: 0, rind: 0, stem: 0, tearSeed: 0.25 });
      var grab = pixel(row.x, row.y);
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      for (var distance of [8, 13, 18, 22, 44]) {
        var cursor = pixel(row.x + distance * row.dx, row.y + distance * row.dy);
        mouseMove(fruit, cursor.x, cursor.y);
        var frame = fruit.peelFrame;
        verify(frame !== null);
        if (distance === 8) {
          verify(frame.exposedPoints.every(p => Math.hypot(p[0] - row.x, p[1] - row.y) < 8));
          if (row.tag === "bottom") compare(frame.crownLift, 0);
        }
        verify(Math.hypot(frame.tip[0] - row.x - distance * row.dx,
          frame.tip[1] - row.y - distance * row.dy) < 2);
        if (distance <= 18) wait(90);
      }
      compare(fruit.pattern, Model.wholeRindPattern);
      var side = pixel(row.x - 44 * row.dy, row.y + 44 * row.dx);
      mouseMove(fruit, side.x, side.y);
      verify(Math.hypot(fruit.peelFrame.tip[0] - row.x + 44 * row.dy,
        fruit.peelFrame.tip[1] - row.y - 44 * row.dx) < 5);
      mouseRelease(fruit, side.x, side.y, Qt.LeftButton);
      compare(fruit.peeledMask, 0);
    }
    function test_slow_pull_can_peel_whole_rind_data() {
      return [{ tag: "side", margins: 0, shape: 0, x: 75, y: 108, dx: -1, dy: 0 },
        { tag: "crown_compact", margins: 145, shape: 1, x: 103, y: 76, dx: 0, dy: -1 }];
    }
    function test_slow_pull_can_peel_whole_rind(data) {
      fruit.anchors.margins = data.margins;
      setVariation({ shape: data.shape });
      function pointAt(distance) {
        return pixel(data.x + data.dx * distance, data.y + data.dy * distance);
      }
      function startSlowly() {
        for (var distance of [7, 12, 17, 22]) {
          var point = pointAt(distance);
          mouseMove(fruit, point.x, point.y);
          if (distance < 22) wait(85);
        }
        compare(fruit.pattern, Model.wholeRindPattern);
        verify(!fruit.pullPose.ready);
      }
      var grab = pointAt(0), shortPull = pointAt(22), normalPull = pointAt(61), longPull = pointAt(78);

      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      startSlowly();
      mouseRelease(fruit, shortPull.x, shortPull.y, Qt.LeftButton);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);

      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      wait(260);
      mouseMove(fruit, normalPull.x, normalPull.y);
      mouseRelease(fruit, normalPull.x, normalPull.y, Qt.LeftButton);
      verify(fruit.pattern !== Model.wholeRindPattern);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);

      fruit.reset();
      setVariation({ shape: data.shape });
      fruit.animationDuration = 160;
      mousePress(fruit, grab.x, grab.y, Qt.LeftButton);
      startSlowly();
      mouseMove(fruit, normalPull.x, normalPull.y);
      verify(!fruit.pullPose.ready);
      mouseMove(fruit, longPull.x, longPull.y);
      verify(fruit.pullPose.ready);
      verify(!fruit.fullyPeeled);
      var reverse = pointAt(-78);
      mouseMove(fruit, grab.x, grab.y);
      mouseMove(fruit, reverse.x, reverse.y);
      compare(fruit.peelProgress, 0);
      verify(!fruit.pullPose.ready);
      mouseMove(fruit, longPull.x, longPull.y);
      verify(fruit.pullPose.ready);
      mouseRelease(fruit, longPull.x, longPull.y, Qt.LeftButton);
      tryCompare(fruit, "fullyPeeled", true);
      tryCompare(fruit, "busy", false);
      compare(fruit.landed.length, 1);
      compare(fruit.remaining, 8);
      var slice = pixel(122, 76);
      mouseClick(fruit, slice.x, slice.y, Qt.LeftButton);
      compare(fruit.remaining, 7);
    }
    function test_cancelled_start_can_choose_another_pattern() {
      verify(fruit.beginPeel(0, 100, 62));
      var layout = JSON.stringify(fruit.pieces);
      fruit.animatePeel(0);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);
      verify(fruit.beginPeel(0, 100, 62));
      compare(JSON.stringify(fruit.pieces), layout);
      fruit.animatePeel(0);
      pullFrom(36, 108, 70);
      compare(fruit.pattern, 0);
    }
    function test_pattern_locks_after_first_piece() {
      pullFrom(100, 62, 70);
      compare(fruit.pattern, 1);
      var layout = JSON.stringify(fruit.pieces);
      var index = 0;
      while (fruit.peeledMask & (1 << index)) index++;
      var piece = fruit.pieces[index];
      pullFrom(piece.cx, piece.cy, 70);
      compare(fruit.pattern, 1);
      verify(Math.abs(fruit.startPoint.x - 100) < 1);
      verify(Math.abs(fruit.startPoint.y - 62) < 1);
      compare(JSON.stringify(fruit.pieces), layout);
      compare(fruit.peelRemaining, fruit.pieces.length - 2);
    }
    function test_keyboard_peels_and_eats() {
      mouseMove(fruit, 5, 5);
      compare(fruit.hintKey, "peelHint");
      fruit.moveCursor(1);
      compare(fruit.keyboardIndex, 0);
      compare(fruit.hintKey, "keyboardPeelHint");
      fruit.moveCursor(1);
      fruit.keyboardAction();
      compare(fruit.pattern, 0);
      compare(fruit.peelRemaining, fruit.pieces.length - 1);
      for (var i = fruit.peelRemaining; i > 0; i--) fruit.keyboardAction();
      verify(fruit.fullyPeeled);
      compare(fruit.hintKey, "keyboardEatHint");
      fruit.moveCursor(1);
      compare(fruit.keyboardIndex, 4);
      fruit.keyboardAction();
      compare(fruit.eaten, 1 << 4);
      fruit.moveCursor(1);
      compare(fruit.keyboardIndex, 0);
      fruit.keyboardAction();
      compare(fruit.eaten, (1 << 4) | 1);
      var target = pixel(115, 110);
      mouseMove(fruit, target.x, target.y);
      compare(fruit.hintKey, "eatHint");
      fruit.reset();
      compare(fruit.keyboardIndex, -1);
      compare(fruit.remaining, 8);
      compare(completion.count, 0);
    }
    function test_outside_click_leaves_rind_undecided() {
      mouseClick(fruit, 5, 5, Qt.LeftButton);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);
    }

    function test_first_bite_keeps_distant_wedge_shading() {
      setVariation({ shape: 0 });
      expose();
      mouseMove(fruit, 5, 5);
      waitForRendering(fruit);
      var before = grabImage(fruit), sample = pixel(46, 110);
      var x = Math.round(sample.x * before.width / fruit.width);
      var y = Math.round(sample.y * before.height / fruit.height);
      var bite = pixel(115, 110);
      mouseClick(fruit, bite.x, bite.y, Qt.LeftButton);
      compare(fruit.remaining, 7);
      waitForRendering(fruit);
      var after = grabImage(fruit);
      verify(before.red(x, y) > before.blue(x, y) + 60);
      compare(after.red(x, y), before.red(x, y));
      compare(after.green(x, y), before.green(x, y));
      compare(after.blue(x, y), before.blue(x, y));
    }

    function test_joined_flesh_covers_gap_and_accepts_click() {
      setVariation({ shape: 2 });
      expose();
      var p = pixel(101, 145);
      verify(fruit.hitAt(p.x, p.y) >= 0);
      waitForRendering(fruit);
      var image = grabImage(fruit);
      var x = Math.round(p.x * image.width / fruit.width);
      var y = Math.round(p.y * image.height / fruit.height);
      verify(image.red(x, y) > image.blue(x, y) + 65);
      mouseClick(fruit, p.x, p.y, Qt.LeftButton);
      compare(fruit.remaining, Model.segments - 1);
    }

    function test_isolated_wedges_keep_solid_clickable_flesh() {
      setVariation({ shape: 0 });
      expose();
      for (var i = 0; i < Model.segments; i++) {
        fruit.eaten = Model.all ^ (1 << i);
        var target = pixel([42, 82, 115, 156][i % 4], 110);
        compare(fruit.hitAt(target.x, target.y), i);
        waitForRendering(fruit);
        var image = grabImage(fruit);
        var x = Math.round(target.x * image.width / fruit.width);
        var y = Math.round(target.y * image.height / fruit.height);
        verify(image.red(x, y) > image.blue(x, y) + 60, "The remaining wedge must render under its mouse target");
        mouseClick(fruit, target.x, target.y, Qt.LeftButton);
        compare(fruit.remaining, 0);
      }
    }

    function test_pixel_art_keeps_visual_hit_alignment_data() {
      return [
        { tag: "full-light", margin: 0, variant: 0, background: "#eef2f6" },
        { tag: "full-dark", margin: 0, variant: 1, background: "#10141c" },
        { tag: "compact-light", margin: 130, variant: 2, background: "#eef2f6" },
        { tag: "compact-dark", margin: 130, variant: 3, background: "#10141c" }
      ];
    }
    function test_pixel_art_keeps_visual_hit_alignment(row) {
      testSurface.color = row.background;
      fruit.anchors.margins = row.margin;
      setVariation({ shape: row.variant });
      verify(waitForRendering(testSurface));
      var image = grabImage(testSurface);
      verify(Qt.colorEqual(image.pixel(5, 5), row.background));
      var targets = [pixel(35, 108), pixel(165, 108)];
      for (var i = 0; i < targets.length; i++) {
        var p = targets[i];
        verify(fruit.hitAt(p.x, p.y) >= 0);
        var screenPoint = fruit.mapToItem(testSurface, p.x, p.y);
        var x = Math.round(screenPoint.x * image.width / testSurface.width);
        var y = Math.round(screenPoint.y * image.height / testSurface.height);
        verify(image.red(x, y) > image.blue(x, y) + 70, "The visible rind must cover its mouse targets");
      }
    }

    function test_compact_popup_preserves_pointer_targets() {
      fruit.anchors.margins = 130;
      setVariation({ shape: 2 });
      verify(fruit.artScale < 0.6);
      expose();
      var target = pixel(115, 110);
      compare(fruit.hitAt(Math.round(target.x), Math.round(target.y)), 6);
      mouseClick(fruit, target.x, target.y, Qt.LeftButton);
      compare(fruit.eaten, 1 << 6);
      compare(fruit.remaining, 7);
    }

  }
}
