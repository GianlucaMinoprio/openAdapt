import QtQuick
import QtTest
import QtQuick.Window
import qs.Commons
import "../../plugin" as App
import "../../plugin/Model.js" as Model

Item {
  id: host
  width: 640; height: 1000
  TestSession { id: session }
  Rectangle { id: frame; width: panel.width+20; height: panel.implicitHeight+20; color: Color.background
    App.PanelContent { id: panel; x: 10; y: 10; width: 380; session: session; reduceMotion: true }
  }
  SignalSpy { id: requests; target: session; signalName: "dispatched" }
  TestCase {
    name: "PanelContent"; when: windowShown
    function initTestCase() { host.Window.window.width=640; host.Window.window.height=1000; }
    function init() { Style.scale = 1; panel.width = 380; session.reset(); panel.reset(); panel.active = true; panel.linkedFit = true; requests.clear(); wait(10); }
    function tap(name) { waitForRendering(panel,100); var item=button(name); mouseClick(item,item.width/2,item.height/2); waitForRendering(panel,100); }
    function button(name) { return findChild(panel, name); }
    function test_navigation_does_not_command_shoes() {
      tap("section-lights"); compare(panel.section, "lights");
      tap("section-modes"); compare(panel.section, "modes");
      tap("section-battery"); compare(panel.section, "battery");
      compare(requests.count, 0);
    }
    function test_tie_and_untie_are_parameter_free() {
      tap("tieShoes"); compare(requests.signalArguments[0][0].action, "tie");
      tap("untieShoes"); compare(requests.signalArguments[1][0].action, "untie");
    }
    function test_lights_always_target_both() {
      tap("section-lights"); tap("color-green");
      compare(requests.signalArguments[0][0].side, "both");
      compare(requests.signalArguments[0][0].color, "green");
    }
    function test_partial_connection_disables_pair_controls_and_keeps_one_connect() {
      var s = Model.clone(session.state); s.feet.right.connected = false; session.state = s; wait(20);
      verify(!button("tieShoes").enabled); verify(!button("untieShoes").enabled);
      verify(button("connectPair").visible); compare(button("connectPair").text, "Connect");
      tap("connectPair"); compare(requests.signalArguments[0][0].pair_id, "test");
      panel.section = "lights"; verify(!button("color-green").enabled); verify(!button("lightsOff").enabled);
    }
    function test_unknown_calibration_blocks_fit_without_blocking_lights() {
      var s = Model.clone(session.state); s.feet.right.fit_calibrated = false; session.state = s;
      verify(!button("tieShoes").enabled); verify(button("lightsOff").enabled);
    }
    function test_shoes_opens_selector_directly_and_disconnect_lives_there() {
      tap("shoeMenu"); compare(panel.page,"shoes");
      verify(button("disconnectShoes").visible); tap("disconnectShoes");
      compare(requests.signalArguments[0][0].action,"disconnect");
    }
    function test_linked_drag_previews_both_and_sends_one_paired_command() {
      var l=button("leftLacingSlider"), r=button("rightLacingSlider");
      mousePress(l,l.width/2,l.height/2); mouseMove(l,l.width/2,30,50);
      compare(l.value,r.value); compare(requests.count,0);
      mouseRelease(l,l.width/2,30); compare(requests.count,1);
      compare(requests.signalArguments[0][0].side,"both");
    }
    function test_unlink_keeps_each_slider_independent() {
      tap("linkFit"); verify(!panel.linkedFit);
      var l=button("leftLacingSlider"), r=button("rightLacingSlider");
      mousePress(l,l.width/2,l.height/2); mouseMove(l,l.width/2,30,50);
      compare(r.value,60); mouseRelease(l,l.width/2,30);
      compare(requests.signalArguments[0][0].side,"left");
    }
    function test_battery_gauges_are_not_fit_inputs() {
      panel.section="battery"; wait(10);
      var gauge=button("leftBatteryGauge"); verify(gauge.visible); verify(!gauge.activeFocusOnTab);
      mouseClick(gauge); compare(requests.count,0);
      tap("refreshBattery"); compare(requests.signalArguments[0][0].action,"battery");
    }
    function test_saving_and_renaming_send_only_names_and_stable_id() {
      panel.section = "modes"; tap("saveCurrentFit");
      var field = button("modeName"); verify(field.activeFocus); field.text = "  Daily  "; keyClick(Qt.Key_Return);
      compare(requests.signalArguments[0][0].action, "mode-save"); compare(requests.signalArguments[0][0].name, "Daily");
      tap("edit-move"); field.text = "Move comfortably"; keyClick(Qt.Key_Return);
      compare(requests.signalArguments[1][0].mode_id, "move"); compare(requests.signalArguments[1][0].action, "mode-rename");
    }
    function test_font_scaling_preserves_full_control_width() {
      Style.scale = 1.5; panel.width = 570; wait(20);
      compare(button("section-fit").width, (570-18)/4);
      verify(button("leftLacingSlider").width > 88);
      verify(panel.implicitHeight > 600);
    }
    function test_render_light_dark_and_large_text() {
      var themes=[{name:"dark",background:"#101510",ink:"#ecf0ec"},{name:"light",background:"#f6f6f4",ink:"#141614"}];
      for (var t=0;t<themes.length;t++) {
        Color.background=themes[t].background; Color.foreground=themes[t].ink;
        for (var n=0;n<2;n++) {
          Style.scale=n ? 1.5 : 1; panel.width=380*Style.scale;
          for (var i=0;i<4;i++) {
            panel.section=["fit","lights","battery","modes"][i]; wait(40);
            verify(frame.height>0 && frame.height<host.Window.window.height);
            var shot=grabImage(frame); verify(shot.width>0); shot.save("/tmp/openadapt-"+themes[t].name+"-"+panel.section+"-"+n+".png");
          }
        }
      }
      Style.scale=1; panel.width=380; Color.background="#101510"; Color.foreground="#ececec";
    }
    function test_progress_stops_short_and_reduced_motion_uses_measurement() {
      var move = {phase:"moving",start:20,target:80,started_at:10};
      compare(Model.progress(move,20,11.4,false),47);
      compare(Model.progress(move,20,99,false),74);
      compare(Model.progress(move,20,99,true),20);
      move.phase="confirmed"; compare(Model.progress(move,80,99,false),80);
      move.phase="queued"; compare(Model.progress(move,20,99,false),20);
    }
  }
}
