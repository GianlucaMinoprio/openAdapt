import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  visible: false
  property string executable: (Quickshell.env("HOME") || "") + "/.local/bin/openadapt-session"
  property var state: Model.blank()
  property bool loaded: false
  property bool requestPending: false
  property bool showBattery: true
  property int revision: 0
  readonly property bool connected: process.running && state.connected === true
  readonly property bool busy: requestPending || state.busy === true
  readonly property string message: state.message || ""
  readonly property bool failed: state.failed === true
  signal dispatched(var request)

  function start() {
    if (!process.running) { loaded = false; process.running = true; }
  }
  function refresh() {
    if (!process.running) start();
    else if (loaded) request({action:"status"});
  }
  function request(command) {
    if (!process.running || !loaded || (busy && command.action !== "disconnect" && command.action !== "status")) return false;
    if (command.action !== "status") requestPending = true;
    dispatched(command);
    process.write(JSON.stringify(command) + "\n");
    return true;
  }
  function receive(text) {
    try {
      var reply = JSON.parse(text);
      if (!reply.state || !reply.state.feet || !Array.isArray(reply.state.saved_pairs))
        throw new Error("Missing state");
      state = reply.state;
      loaded = true;
      requestPending = false;
      // Preserve the released slider position while its command is running;
      // reconcile it with the verified result when the operation finishes.
      if (!state.busy) revision++;
    } catch (error) {
      var next = Model.disconnected(state);
      next.message = "Could not load saved shoes. Check the OpenAdapt installation.";
      next.failed = true;
      state = next;
      requestPending = false;
      revision++;
    }
  }

  Process {
    id: process
    command: [root.executable]
    stdinEnabled: true
    stdout: SplitParser { onRead: data => root.receive(data) }
    stderr: StdioCollector { waitForEnd: true }
    onExited: {
      var next = Model.disconnected(root.state);
      next.message = "Controller stopped. Reopen the panel to reconnect.";
      next.failed = true;
      root.state = next;
      root.loaded = false;
      root.requestPending = false;
      root.revision++;
    }
  }
  Component.onCompleted: start()
}
