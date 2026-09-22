import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui as UI
import "Model.js" as Model

Column {
  id: root
  property string side: "left"
  property int value: 0
  property int revision: 0
  property color ink: Color.popups.text
  property color accent: Color.accent
  property string family: Style.font.family
  property bool editing: true
  property bool connected: true
  property bool fitCalibrated: true
  property bool reduceMotion: false
  property var movement: null
  property real preview: -1
  property int pairedValue: -1
  property bool dirty: false
  property bool awaitingResult: false
  property real clockNow: Date.now() / 1000
  readonly property bool moving: movement !== null && movement.phase === "moving"
  readonly property bool pending: movement !== null && (moving || movement.phase === "queued")
  readonly property bool inputFocused: slider.activeFocus
  readonly property real displayedValue: slider.value
  readonly property real trackCenterY: slider.y + slider.height / 2
  readonly property real progressValue: Model.progress(movement, value, clockNow, reduceMotion)
  signal committed(int percent)
  signal previewed(int percent)
  signal previewEnded()
  width: Style.space(140)
  spacing: Style.spacing.lg
  onValueChanged: reconcile()
  onRevisionChanged: { awaitingResult = false; reconcile(); }
  onMovementChanged: { clockNow = Date.now() / 1000; reconcile(); }
  onPreviewChanged: reconcile()
  onEditingChanged: if (!editing && dirty) cancel()

  function reconcile() {
    var hasTarget = movement && (movement.phase === "queued" || movement.phase === "moving");
    if (hasTarget) awaitingResult = false;
    if (!slider.pressed && !dirty && !awaitingResult) slider.value = preview >= 0 ? preview : hasTarget ? movement.target : value;
  }
  function cancel() {
    dirty = false; wheelCommit.stop();
    previewEnded();
    if (!awaitingResult) slider.value = movement && (movement.phase === "queued" || movement.phase === "moving") ? movement.target : value;
  }
  function commit() {
    if (!dirty || !editing) return;
    dirty = false;
    if (Model.snap(slider.value) !== root.value || (pairedValue >= 0 && Model.snap(slider.value) !== pairedValue)) { awaitingResult = true; committed(Model.snap(slider.value)); }
    else previewEnded();
  }

  Text {
    width: parent.width; horizontalAlignment: Text.AlignHCenter
    text: root.side === "left" ? "Left" : "Right"
    color: root.ink; font.family: root.family; font.pixelSize: Style.font.body
  }
  Text {
    width: parent.width; horizontalAlignment: Text.AlignHCenter
    text: root.connected && root.fitCalibrated ? Math.round(slider.value) + "%" : "—"
    color: root.ink; font.family: root.family; font.pixelSize: Style.font.displayLarge
    font.features: { "tnum": 1 }
  }
  Slider {
    id: slider
    objectName: root.side + "LacingSlider"
    property bool isFitInput: true
    anchors.horizontalCenter: parent.horizontalCenter
    orientation: Qt.Vertical
    from: 0; to: 100; stepSize: 5; snapMode: Slider.SnapAlways
    value: root.value
    live: true; wheelEnabled: activeFocus
    width: Style.space(92); height: Style.space(204)
    topPadding: 0; bottomPadding: 0
    enabled: root.editing
    activeFocusOnTab: true
    Accessible.name: root.side + " shoe fit"
    Accessible.description: "Up tightens, down loosens, in five percent steps. Escape cancels an unfinished change."
    onMoved: { root.dirty = true; root.previewed(Model.snap(value)); if (!pressed) wheelCommit.restart(); }
    onPressedChanged: { if (pressed) wheelCommit.stop(); else root.commit(); }
    Keys.onPressed: event => {
      var delta = event.key === Qt.Key_Up || event.key === Qt.Key_Right ? 5 : event.key === Qt.Key_Down || event.key === Qt.Key_Left ? -5 : 0;
      if (delta) {
        value = Model.snap(value + delta); root.dirty = true; root.previewed(Model.snap(value)); wheelCommit.restart(); event.accepted = true;
      } else if (event.key === Qt.Key_Escape && root.dirty) {
        root.cancel(); event.accepted = true;
      } else event.accepted = false;
    }
    background: UI.BorderSurface {
      x: Style.space(6); width: slider.width - Style.space(12); height: slider.height
      radius: Style.space(18)
      color: Style.normalFillFor(root.ink, root.accent)
      borderSpec: Border.controlSpec(slider.activeFocus ? "focus" : "normal", root.ink, root.accent)
      clip: true
      // Target tint follows the pointer; the stronger fill follows movement.
      Rectangle {
        anchors.fill: parent; anchors.margins: Style.space(2); radius: Style.space(16)
        color: root.accent; opacity: root.connected && root.fitCalibrated ? 0.18 : 0
        transform: Scale { origin.y: slider.height - Style.space(4); yScale: slider.position }
      }
      Rectangle {
        anchors.fill: parent; anchors.margins: Style.space(2); radius: Style.space(16)
        color: root.accent; opacity: root.connected && root.fitCalibrated ? 0.7 : 0
        transform: Scale {
          origin.y: slider.height - Style.space(4)
          yScale: root.progressValue / 100
          Behavior on yScale {
            enabled: !root.reduceMotion && !root.moving
            NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1] }
          }
        }
      }
      // Twenty intervals: every tick is 5%, with longer quarter marks.
      Repeater {
        model: 19
        Rectangle {
          required property int index
          objectName: root.side + "FitTick" + (index + 1)
          anchors.horizontalCenter: parent.horizontalCenter
          y: Style.space(2) + (parent.height - Style.space(4)) * (index + 1) / 20
          width: Style.space((index + 1) % 5 === 0 ? 20 : 9)
          height: Style.space(1)
          color: root.ink
          opacity: (index + 1) % 5 === 0 ? 0.5 : 0.28
        }
      }
    }
    handle: Rectangle {
      x: Style.space(16); width: slider.width - Style.space(32); height: Style.space(4)
      y: slider.topPadding + (1 - slider.position) * (slider.availableHeight - height)
      radius: height / 2
      color: root.ink
      visible: root.connected && root.fitCalibrated
    }
  }
  Timer { id: wheelCommit; interval: 180; onTriggered: root.commit() }
  Timer { interval: 16; repeat: true; running: root.visible && root.moving && !root.reduceMotion; onTriggered: root.clockNow = Date.now() / 1000 }
}
