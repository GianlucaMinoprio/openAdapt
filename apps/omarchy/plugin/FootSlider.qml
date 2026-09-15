import QtQuick
import QtQuick.Controls
import "Model.js" as Model

Column {
  id: root
  property string side: "left"
  property int value: 0
  property int revision: 0
  property color ink: "#e2e8e5"
  property color accent: "#9bdacb"
  property string family: "sans-serif"
  property bool editing: true
  property bool connected: true
  property bool showBattery: false
  property var battery: null
  property string checked: ""
  property bool dirty: false
  readonly property real displayedValue: slider.value
  signal committed(int percent)
  width: 140
  spacing: 8
  onValueChanged: if (!slider.pressed) slider.value = Model.snap(value)
  onRevisionChanged: if (!slider.pressed) slider.value = Model.snap(value)
  onEditingChanged: if (!editing && dirty) {
    dirty = false;
    wheelCommit.stop();
    slider.value = root.value;
  }

  function commit() {
    if (!dirty || !editing) return;
    dirty = false;
    if (Model.snap(slider.value) !== root.value) committed(Model.snap(slider.value));
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.side === "left" ? "LEFT" : "RIGHT"
    color: Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.6)
    font.family: root.family; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.connected ? Math.round(slider.value) + "%" : "—"
    color: root.ink
    font.family: root.family; font.pixelSize: 30; font.weight: Font.Medium
  }
  Slider {
    id: slider
    objectName: root.side + "LacingSlider"
    anchors.horizontalCenter: parent.horizontalCenter
    orientation: Qt.Vertical
    from: 0; to: 100; stepSize: 5; snapMode: Slider.SnapAlways
    value: root.value
    live: true; wheelEnabled: true
    width: 92; height: 204
    topPadding: 9; bottomPadding: 9; leftPadding: 7; rightPadding: 7
    enabled: root.editing
    activeFocusOnTab: true
    Accessible.name: root.side + " shoe lacing"
    Accessible.description: "Drag up to tighten, down to loosen. Steps of five percent."
    onMoved: {
      root.dirty = true;
      if (!pressed) wheelCommit.restart();
    }
    onPressedChanged: {
      if (pressed) wheelCommit.stop();
      else root.commit();
    }
    Keys.onEscapePressed: {
      root.dirty = false;
      wheelCommit.stop();
      value = root.value;
    }
    background: Rectangle {
      x: 7; width: slider.width - 14; height: slider.height
      radius: 18
      color: Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.07)
      border.width: slider.activeFocus ? 2 : 1
      border.color: slider.activeFocus ? root.accent : Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.10)
      clip: true
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(5, parent.height * slider.position)
        radius: 18
        color: root.accent
        opacity: !root.connected ? 0 : (root.editing ? 0.9 : 0.35)
        Behavior on height { enabled: !slider.pressed; NumberAnimation { duration: 100 } }
      }
      Repeater {
        model: 19
        Rectangle {
          required property int index
          x: (parent.width-width)/2
          y: parent.height*(index+1)/20
          width: index % 5 === 4 ? 17 : 8; height: 1
          color: Qt.rgba(0,0,0,0.18)
        }
      }
    }
    handle: Rectangle {
      x: 20; width: slider.width-40; height: 5
      y: slider.topPadding + (1-slider.position)*(slider.availableHeight-height)
      radius: 3
      color: root.ink
      opacity: !root.connected ? 0 : (root.editing ? 1 : 0.5)
      Behavior on y { enabled: !slider.pressed; NumberAnimation { duration: 90 } }
    }
  }
  Text {
    id: batteryLabel
    anchors.horizontalCenter: parent.horizontalCenter
    text: !root.connected ? "Not connected" : (root.showBattery ? (root.battery === null ? "Battery —" : "Battery " + root.battery + "%") : "0  ·  LACING  ·  100")
    color: Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.55)
    font.family: root.family; font.pixelSize: 10
  }
  ToolTip.visible: batteryHover.containsMouse && root.showBattery
  ToolTip.text: root.checked
  MouseArea { id: batteryHover; parent:batteryLabel; anchors.fill:parent; hoverEnabled:true; acceptedButtons:Qt.NoButton }
  Timer { id: wheelCommit; interval: 180; onTriggered: root.commit() }
}
