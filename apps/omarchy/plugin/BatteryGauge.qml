import QtQuick
import qs.Commons

// A read-only battery silhouette: no slider handle, scale ticks, or input handler.
Column {
  id: root
  property string side: "left"
  property var percent: null
  property bool connected: false
  property string checked: "Not checked yet"
  spacing: Style.spacing.lg
  Accessible.role: Accessible.StaticText
  Accessible.name: side + " battery " + (percent === null ? "unknown" : percent + " percent") + ". " + checked
  AppText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.side === "left" ? "Left" : "Right" }
  AppText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.percent === null ? "—" : root.percent + "%"; font.pixelSize: Style.font.displayLarge; font.features: {"tnum":1} }
  Item {
    width: Style.space(60); height: Style.space(156); anchors.horizontalCenter: parent.horizontalCenter
    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: Style.space(24); height: Style.space(7); radius: Style.space(2); color: Color.popups.text; opacity: 0.6 }
    Rectangle {
      x: 0; y: Style.space(6); width: parent.width; height: parent.height - y
      radius: Style.space(8); color: "transparent"; border.width: Style.space(2); border.color: Color.popups.text; opacity: root.connected ? 0.75 : 0.4
      Rectangle {
        id: batteryFill
        x: Style.space(6); y: Style.space(6); width: parent.width - x * 2; height: parent.height - y * 2
        radius: Style.space(3)
        color: root.percent !== null && root.percent < 20 ? Color.urgent : Color.popups.text
        transform: Scale { origin.y: batteryFill.height; yScale: root.percent === null ? 0 : Math.max(0, Math.min(1, root.percent / 100)) }
      }
    }
  }
  AppText {
    width: parent.width; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Style.font.bodySmall; opacity: 0.7
    text: (root.connected ? "" : "Saved reading\n") + root.checked
  }
}
