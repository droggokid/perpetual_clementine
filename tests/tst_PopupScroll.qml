import QtQuick
import QtTest
import ".."

Rectangle {
  width: 240
  height: 180

  Flickable {
    id: viewport
    anchors.fill: parent
    contentWidth: width
    contentHeight: 400
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Clementine {
      id: fruit
      width: viewport.width
      height: 145
    }
  }

  TestCase {
    name: "PopupScroll"
    when: windowShown

    function test_drag_from_blank_artwork_scrolls() {
      compare(fruit.hitAt(8, 130), -1);
      mousePress(viewport, 8, 130, Qt.LeftButton);
      mouseMove(viewport, 8, 102, 20);
      mouseMove(viewport, 8, 65, 20);
      mouseMove(viewport, 8, 28, 20);
      var scroll = viewport.contentY;
      mouseRelease(viewport, 8, 28, Qt.LeftButton);
      verify(scroll > 0);
      verify(!fruit.patternChosen);
    }
  }
}
