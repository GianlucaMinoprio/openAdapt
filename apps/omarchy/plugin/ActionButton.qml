import QtQuick
import QtQuick.Controls

Button {
  id: root
  property color ink: "#e2e8e5"
  property color accent: "#9bdacb"
  property bool emphasized: false
  property bool compact: false
  property string family: "sans-serif"
  implicitHeight: compact ? 30 : 38
  implicitWidth: Math.max(compact ? 50 : 96, label.implicitWidth + 24)
  hoverEnabled: true
  activeFocusOnTab: true
  Accessible.name: text
  background: Rectangle {
    radius: 9
    color: root.emphasized ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,root.down ? 0.27 : 0.16)
                          : Qt.rgba(root.ink.r,root.ink.g,root.ink.b,root.hovered ? 0.12 : 0.055)
    border.width: root.activeFocus ? 2 : 1
    border.color: root.activeFocus ? root.accent : Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.10)
    opacity: root.enabled ? 1 : 0.4
  }
  contentItem: Text {
    id: label
    text: root.text
    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: root.emphasized ? root.accent : root.ink
    opacity: root.enabled ? 1 : 0.35
    font.family: root.family
    font.pixelSize: 12
    font.weight: root.emphasized ? Font.DemiBold : Font.Medium
  }
}
