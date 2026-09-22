pragma Singleton
import QtQuick
QtObject {
  property color background: "#101510"
  property color foreground: "#ececec"
  property color accent: "#36ab23"
  property color urgent: "#ff6666"
  property var popups: ({text:foreground})
}
