import QtQuick
import QtTest
import ".."

Item {
  width: 400
  height: 400

  Clementine {
    id: fruit
    anchors.fill: parent
    animationDuration: 0
  }

  TestCase {
    name: "Clementine"
    when: windowShown

    function init() {
      fruit.animationDuration = 0;
      fruit.renewDelay = 1400;
      fruit.interactive = true;
      fruit.reset();
    }
    function pixel(x, y) {
      return Qt.point(fruit.centerX + (x - 100) * fruit.artScale,
        fruit.centerY + (y - 100) * fruit.artScale);
    }
    function expose() {
      if (!fruit.patternChosen) fruit.keyboardAction();
      var count = fruit.peelRemaining;
      for (var i = 0; i < count; i++) fruit.keyboardAction();
      verify(fruit.fullyPeeled);
      compare(fruit.remaining, 8);
    }

    function test_pull_and_snapback() {
      var p = pixel(110, 110), count = fruit.peelRemaining;
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + 5, p.y + 5);
      mouseRelease(fruit, p.x + 5, p.y + 5, Qt.LeftButton);
      compare(fruit.peelRemaining, count);
      compare(fruit.peelProgress, 0);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + 80, p.y + 45);
      mouseRelease(fruit, p.x + 80, p.y + 45, Qt.LeftButton);
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
    function test_click_eats_one() {
      expose();
      var p = pixel(122, 76);
      verify(fruit.hitAt(p.x, p.y) >= 0);
      mouseClick(fruit, p.x, p.y, Qt.LeftButton);
      compare(fruit.remaining, 7);
    }
    function test_sweep_commits_on_release() {
      expose();
      var a = pixel(35, 118), b = pixel(165, 118);
      mousePress(fruit, a.x, a.y, Qt.LeftButton);
      mouseMove(fruit, b.x, b.y);
      compare(fruit.remaining, 8);
      verify(fruit.selected !== 0);
      mouseRelease(fruit, b.x, b.y, Qt.LeftButton);
      verify(fruit.remaining <= 6);
      compare(fruit.selected, 0);
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
      mouseMove(fruit, p.x + 30, p.y + 20);
      fruit.interactive = false;
      compare(fruit.activePeel, -1);
      compare(fruit.peelRemaining, count);
      compare(fruit.busy, false);
      mouseRelease(fruit, p.x + 30, p.y + 20, Qt.LeftButton);
    }
    function test_animation_finishes() {
      fruit.animationDuration = 80;
      fruit.keyboardAction();
      var count = fruit.pieces.length;
      verify(fruit.busy);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.peelRemaining, count - 1);
      compare(fruit.activePeel, -1);
      fruit.animationDuration = 0;
      while (!fruit.fullyPeeled) fruit.keyboardAction();
      fruit.animationDuration = 80;
      fruit.keyboardAction();
      verify(fruit.busy);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.remaining, 7);
      compare(fruit.fading, 0);
    }
    function test_finish_and_new_start() {
      expose();
      for (var i = 0; i < 8; i++) fruit.keyboardAction();
      compare(fruit.remaining, 0);
      var previous = fruit.variant;
      fruit.reset();
      verify(fruit.variant !== previous);
      verify(!fruit.patternChosen);
      compare(fruit.remaining, 8);
      compare(fruit.peelRemaining, 0);
    }
    function finishFruit() {
      expose();
      for (var i = 0; i < 8; i++) fruit.keyboardAction();
      compare(fruit.remaining, 0);
    }
    function test_progressive_fold() {
      var p = pixel(110, 110), count = fruit.peelRemaining;
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + 28, p.y + 14);
      verify(fruit.peelFrame !== null);
      verify(fruit.peelFrame.attached.length > 0);
      verify(fruit.peelFrame.underside.length > 0);
      verify(fruit.peelFrame.fibres.length > 0);
      compare(fruit.peelRemaining, fruit.pieces.length);
      compare(fruit.peeledMask, 0);
      fruit.cancelGesture();
      mouseRelease(fruit, p.x + 28, p.y + 14, Qt.LeftButton);
      compare(fruit.peelRemaining, count);
    }
    function test_fold_lands_in_its_own_shape() {
      fruit.animationDuration = 120;
      fruit.keyboardAction();
      tryVerify(function() { return fruit.dropping >= 0; }, 2000);
      var id = fruit.dropping, shape = fruit.dropFrame.underside;
      verify(shape.length > 0);
      tryCompare(fruit, "busy", false, 2000);
      compare(fruit.landed[id].underside, shape);
      compare(fruit.dropping, -1);
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
      fruit.keyboardAction();
      var mask = fruit.peeledMask;
      verify(mask !== 0);
      wait(140);
      compare(fruit.peeledMask, mask);
    }

    function pullFrom(x, y, distance) {
      var p = pixel(x, y);
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + distance, p.y + distance * 0.4);
      mouseRelease(fruit, p.x + distance, p.y + distance * 0.4, Qt.LeftButton);
    }
    function test_start_location_selects_pattern() {
      var starts = [[100, 62, 1], [36, 108, 0], [164, 108, 0], [100, 153, 2], [100, 108, 2]];
      for (var i = 0; i < starts.length; i++) {
        fruit.reset();
        verify(!fruit.patternChosen);
        pullFrom(starts[i][0], starts[i][1], 70);
        compare(fruit.pattern, starts[i][2]);
        compare(fruit.startPoint.x, starts[i][0]);
        compare(fruit.startPoint.y, starts[i][1]);
        compare(fruit.peelRemaining, fruit.pieces.length - 1);
      }
    }
    function test_cancelled_start_can_choose_another_pattern() {
      pullFrom(100, 62, 5);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);
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
      compare(fruit.startPoint.x, 100);
      compare(fruit.startPoint.y, 62);
      compare(JSON.stringify(fruit.pieces), layout);
      compare(fruit.peelRemaining, fruit.pieces.length - 2);
    }
    function test_keyboard_selects_start_before_peeling() {
      fruit.moveCursor(1);
      fruit.moveCursor(1);
      fruit.keyboardAction();
      compare(fruit.pattern, 0);
      compare(fruit.startPoint.x, 36);
    }
    function test_outside_click_leaves_rind_undecided() {
      mouseClick(fruit, 5, 5, Qt.LeftButton);
      verify(!fruit.patternChosen);
      compare(fruit.peeledMask, 0);
    }

    function test_pixel_art_keeps_visual_hit_alignment() {
      waitForRendering(fruit);
      var image = grabImage(fruit);
      var targets = [pixel(35, 108), pixel(165, 108)];
      for (var i = 0; i < targets.length; i++) {
        var p = targets[i];
        verify(fruit.hitAt(p.x, p.y) >= 0);
        var x = Math.round(p.x * image.width / fruit.width);
        var y = Math.round(p.y * image.height / fruit.height);
        verify(image.red(x, y) > image.blue(x, y) + 70, "The visible rind must cover its mouse targets");
      }
    }

  }
}
