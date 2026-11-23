import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "session"

Ui.Panel {
  id: root
  moduleName: "droggokid.perpetual-clementine"
  manageIpc: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property var strings: ClementineSession.strings
  readonly property var fruit: ClementineSession.fruit

  function syncFruit() {
    if (opened && panel.loadedContent) ClementineSession.attach(root, panel.loadedContent.fruitHost);
    else ClementineSession.release(root);
  }

  onOpenedChanged: syncFruit()
  Component.onDestruction: if (ClementineSession) ClementineSession.release(root)

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    iconComponent: Component {
      Icon {
        monochrome: ClementineSession.monochromeIcon
        monochromeColor: button.foreground
      }
    }
    tooltipText: strings.t("title")
    active: root.opened
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) ClementineSession.monochromeIcon = !ClementineSession.monochromeIcon;
      else root.toggle();
    }
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)
    onLoadedContentChanged: root.syncFruit()

    content: Ui.PanelKeyCatcher {
      property alias fruitHost: artwork
      implicitHeight: column.implicitHeight
      onCloseRequested: {
        if (fruit && fruit.gesture !== "") fruit.cancelGesture();
        else root.close();
      }
      onMoveRequested: function(dx, dy) { if (fruit) fruit.moveCursor(dx !== 0 ? dx : dy); }
      onActivateRequested: if (fruit) fruit.keyboardAction()
      onTabRequested: function(direction) { root.switchPanel(direction); }
      onTextKey: function(text, modifiers) {
        if (fruit && text.toLowerCase() === "r" && !(modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
          fruit.reset();
      }

      component Caption: Text {
        width: parent.width
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Commons.Color.popups.text
      }

      Flickable {
        id: viewport
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        interactive: contentHeight > height
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: column
          width: viewport.width
          spacing: Style.space(4)

          Item {
            id: heading
            width: column.width
            height: Math.max(title.height, fresh.height)

            Caption {
              id: title
              anchors.centerIn: parent
              width: Math.max(1, heading.width - 2 * (fresh.width + Style.space(4)))
              text: strings.t("title")
              font.pixelSize: Style.font.subtitle
              font.weight: Font.DemiBold
            }
            Ui.Button {
              id: fresh
              anchors.right: parent.right
              anchors.top: parent.top
              width: Style.space(24)
              height: width
              horizontalPadding: 0
              verticalPadding: 0
              iconText: "↻"
              iconSize: Style.font.body
              foreground: Commons.Color.popups.text
              opacity: hot ? 1 : 0.68
              tooltipText: strings.t("freshFruit")
              Accessible.role: Accessible.Button
              Accessible.name: tooltipText
              Accessible.onPressAction: fresh.clicked()
              onClicked: if (fruit) fruit.reset()
            }
          }

          Caption {
            id: hint
            text: strings.t(fruit && fruit.fullyPeeled ? "eatHint" : "peelHint")
            font.pixelSize: Style.font.caption
            opacity: !fruit || fruit.remaining > 0 ? 0.70 : 0
          }

          Item {
            id: artwork
            width: column.width
            readonly property real preferredHeight: Style.space(234)
            readonly property real captionHeight: heading.height + hint.height + quip.height + total.height
              + column.spacing * 4
            height: panel.availableCardHeight > 0
              ? Math.min(preferredHeight, Math.max(Style.space(96),
                panel.availableCardHeight - panel.verticalContentInset - captionHeight))
              : preferredHeight

            Caption {
              anchors.centerIn: parent
              visible: !!fruit && fruit.remaining === 0 && !fruit.busy
              text: strings.t("finished")
            }
          }

          Caption {
            id: quip
            text: ClementineSession.quip
            opacity: !fruit || fruit.remaining > 0 ? 0.78 : 0
          }
          Caption {
            id: total
            text: strings.tn("eatenTotal", FruitCounter.total).arg(Commons.I18n.formatNumber(FruitCounter.total))
            font.pixelSize: Style.font.caption
            opacity: 0.68
          }
        }
      }
    }
  }
}
