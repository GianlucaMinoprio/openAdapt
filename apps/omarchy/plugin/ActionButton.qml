import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui as UI

UI.Button {
  id: root
  property color ink: Color.popups.text
  property string family: Style.font.family
  property bool emphasized: false
  property bool compact: false
  property bool pointerInside: false
  foreground: ink
  fontFamily: family
  selected: emphasized
  bordered: true
  focusable: true
  implicitHeight: Math.max(Style.space(compact ? 30 : 38), fontSize + verticalPadding * 2 + Style.space(4))
  opacity: enabled ? 1 : 0.4
  Accessible.role: Accessible.Button
  Accessible.name: text || tooltipText
  Accessible.onPressAction: if (enabled) clicked()
  onHovered: inside => pointerInside = inside
  // Native hover tooltip plus keyboard access to the same detail.
  ToolTip.visible: activeFocus && tooltipText !== ""
  ToolTip.text: tooltipText
}
