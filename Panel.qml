import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "FruitModel.js" as Model

Ui.Panel {
  id: root
  moduleName: "droggokid.perpetual-clementine"
  manageIpc: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    iconComponent: Component { Icon {} }
    tooltipText: strings.t("title")
    active: root.opened
    onPressed: root.toggle()
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: Ui.PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: {
        if (fruit.gesture !== "") fruit.cancelGesture();
        else root.close();
      }
      onMoveRequested: function(dx, dy) { fruit.moveCursor(dx !== 0 ? dx : dy); }
      onActivateRequested: fruit.keyboardAction()
      onTabRequested: function(direction) { root.switchPanel(direction); }
      onTextKey: function(text, modifiers) { if (text.toLowerCase() === "r") fruit.reset(); }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: strings.t("title")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: strings.t("subtitle")
          color: Qt.darker(Commons.Color.foreground, 1.45)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Item {
          width: parent.width
          height: Math.max(Style.space(150), Math.min(Style.space(225), panel.availableCardHeight - Style.space(220)))

          Clementine {
            id: fruit
            anchors.fill: parent
            interactive: root.opened
            animationDuration: Style.duration(220)
            accessibleName: strings.t("title")
            accessibleDescription: strings.t("keyboard")
          }

          Text {
            anchors.centerIn: parent
            visible: fruit.remaining === 0 && !fruit.busy
            textFormat: Text.PlainText
            text: strings.t("finished")
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: fruit.selected ? strings.tn("selected", Model.count(fruit.selected)).arg(Commons.I18n.formatNumber(Model.count(fruit.selected)))
            : fruit.fullyPeeled ? strings.tn("remaining", fruit.remaining).arg(Commons.I18n.formatNumber(fruit.remaining))
            : strings.tn("peels", fruit.peelRemaining).arg(Commons.I18n.formatNumber(fruit.peelRemaining))
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter

        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: fruit.fullyPeeled ? strings.t("eatHint") : strings.t("peelHint")
          color: Qt.darker(Commons.Color.foreground, 1.45)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Ui.Button {
          width: parent.width
          text: strings.t("fresh")
          bordered: true
          onClicked: fruit.reset()
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: strings.t("keyboardHint")
          color: Qt.darker(Commons.Color.foreground, 1.65)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
