import QtQuick
import QtQuick.Controls

Column {
  id: root
  property var pairs: []
  property bool loaded: true
  property bool busy: false
  property bool connected: false
  property color ink: "#e2e8e5"
  property color accent: "#36ab23"
  property string family: "sans-serif"
  signal connectRequested(string pairId)
  signal openRequested()
  signal newRequested()
  spacing: 14

  Text {
    visible: root.pairs.length > 0
    text: "Your shoes"; color:root.ink; font.family:root.family; font.pixelSize:14; font.weight:Font.Medium
  }
  Repeater {
    model: root.loaded ? root.pairs : []
    delegate: Rectangle {
      id: card
      required property var modelData
      width:root.width; height:86; radius:12
      color:Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.045)
      border.width:1; border.color:Qt.rgba(root.accent.r,root.accent.g,root.accent.b,0.18)
      ShoeMark { x:13; anchors.verticalCenter:parent.verticalCenter; width:42; height:42; ink:root.accent; lampInk:"#ffffff" }
      Column {
        x:68; anchors.verticalCenter:parent.verticalCenter; width:parent.width-176; spacing:6
        Text { text:card.modelData.name; textFormat:Text.PlainText; width:parent.width; elide:Text.ElideRight
          color:root.ink; font.family:root.family; font.pixelSize:14; font.weight:Font.DemiBold }
        Text { text:!card.modelData.connectable ? "Setup not verified" : (card.modelData.selected && root.connected ? "Connected" : "Left + right")
          color:Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.55); font.family:root.family; font.pixelSize:10 }
      }
      ActionButton {
        objectName:"connect-" + card.modelData.id
        anchors.right:parent.right; anchors.rightMargin:12; anchors.verticalCenter:parent.verticalCenter
        text:card.modelData.selected && root.connected ? "Open" : "Connect"
        compact:true; emphasized:true; ink:root.ink; accent:root.accent; family:root.family
        enabled:!root.busy && card.modelData.connectable
        onClicked: {
          if (card.modelData.selected && root.connected) root.openRequested();
          else root.connectRequested(card.modelData.id);
        }
      }
    }
  }
  Item {
    width:root.width; height:root.loaded && root.pairs.length > 0 ? 40 : 235
    Column {
      anchors.centerIn:parent; width:parent.width; spacing:15
      ShoeMark { visible:root.pairs.length === 0; width:62; height:62; anchors.horizontalCenter:parent.horizontalCenter; ink:root.accent; lampInk:"#ffffff" }
      Text { visible:root.pairs.length === 0; anchors.horizontalCenter:parent.horizontalCenter
        text:root.loaded ? "Your shoes start here" : "Loading your shoes…"
        color:root.ink; font.family:root.family; font.pixelSize:14 }
      ActionButton { objectName:"newShoes"; anchors.horizontalCenter:parent.horizontalCenter
        width:root.pairs.length > 0 ? root.width : 160
        text:"+  New shoes"; emphasized:root.pairs.length === 0
        enabled:root.loaded && !root.busy; ink:root.ink; accent:root.accent; family:root.family
        onClicked:root.newRequested() }
    }
  }
}
