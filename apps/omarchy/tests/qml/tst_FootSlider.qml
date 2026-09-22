import QtQuick
import QtTest
import "../../plugin" as App

Item {
  width:400; height:500
  App.FootSlider { id:foot; x:20; y:20; value:50 }
  SignalSpy { id:commits; target:foot; signalName:"committed" }
  TestCase {
    name:"FootSlider"; when:windowShown
    function init() { foot.movement=null; foot.reduceMotion=true; foot.editing=true; foot.value=50; foot.revision++; commits.clear(); wait(50); }
    function slider() { return findChild(foot,"leftLacingSlider"); }
    function test_scale_marks_every_five_percent() {
      var previous=-1;
      for (var i=1;i<=19;i++) { var tick=findChild(foot,"leftFitTick"+i); verify(tick!==null); verify(tick.y>previous); previous=tick.y; }
    }
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
    function test_released_target_stays_locked_during_initial_busy_reply() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2); mouseMove(s,s.width/2,30,50); mouseRelease(s,s.width/2,30);
      var released=foot.displayedValue;
      foot.movement={phase:"confirmed",start:50,target:50,started_at:null};
      compare(foot.displayedValue,released);
      foot.movement={phase:"queued",start:50,target:released,started_at:null};
      compare(foot.displayedValue,released); compare(foot.progressValue,50);
    }
    function test_failed_operation_reverts_display() {
      var s=slider();
      mousePress(s,s.width/2,s.height/2);
      mouseMove(s,s.width/2,30,50); mouseRelease(s,s.width/2,30);
      foot.revision++; wait(50); compare(foot.displayedValue,50);
    }
    function test_escape_cancels_keyboard_debounce() {
      var s=slider(); s.forceActiveFocus(); keyClick(Qt.Key_Up); keyClick(Qt.Key_Escape);
      wait(220); compare(commits.count,0); compare(foot.displayedValue,50);
    }
    function test_movement_target_does_not_replace_measured_progress() {
      foot.movement={phase:"queued",start:50,target:80,started_at:null};
      compare(foot.displayedValue,80); compare(foot.progressValue,50); compare(commits.count,0);
      foot.movement={phase:"moving",start:50,target:80,started_at:Date.now()/1000-1};
      foot.reduceMotion=false; verify(foot.progressValue>50 && foot.progressValue<80);
    }
    function test_keyboard_steps_by_five() {
      var s=slider(); s.forceActiveFocus();
      keyClick(Qt.Key_Up); wait(220);
      compare(commits.count,1); compare(commits.signalArguments[0][0],55);
    }
  }
}
