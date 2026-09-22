import QtQuick
import "../../plugin/Model.js" as Model
Item {
  property var state: initial()
  property bool loaded: true
  property bool busy: false
  property bool connected: state.connected
  property int revision: 0
  property string message: state.message || ""
  property bool failed: state.failed === true
  signal dispatched(var request)
  function initial() {
    var s = Model.blank();
    s.saved_pairs = [{id:"test", name:"Auto Max", connectable:true, selected:true}];
    s.selected_id = "test"; s.pair_name = "Auto Max"; s.connected = true;
    s.modes = [{id:"move",name:"Move",left:60,right:60}, {id:"chill",name:"Chill",left:30,right:30}]; s.tie_mode_id = "move";
    ["left","right"].forEach(function(side) { s.feet[side].connected=true; s.feet[side].fit_calibrated=true; s.feet[side].battery=side === "left" ? 88 : 76; s.feet[side].battery_checked_at=Date.now()/1000; s.feet[side].percent=60; s.feet[side].status="verified"; });
    return s;
  }
  function request(command) { dispatched(command); return true; }
  function reset() { state = initial(); busy = false; revision++; }
}
