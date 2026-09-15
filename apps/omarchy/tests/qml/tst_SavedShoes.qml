import QtQuick
import QtTest
import "../../plugin" as App

Item {
  width:400; height:600
  App.SavedShoes { id:list; x:20; y:20; width:348 }
  SignalSpy { id:connections; target:list; signalName:"connectRequested" }
  SignalSpy { id:newShoes; target:list; signalName:"newRequested" }
  SignalSpy { id:openPair; target:list; signalName:"openRequested" }
  TestCase {
    name:"SavedShoes"; when:windowShown
    function init() { list.loaded=true; list.busy=false; list.connected=false; list.pairs=[]; connections.clear(); newShoes.clear(); openPair.clear(); wait(10); }
    function test_empty_list_centers_new_button_and_never_connects() {
      var button=findChild(list,"newShoes");
      verify(button.visible); compare(button.width,160);
      mouseClick(button); compare(newShoes.count,1); compare(connections.count,0);
    }
    function test_saved_pairs_route_only_selected_id() {
      list.pairs=[{id:"a",name:"First",connectable:true,selected:false},{id:"b",name:"Second",connectable:true,selected:false}]; wait(20);
      var second=findChild(list,"connect-b"); mouseClick(second);
      compare(connections.count,1); compare(connections.signalArguments[0][0],"b");
      var add=findChild(list,"newShoes");
      verify(add.mapToItem(list,0,0).y > second.mapToItem(list,0,0).y);
      compare(add.width,list.width);
    }
    function test_busy_disables_connection_and_new_shoes() {
      list.pairs=[{id:"a",name:"First",connectable:true,selected:false}]; list.busy=true; wait(20);
      verify(!findChild(list,"connect-a").enabled); verify(!findChild(list,"newShoes").enabled);
    }
    function test_connected_pair_opens_without_reconnecting() {
      list.pairs=[{id:"a",name:"First",connectable:true,selected:true}]; list.connected=true; wait(20);
      mouseClick(findChild(list,"connect-a")); compare(openPair.count,1); compare(connections.count,0);
    }
  }
}
