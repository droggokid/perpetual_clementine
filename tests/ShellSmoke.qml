import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Run as shell.qml in a scratch Quickshell config with Omarchy's Commons/ and Ui/.
// Place the repo at plugin/ or set CLEMENTINE_SMOKE_PLUGIN_DIR. Use a temporary XDG_STATE_HOME.
ShellRoot {
  id: smoke

  readonly property string pluginDir: Quickshell.env("CLEMENTINE_SMOKE_PLUGIN_DIR") || Quickshell.shellDir + "/plugin"
  readonly property string expectedLanguage: Quickshell.env("CLEMENTINE_SMOKE_LANGUAGE")
  readonly property string languagePath: Quickshell.env("CLEMENTINE_SMOKE_LANGUAGE_PATH")
  readonly property string swaySocket: Quickshell.env("CLEMENTINE_SMOKE_SWAY_SOCKET")
  property var pendingCheck: null
  PanelWindow {
    screen: Quickshell.screens[0]
    anchors.top: true
    anchors.left: true
    implicitWidth: 300; implicitHeight: 36
    exclusionMode: ExclusionMode.Ignore
    Item { id: leftHost; anchors.fill: parent }
  }
  PanelWindow {
    id: rightWindow
    screen: Quickshell.screens[1] || Quickshell.screens[0]
    visible: rightHost.active
    anchors.top: true
    anchors.left: true
    implicitWidth: 300; implicitHeight: 36
    exclusionMode: ExclusionMode.Ignore
    Loader {
      id: rightHost
      anchors.fill: parent
      active: !smoke.swaySocket || Quickshell.screens.length > 1
      sourceComponent: Item {}
    }
  }

  function verify(condition, message) {
    if (!condition) throw new Error(message);
  }
  function fail(error) {
    console.error(error);
    Qt.exit(1);
  }
  function finish() {
    console.log("Shell smoke checks passed");
    Qt.quit();
  }
  function eventually(message, ready, next) {
    pendingCheck = { message: message, ready: ready, next: next, deadline: Date.now() + 4000 };
    updates.restart();
  }

  Timer {
    id: updates
    interval: 25
    repeat: true
    onTriggered: {
      try {
        var check = smoke.pendingCheck;
        if (check.ready()) {
          stop();
          smoke.pendingCheck = null;
          check.next();
        } else smoke.verify(Date.now() < check.deadline, check.message);
      } catch (error) {
        stop();
        smoke.fail(error);
      }
    }
  }

  FileView {
    id: savedCounter
    path: Quickshell.env("XDG_STATE_HOME") + "/omarchy/droggokid.perpetual-clementine.ini"
    blockAllReads: true
    printErrors: false
  }

  FileView {
    id: languageCatalog
    path: smoke.expectedLanguage ? smoke.pluginDir + "/i18n/" + smoke.expectedLanguage + ".json" : ""
    blockAllReads: true
  }

  FileView {
    id: languageOverride
    path: smoke.languagePath
    blockWrites: true
    onSaveFailed: smoke.fail("Could not change the test language");
  }

  Process {
    id: disableOutput
    onExited: function(code) {
      if (code !== 0) smoke.fail("Could not disable the test output: swaymsg exited " + code);
    }
  }

  Test.TestEvent { id: input }

  Process {
    id: sendKeys
    command: ["wtype", "-s", "150", "-k", "Right", "-k", "Return", "-s", "75", "-k", "Escape"]
    onExited: function(code) {
      if (code !== 0) smoke.fail("Could not send test keys: wtype exited " + code);
    }
  }

  Timer {
    interval: 100
    running: true
    onTriggered: {
      try {
        Commons.Style.reduceMotion = true;
        var factory = Qt.createComponent(Commons.Util.fileUrl(smoke.pluginDir + "/Panel.qml"));
        verify(factory.status === Component.Ready, factory.errorString());
        var left = factory.createObject(leftHost, { width: 24, height: 24 });
        verify(rightHost.item, "The Wayland smoke test should have a second output");
        var right = factory.createObject(rightHost.item, { width: 24, height: 24 });
        verify(left && right, "Both bar widgets should load");

        verify(!left.fruit && !right.fruit, "The fruit should load on first open");
        clickBarItem(left);
        var fruit = left.fruit;
        verify(fruit && fruit.interactive && fruit.width > 0, "The first popup should show the fruit");
        var leftArtwork = fruit.parent;
        var peelHint = left.strings.t("peelHint");
        verify(peelHint !== "peelHint", "The hint should be translated");
        var catalog = null;
        if (smoke.expectedLanguage) {
          catalog = JSON.parse(languageCatalog.text());
          verify(Commons.I18n.language === smoke.expectedLanguage, "The shell should load the test language");
          verify(peelHint === catalog.peelHint, "The peel hint should come from the selected language");
        }
        var leftButton = left.children.find(child => child.triggerPress);
        var rightButton = right.children.find(child => child.triggerPress);
        var leftIcon = findDescendant(leftButton, item => "monochrome" in item);
        var rightIcon = findDescendant(rightButton, item => "monochrome" in item);
        var initiallyMonochrome = leftIcon.monochrome;
        var expectedIcon = Quickshell.env("CLEMENTINE_SMOKE_EXPECT_ICON");
        verify(rightIcon.monochrome === initiallyMonochrome, "Both icons should start with the same style");
        if (expectedIcon)
          verify(initiallyMonochrome === (expectedIcon === "monochrome"), "The icon style should survive a shell restart");
        leftButton.triggerPress(Qt.RightButton);
        verify(leftIcon.monochrome === !initiallyMonochrome && rightIcon.monochrome === !initiallyMonochrome,
          "The first icon should switch both bars to the other style");
        rightButton.triggerPress(Qt.RightButton);
        verify(leftIcon.monochrome === initiallyMonochrome && rightIcon.monochrome === initiallyMonochrome,
          "The second icon should restore the original style on both bars");
        if (expectedIcon) rightButton.triggerPress(Qt.RightButton);

        fruit.keyboardAction();
        verify(fruit.peeledMask !== 0, "A keyboard peel should detach a piece");
        var peeled = fruit.peeledMask;
        right.open();
        verify(!left.opened && right.opened && fruit.parent !== leftArtwork, "Opening the second popup should move the artwork");
        verify(right.fruit === fruit && fruit.peeledMask === peeled,
          "The other popup should use the same fruit and peel progress");
        right.close();
        verify(!fruit.interactive, "Closing the active popup should pause play");
        right.open();
        verify(fruit.interactive && fruit.peeledMask === peeled, "Closing and reopening should retain progress");

        var column = fruit.parent.parent;
        var keyboardPeelHint = catalog ? catalog.keyboardPeelHint : right.strings.t("keyboardPeelHint");
        var hint = column.children.find(item => item.text === keyboardPeelHint);
        verify(hint && hint.opacity > 0, "The popup should show the keyboard peel hint before eating");
        var savedTotal = /^total=(\d+)$/m.exec(savedCounter.text());
        var previousTotal = savedTotal ? Number(savedTotal[1]) : 0;
        var expectedTotal = Quickshell.env("CLEMENTINE_SMOKE_EXPECT_TOTAL");
        if (expectedTotal)
          verify(previousTotal === Number(expectedTotal), "The test state should carry over between shell processes");
        function countText(count) {
          var translation = catalog ? catalog.eatenTotal[count === 1 ? "one" : "other"] : right.strings.tn("eatenTotal", count);
          return translation.arg(Commons.I18n.formatNumber(count));
        }
        var counter = column.children.find(item => item.text === countText(previousTotal));
        verify(counter, "The popup should show the saved clementine count");
        for (var i = fruit.peelRemaining; i > 0; i--) fruit.keyboardAction();
        verify(hint.text === (catalog ? catalog.keyboardEatHint : right.strings.t("keyboardEatHint")),
          "The popup should switch to the keyboard eat hint after the last peel");
        for (var j = fruit.remaining; j > 0; j--) fruit.keyboardAction();
        verify(counter.text === countText(previousTotal + 1), "The popup count should update after the last bite");
        verify(hint.opacity === 0, "The hint should be hidden during the completion pause");
        savedCounter.reload();
        verify(savedCounter.text().split("\n").includes("total=" + (previousTotal + 1)),
          "The lifetime total should be written to disk");
        var resetLabel = catalog ? catalog.freshFruit : right.strings.t("freshFruit");
        var resetButton = findDescendant(column, item => item.tooltipText === resetLabel && typeof item.clicked === "function");
        verify(resetButton, "The popup should have a localized reset button");
        resetButton.clicked();
        verify(fruit.remaining === 8 && counter.text === countText(previousTotal + 1),
          "A fresh fruit should keep the lifetime total");
        verify(hint.text === peelHint && hint.opacity > 0, "Reset should restore the peel hint");
        smoke.testPopupColors(hint, counter, resetButton);
        if (!smoke.languagePath) {
          smoke.finish();
          return;
        }

        fruit.keyboardAction();
        var mask = fruit.peeledMask;
        verify(mask !== 0, "There should be unfinished peel progress before live shell changes");
        var nextLanguage = Commons.I18n.language === "da" ? "en" : "da";
        languageCatalog.path = smoke.pluginDir + "/i18n/" + nextLanguage + ".json";
        var nextCatalog = JSON.parse(languageCatalog.text());
        var total = previousTotal + 1;
        var nextCounter = nextCatalog.eatenTotal[total === 1 ? "one" : "other"].arg(Commons.I18n.formatNumber(total));
        var nextHint = nextCatalog.keyboardPeelHint;
        languageOverride.setText(nextLanguage + "\n");
        smoke.eventually("The open popup should update after a live language switch", function() {
          return Commons.I18n.language === nextLanguage && hint.text === nextHint
            && resetButton.tooltipText === nextCatalog.freshFruit && counter.text === nextCounter;
        }, function() {
          verify(right.opened && right.fruit === fruit && fruit.peeledMask === mask,
            "Changing the language should keep the current fruit and peel progress");
          if (smoke.swaySocket) smoke.testInputRouting(left, right, fruit, mask, nextCounter);
          else smoke.finish();
        });
      } catch (error) {
        smoke.fail(error);
      }
    }
  }

  function testPopupColors(hint, counter, resetButton) {
    var original = Commons.Color.themeShellValues;
    try {
      for (var [background, text] of [["#eef2f6", "#172237"], ["#10141c", "#e3e8f2"]]) {
        Commons.Color.loadShell('[popups]\nbackground = "' + background + '"\ntext = "' + text + '"');
        verify(Qt.colorEqual(hint.color, text) && Qt.colorEqual(counter.color, text)
          && Qt.colorEqual(resetButton.foreground, text), "The open popup should follow the theme's text color");
      }
    } finally {
      Commons.Color.themeShellValues = original;
      Commons.Color.mergeShell();
    }
  }

  function clickBarItem(panel) {
    verify(input.mouseClick(panel, panel.width / 2, panel.height / 2, Qt.LeftButton, Qt.NoModifier, 0),
      "Qt should deliver a click to the bar window");
    verify(panel.opened, "Clicking the bar item should open the popup");
  }

  function testInputRouting(left, right, fruit, mask, countText) {
    right.close();
    clickBarItem(left);
    verify(left.fruit === fruit && fruit.peeledMask === mask, "Clicking the other bar should resume the same fruit");
    sendKeys.running = true;
    eventually("Arrow and Enter should peel in the focused popup, and Escape should close it", function() {
      return !left.opened && fruit.peeledMask !== mask;
    }, function() {
      clickBarItem(right);
      testOutputRemoval(left, right, fruit, fruit.peeledMask, countText);
    });
  }

  function testOutputRemoval(left, right, fruit, mask, countText) {
    verify(right.opened && rightWindow.screen.name === Quickshell.screens[1].name,
      "The active popup should be on the second output");
    disableOutput.command = ["swaymsg", "-q", "-s", swaySocket, "output", rightWindow.screen.name, "disable"];
    disableOutput.running = true;
    eventually("Disabling the second output should destroy its popup", function() {
      return Quickshell.screens.length === 1 && !rightHost.item && !fruit.interactive;
    }, function() {
      clickBarItem(left);
      verify(left.opened && fruit.interactive && left.fruit === fruit && fruit.peeledMask === mask,
        "Reopening after disconnect should recover the same fruit");
      verify(fruit.parent.parent.children.some(item => item.text === countText),
        "Reopening after disconnect should keep the lifetime total");
      finish();
    });
  }

  function findDescendant(item, predicate) {
    if (!item) return null;
    if (predicate(item)) return item;
    for (var child of item.children) {
      var match = findDescendant(child, predicate);
      if (match) return match;
    }
    return null;
  }
}
