import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "plugin" as Plugin
import "plugin/session" as Shared

// Run as shell.qml in a scratch Quickshell config with this repo at plugin/
// and Omarchy's Commons/ and Ui/ alongside it. Use a temporary XDG_STATE_HOME.
ShellRoot {
  FloatingWindow {
    screen: Quickshell.screens[0]
    implicitWidth: 300; implicitHeight: 360
    Item { id: leftHost; anchors.fill: parent }
  }
  FloatingWindow {
    screen: Quickshell.screens[1] || Quickshell.screens[0]
    implicitWidth: 300; implicitHeight: 360
    Item { id: rightHost; anchors.fill: parent }
  }

  function verify(condition, message) {
    if (!condition) throw new Error(message);
  }

  FileView {
    id: savedCounter
    path: Plugin.FruitCounter.location
    blockLoading: true
    printErrors: false
  }

  Timer {
    interval: 100
    running: true
    onTriggered: {
      try {
        Commons.Style.reduceMotion = true;
        var factory = Qt.createComponent(Qt.resolvedUrl("plugin/Panel.qml"));
        verify(factory.status === Component.Ready, factory.errorString());
        var left = factory.createObject(leftHost, { width: 24, height: 24 });
        var right = factory.createObject(rightHost, { width: 24, height: 24 });
        verify(left && right, "Both bar widgets should load");

        var session = Shared.ClementineSession;
        verify(!session.fruit, "The fruit should load on first open");
        left.open();
        var fruit = session.fruit;
        verify(fruit && fruit.interactive && fruit.width > 0, "The first popup should show the fruit");
        var leftArtwork = fruit.parent;
        var quote = session.quip;
        verify(quote !== session.quipKeys[session.quipIndex], "The quote should be translated");
        var leftButton = left.children.find(child => child.triggerPress);
        var rightButton = right.children.find(child => child.triggerPress);
        var leftIcon = iconIn(leftButton);
        var rightIcon = iconIn(rightButton);
        leftButton.triggerPress(Qt.RightButton);
        verify(leftIcon.monochrome && rightIcon.monochrome, "Both icons should switch to monochrome");
        rightButton.triggerPress(Qt.RightButton);
        verify(!leftIcon.monochrome && !rightIcon.monochrome, "Either icon can restore color on both bars");

        fruit.keyboardAction();
        verify(fruit.peeledMask !== 0, "A keyboard peel should detach a piece");
        var peeled = fruit.peeledMask;
        right.open();
        verify(!left.opened && right.opened && fruit.parent !== leftArtwork, "Opening the second popup should move the artwork");
        verify(right.fruit === fruit && fruit.peeledMask === peeled && session.quip === quote,
          "The other popup should use the same fruit, peel progress, and quote");
        left.destroy();
        right.close();
        verify(!fruit.interactive, "Closing the active popup should pause play");
        right.open();
        verify(fruit.interactive && fruit.peeledMask === peeled, "Closing and reopening should retain progress");

        var previousTotal = Plugin.FruitCounter.total;
        for (var i = fruit.peelRemaining; i > 0; i--) fruit.keyboardAction();
        for (var j = fruit.remaining; j > 0; j--) fruit.keyboardAction();
        verify(Plugin.FruitCounter.total === previousTotal + 1, "Finishing the shared fruit should count once");
        savedCounter.reload();
        verify(savedCounter.text().split("\n").includes("total=" + (previousTotal + 1)),
          "The lifetime total should be written to disk");
        fruit.reset();
        verify(fruit.remaining === 8 && Plugin.FruitCounter.total === previousTotal + 1,
          "A fresh fruit should keep the lifetime total");
        console.log("Shell smoke checks passed");
        Qt.quit();
      } catch (error) {
        console.error(error);
        Qt.exit(1);
      }
    }
  }

  function iconIn(item) {
    if (!item) return null;
    if ("monochrome" in item) return item;
    for (var child of item.children) {
      var icon = iconIn(child);
      if (icon) return icon;
    }
    return null;
  }
}
