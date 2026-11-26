pragma Singleton
import QtQuick
import qs.Commons as Commons
import ".."
import "QuipDeck.js" as QuipDeck

Item {
  id: session

  readonly property bool monochromeIcon: FruitCounter.monochromeIcon
  property Item activePanel: null
  property Item fruit: null
  property alias strings: translations
  readonly property double eatenTotal: FruitCounter.total

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
  property var remainingQuips: []
  property string quipKey: ""
  readonly property string quip: translations.t(quipKey)

  function advanceQuip() {
    var draw = QuipDeck.draw(quipKeys, remainingQuips, quipKey, Math.random);
    remainingQuips = draw.remaining;
    quipKey = draw.key;
  }

  function toggleIconStyle() {
    FruitCounter.saveIconStyle(!monochromeIcon);
  }

  Component.onCompleted: advanceQuip()

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
        session.advanceQuip();
      }
    }
  }
}
