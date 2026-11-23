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
      fruit.interactive = true;
      fruit.reset();
    }
    function pixel(x, y) {
      return Qt.point(fruit.centerX + (x - 100) * fruit.artScale,
        fruit.centerY + (y - 100) * fruit.artScale);
    }
    function expose() {
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
      compare(fruit.peelRemaining, count - 1);
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
      var count = fruit.peelRemaining;
      fruit.animationDuration = 80;
      fruit.keyboardAction();
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
    function test_finish_and_new_pattern() {
      expose();
      for (var i = 0; i < 8; i++) fruit.keyboardAction();
      compare(fruit.remaining, 0);
      var previous = fruit.pattern;
      fruit.reset();
      verify(fruit.pattern !== previous);
      compare(fruit.remaining, 8);
      verify(fruit.peelRemaining >= 3 && fruit.peelRemaining <= 5);
    }
  }
}
