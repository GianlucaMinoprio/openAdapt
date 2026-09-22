import QtQuick
import qs.Commons

Column {
  id: root
  property var pairs: []
  property bool loaded: true
  property bool busy: false
  property bool connected: false
  property bool bothConnected: true
  property color ink: Color.popups.text
  property color accent: Color.accent
  property string family: Style.font.family
  signal connectRequested(string pairId)
  signal openRequested()
  signal newRequested()
  signal disconnectRequested()
  spacing: Style.spacing.lg

  Repeater {
    model: root.loaded ? root.pairs : []
    delegate: ActionButton {
      id: card
      required property var modelData
      objectName: "connect-" + modelData.id
      width: root.width; height: Style.space(76)
      ink: root.ink; accent: root.accent; family: root.family
      enabled: !root.busy && modelData.connectable
      emphasized: modelData.selected
      Accessible.name: modelData.name + ", " + stateLabel.text
      tooltipText: modelData.name
      onClicked: {
        if (modelData.selected && root.connected && root.bothConnected) root.openRequested();
        else root.connectRequested(modelData.id);
      }
      ShoeMark { x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; width: Style.space(44); height: width; ink: root.accent; lampInk: "white" }
      Column {
        x: Style.space(68); anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - Style.space(88); spacing: Style.spacing.sm
        AppText { width: parent.width; text: card.modelData.name; wrapMode: Text.NoWrap; elide: Text.ElideRight; font.pixelSize: Style.font.subtitle }
        AppText { id: stateLabel; width: parent.width; text: !card.modelData.connectable ? "Setup not verified" : (card.modelData.selected && root.connected ? (root.bothConnected ? "Connected" : "One shoe connected") : "Not connected"); opacity: 0.7; font.pixelSize: Style.font.bodySmall }
      }
      AppText { anchors.right: parent.right; anchors.rightMargin: Style.space(14); anchors.verticalCenter: parent.verticalCenter; text: card.modelData.selected && root.connected && root.bothConnected ? "Open" : "Connect" }
    }
  }
  Column {
    visible: root.pairs.length === 0; width: root.width; spacing: Style.spacing.lg
    ShoeMark { width: Style.space(92); height: width; anchors.horizontalCenter: parent.horizontalCenter; ink: root.accent; lampInk: "white" }
    AppText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.loaded ? "Your shoes start here" : "Loading your shoes…"; font.pixelSize: Style.font.title }
  }
  ActionButton {
    objectName: "disconnectShoes"; width: root.width; text: "Disconnect"; visible: root.connected
    enabled: root.loaded; onClicked: root.disconnectRequested()
  }
  ActionButton {
    objectName: "newShoes"; width: root.pairs.length ? root.width : Style.space(160); anchors.horizontalCenter: parent.horizontalCenter
    text: "+  New shoes"; emphasized: root.pairs.length === 0
    enabled: root.loaded && !root.busy; ink: root.ink; accent: root.accent; family: root.family
    onClicked: root.newRequested()
  }
}
