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

    function init() { fruit.interactive = true; fruit.reset(); }

    function pointOnFruit() {
      for (var y = 130; y < 240; y += 10) {
        for (var x = 130; x < 270; x += 10) {
          var face = fruit.hitAt(x, y);
          if (face && face.kind === "peel") return Qt.point(x, y);
        }
      }
      fail("No visible peel surface");
      return Qt.point(200, 200);
    }

    function expose() {
      for (var i = 0; i < 10; i++) fruit.keyboardAction();
      verify(fruit.fullyPeeled);
      compare(fruit.remaining, 10);
    }

    function test_pull_and_snapback() {
      var p = pointOnFruit();
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + 10, p.y + 10);
      mouseRelease(fruit, p.x + 10, p.y + 10, Qt.LeftButton);
      compare(fruit.peelRemaining, 10);
      verify(fruit.peel.every(function(value) { return value === 0; }));
      mousePress(fruit, p.x, p.y, Qt.LeftButton);
      mouseMove(fruit, p.x + 100, p.y + 80);
      mouseRelease(fruit, p.x + 100, p.y + 80, Qt.LeftButton);
      compare(fruit.peelRemaining, 9);
      compare(fruit.remaining, 10);
    }

    function test_rotate_without_eating() {
      var before = fruit.yaw;
      mouseDrag(fruit, 200, 180, 70, 25, Qt.RightButton);
      verify(Math.abs(fruit.yaw - before) > 0.1);
      compare(fruit.peelRemaining, 10);
      compare(fruit.remaining, 10);
    }

    function test_click_eats_one() {
      expose();
      mouseClick(fruit, 210, 185, Qt.LeftButton);
      compare(fruit.remaining, 9);
    }

    function test_sweep_commits_on_release() {
      expose();
      mousePress(fruit, 110, 180, Qt.LeftButton);
      mouseMove(fruit, 290, 180);
      compare(fruit.remaining, 10);
      verify(fruit.selected !== 0);
      mouseRelease(fruit, 290, 180, Qt.LeftButton);
      verify(fruit.remaining <= 7);
      compare(fruit.selected, 0);
    }

    function test_cancel_and_close() {
      expose();
      mousePress(fruit, 210, 185, Qt.LeftButton);
      verify(fruit.selected !== 0);
      fruit.cancelGesture();
      mouseRelease(fruit, 210, 185, Qt.LeftButton);
      compare(fruit.remaining, 10);
      compare(fruit.selected, 0);
      mousePress(fruit, 210, 185, Qt.LeftButton);
      fruit.interactive = false;
      compare(fruit.gesture, "");
      compare(fruit.remaining, 10);
      mouseRelease(fruit, 210, 185, Qt.LeftButton);
    }

    function test_finish_and_reset() {
      expose();
      for (var i = 0; i < 10; i++) fruit.keyboardAction();
      compare(fruit.remaining, 0);
      compare(fruit.faces.length, 0);
      fruit.reset();
      compare(fruit.remaining, 10);
      compare(fruit.peelRemaining, 10);
    }
  }
}
