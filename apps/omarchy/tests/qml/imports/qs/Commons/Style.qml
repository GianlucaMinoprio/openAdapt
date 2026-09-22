pragma Singleton
import QtQuick
QtObject {
  id: root
  property real scale: 1
  property real cornerRadius: 6
  function space(value) { return Math.round(value * scale); }
  function normalFillFor(ink, accent) { return Qt.rgba(ink.r, ink.g, ink.b, 0.08); }
  property QtObject spacing: QtObject {
    property int xs: root.space(3)
    property int sm: root.space(4)
    property int lg: root.space(8)
    property int panelGap: root.space(14)
    property int controlPaddingX: root.space(10)
    property int controlPaddingY: root.space(6)
  }
  property QtObject font: QtObject {
    property string family: "monospace"
    property int body: root.space(12)
    property int bodySmall: root.space(11)
    property int subtitle: root.space(13)
    property int title: root.space(14)
    property int heading: root.space(16)
    property int displayLarge: root.space(28)
  }
}
