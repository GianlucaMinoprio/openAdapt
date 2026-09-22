// Loaded only as a temporary verification plugin in the existing Omarchy shell.
// This fixture has no Controller, Process, credentials, or Bluetooth dependency.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui as UI
import "Model.js" as Model

Item {
  id: root
  property bool opened: false
  property string scenario: "fit"
  function open() { opened = true; }
  function close() { opened = false; }
  function show(payload) { opened = true; }
  TestSession { id: session }
  IpcHandler {
    target: "openadapt-verification"
    function show(view: string): void {
      root.opened = true; root.scenario = view;
      session.reset(); content.reset(); content.section = ["lights", "battery", "modes"].includes(view) ? view : "fit";
      var s = Model.clone(session.state);
      if (view === "disconnected" || view === "partial") { s.feet.right.connected = false; s.feet.left.connected = view === "partial"; s.connected = view === "partial"; }
      if (view === "progress") { s.feet.left.percent = 20; s.feet.left.movement = {phase:"moving",start:20,target:80,started_at:Date.now()/1000}; session.busy = true; }
      session.state = s;
    }
    function capture(): string {
      var path = "/tmp/openadapt-native-" + root.scenario + ".png";
      frame.grabToImage(result => result.saveToFile(path));
      return path;
    }
    function close(): void { root.close(); }
    function inspect(): string { return JSON.stringify({section:content.section,width:frame.width,height:frame.height,contentHeight:content.implicitHeight}); }
  }
  PanelWindow {
    visible: root.opened
    implicitWidth: Style.space(412)
    implicitHeight: Math.min(screen.height - Style.space(60), content.implicitHeight + Style.space(32))
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: Style.space(40); right: Style.space(20) }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "openadapt-verification"
    UI.BorderSurface {
      id: frame; anchors.fill: parent
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
      radius: Style.cornerRadius
      Flickable {
        anchors.fill: parent; anchors.margins: Style.space(16); clip: true
        contentWidth: width; contentHeight: content.implicitHeight
        PanelContent { id: content; width: parent.width; session: session; active: root.opened; onCloseRequested: root.close() }
      }
    }
  }
}
