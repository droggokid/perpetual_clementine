pragma Singleton
import QtQuick
import qs.Commons as Commons
import ".."

Item {
  id: session

  property bool monochromeIcon: false
  property Item activePanel: null
  property Item fruit: null
  property alias strings: translations

  readonly property var quipKeys: [
    "peeled", "peeledWinter", "peeledRound", "peeledWitnesses",
    "peeledPortions", "peeledAgain",
    "peeledChat", "peeledMeeting", "peeledCouncil", "peeledVictory",
    "peeledMajesty", "peeledProphecy", "peeledDignity", "peeledComplaint",
    "peeledIncident", "peeledOrb", "peeledVitamin", "peeledControl",
    "peeledOperation", "peeledExecutable", "peeledEvidence", "peeledLunch",
    "peeledKingdom", "peeledSins", "peeledInnocent",
    "peeledGeneva", "peeledWork", "peeledCare", "peeledEnemies"
  ]
  property int quipIndex: Math.floor(Math.random() * quipKeys.length)
  readonly property string quip: translations.t(quipKeys[quipIndex])

  function attach(panel, host) {
    if (activePanel && activePanel !== panel) activePanel.close();
    // The session owns the fruit. Only its visual parent moves between popups.
    if (!fruit) fruit = fruitComponent.createObject(session);
    fruit.parent = host;
    activePanel = panel;
    fruit.interactive = true;
  }

  function release(panel) {
    if (activePanel !== panel) return;
    activePanel = null;
    if (fruit) fruit.interactive = false;
  }

  Commons.Translations { id: translations; directory: Qt.resolvedUrl("../i18n") }

  Component {
    id: fruitComponent

    Clementine {
      anchors.fill: parent
      interactive: false
      animationDuration: Commons.Style.duration(220)
      accessibleName: translations.t("title")
      accessibleDescription: translations.t("keyboardHelp")
      onFruitEaten: {
        FruitCounter.recordFruit();
        var next = Math.floor(Math.random() * (session.quipKeys.length - 1));
        session.quipIndex = next < session.quipIndex ? next : next + 1;
      }
    }
  }
}
