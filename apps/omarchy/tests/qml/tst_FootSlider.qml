import QtQuick
import QtTest
import "../../plugin" as App

Item {
  width:400; height:500
  App.FootSlider { id:foot; x:20; y:20; value:50 }
  SignalSpy { id:commits; target:foot; signalName:"committed" }
  TestCase {
    name:"FootSlider"; when:windowShown
    function init() { foot.editing=true; foot.value=50; foot.revision++; commits.clear(); wait(50); }
    function slider() { return findChild(foot,"leftLacingSlider"); }
    function test_programmatic_update_never_commands() {
      foot.value=75; wait(200);
      compare(foot.displayedValue,75); compare(commits.count,0);
    }
    function test_drag_commits_only_once_on_release() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2);
      mouseMove(s,s.width/2,30,50);
      compare(commits.count,0);
      mouseRelease(s,s.width/2,30);
      compare(commits.count,1);
      verify(commits.signalArguments[0][0] % 5 === 0);
      verify(commits.signalArguments[0][0] > 50);
    }
    function test_drag_to_bottom_is_zero() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2);
      mouseMove(s,s.width/2,s.height,50);
      mouseRelease(s,s.width/2,s.height);
      compare(commits.count,1); compare(commits.signalArguments[0][0],0);
    }
    function test_disabling_cancels_pending_drag() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2);
      mouseMove(s,s.width/2,30,50);
      foot.editing=false;
      mouseRelease(s,s.width/2,30);
      wait(250); compare(commits.count,0);
    }
    function test_failed_operation_reverts_display() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2);
      mouseMove(s,s.width/2,30,50); mouseRelease(s,s.width/2,30);
      foot.revision++; wait(50); compare(foot.displayedValue,50);
    }
    function test_keyboard_steps_by_five() {
      var s=slider(); s.forceActiveFocus();
      keyClick(Qt.Key_Up); wait(220);
      compare(commits.count,1); compare(commits.signalArguments[0][0],55);
    }
  }
}
