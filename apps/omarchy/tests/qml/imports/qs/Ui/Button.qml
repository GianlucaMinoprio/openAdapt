// Test-only adapter: QtTest cannot load Quickshell's statically linked plugin.
// The installed shell validates the actual qs.Ui controls separately.
import QtQuick
import QtQuick.Controls as C
import qs.Commons
Item {
  id: root
  property bool selected: false
  property bool bordered: true
  property bool focusable: true
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property real verticalPadding: Style.spacing.controlPaddingY
  property string tooltipText: ""
  signal hovered(bool inside)
  property string text: ""
  property string iconText: ""
  property real iconSize: Style.font.body
  signal clicked()
  activeFocusOnTab: focusable
  Keys.onSpacePressed: clicked()
  Keys.onReturnPressed: clicked()
  MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.hovered(true); onExited: root.hovered(false); onClicked: { root.forceActiveFocus(); root.clicked(); } }
  implicitWidth: label.implicitWidth + Style.space(24)
  Text { anchors.centerIn: parent; id: label; text: root.text || root.iconText; color: root.foreground; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: root.fontFamily; font.pixelSize: root.iconText ? root.iconSize : root.fontSize }
  Rectangle { z: -1; anchors.fill: parent; color: root.selected ? Qt.rgba(root.accent.r,root.accent.g,root.accent.b,0.16) : "transparent"; radius: Style.cornerRadius; border.color: root.activeFocus ? root.accent : Qt.rgba(root.foreground.r,root.foreground.g,root.foreground.b,0.3) }
}
