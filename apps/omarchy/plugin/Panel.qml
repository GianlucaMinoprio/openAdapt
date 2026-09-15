import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as UI
import "Model.js" as Model

UI.Panel {
  id: root
  moduleName: "io.github.gianlucaminoprio.openadapt"
  ipcTarget: "io.github.gianlucaminoprio.openadapt"
  manageIpc: false
  property string page: "shoes"
  property string colorSide: "both"
  readonly property color ink: Color.popups.text
  readonly property color accent: Color.accent
  readonly property color muted: Qt.rgba(ink.r,ink.g,ink.b,0.53)
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property bool bothConnected: controller.state.feet.left.connected && controller.state.feet.right.connected
  readonly property bool colorConnected: colorSide === "both" ? bothConnected : controller.state.feet[colorSide].connected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Controller { id: controller }
  function showDefault() { root.page = controller.connected ? "controls" : "shoes"; root.open(); }
  onOpenedChanged: if (opened) {
    root.page = controller.connected ? "controls" : "shoes";
    controller.refresh();
    Qt.callLater(function() { keyScope.forceActiveFocus(); });
  }
  onPageChanged: if (flick) flick.contentY = 0
  Connections {
    target: controller
    function onConnectedChanged() {
      if (controller.connected) root.page = "controls";
      else if (root.page === "controls") root.page = "shoes";
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.showDefault(); }
    function close(): void { root.close(); }
    function toggle(): void { root.toggle(); }
    function showShoes(): void { root.open(); root.page = "shoes"; }
    function showNewShoes(): void { root.open(); root.page = "new"; }
    function connectSaved(pairId: string): string { return controller.request({action:"connect",pair_id:pairId}) ? "connecting" : "unavailable"; }
    function disconnect(): string { return controller.request({action:"disconnect"}) ? "disconnecting" : "unavailable"; }
    function refreshBattery(): string { return controller.request({action:"battery"}) ? "reading" : "unavailable"; }
    function inspect(): string {
      return JSON.stringify({opened:root.opened, page:root.page, mode:"live", connected:controller.connected,
        busy:controller.busy, loaded:controller.loaded, message:controller.message,
        iconColor:button.iconInk.toString(), accentColor:root.accent.toString(), state:controller.state,
        panel:{x:panel.cardOrigin.x,y:panel.cardOrigin.y,width:panel.contentWidth,height:panel.contentHeight,scrollable:flick.interactive}});
    }
  }

  UI.BarIconButton {
    id: button
    readonly property color iconInk: root.bar ? root.bar.foreground : Color.foreground
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component { ShoeMark { ink: button.iconInk } }
    onPressed: (buttonCode) => root.toggle()
  }

  UI.KeyboardPanel {
    id: panel
    anchorItem: button; owner:root; bar:root.bar; open:root.opened; focusTarget:keyScope
    contentWidth:panel.fittedContentWidth(Style.space(380))
    contentHeight:panel.fittedContentHeight(content.implicitHeight,Style.space(780))
    FocusScope {
      id:keyScope; anchors.fill:parent
      Keys.onEscapePressed: { if (root.page === "new") root.page="shoes"; else root.close(); }
      Flickable {
        id:flick; anchors.fill:parent; clip:true
        contentWidth:width; contentHeight:content.implicitHeight
        interactive:contentHeight > height+1; boundsBehavior:Flickable.StopAtBounds
        ScrollBar.vertical:ScrollBar { policy:ScrollBar.AsNeeded }
        Column {
          id:content; width:flick.width; spacing:17
          Item {
            width:parent.width; height:44
            ShoeMark { width:33; height:34; anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter; ink:root.accent }
            Column {
              x:44; anchors.verticalCenter:parent.verticalCenter; spacing:3; width:parent.width-142
              Text { text:"OpenAdapt"; color:root.ink; font.family:root.family; font.pixelSize:19; font.weight:Font.DemiBold }
              Text { text:root.page === "controls" ? controller.state.pair_name.toUpperCase() : "YOUR SHOE COLLECTION"
                textFormat:Text.PlainText; width:parent.width; elide:Text.ElideRight
                color:root.muted; font.family:root.family; font.pixelSize:9; font.letterSpacing:1.1 }
            }
            ActionButton {
              visible:root.page !== "shoes" || controller.connected
              anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter
              text:root.page === "controls" ? "Shoes" : "Back"; compact:true
              ink:root.ink; accent:root.accent; family:root.family
              onClicked:root.page = root.page === "shoes" && controller.connected ? "controls" : "shoes"
            }
          }

          SavedShoes {
            visible:root.page === "shoes"; width:parent.width
            pairs:controller.state.saved_pairs; loaded:controller.loaded; busy:controller.busy
            connected:controller.connected; ink:root.ink; accent:root.accent; family:root.family
            onConnectRequested: pairId => controller.request({action:"connect",pair_id:pairId})
            onOpenRequested:root.page="controls"
            onNewRequested:root.page="new"
          }

          Column {
            visible:root.page === "new"; width:parent.width; spacing:18
            ShoeMark { width:70; height:70; anchors.horizontalCenter:parent.horizontalCenter; ink:root.accent }
            Text { text:"New shoes"; color:root.ink; font.family:root.family; font.pixelSize:19; font.weight:Font.Medium }
            Text { width:parent.width; wrapMode:Text.WordWrap; lineHeight:1.4
              text:"Setup for new or reset shoes needs its first pairing test before it can be enabled."
              color:root.ink; font.family:root.family; font.pixelSize:12 }
            Text { width:parent.width; wrapMode:Text.WordWrap; lineHeight:1.4
              text:"Your saved shoes can connect now. You don't need to reset them."
              color:root.muted; font.family:root.family; font.pixelSize:12 }
            ActionButton { width:parent.width; text:"Back to saved shoes"; emphasized:true
              ink:root.ink; accent:root.accent; family:root.family; onClicked:root.page="shoes" }
          }

          Column {
            visible:root.page === "controls"; width:parent.width; spacing:16
            Row {
              width:parent.width; spacing:8
              Column {
                width:parent.width-108; anchors.verticalCenter:parent.verticalCenter; spacing:4
                Repeater {
                  model:["left","right"]
                  Row {
                    required property string modelData
                    spacing:7
                    Rectangle { width:5; height:5; radius:3; y:4
                      color:controller.state.feet[modelData].connected ? root.accent : root.muted }
                    Text { text:(modelData === "left" ? "Left" : "Right") + " · " + controller.state.feet[modelData].connection
                      color:root.muted; font.family:root.family; font.pixelSize:10 }
                  }
                }
              }
              ActionButton { text:"Disconnect"; compact:true; width:100; ink:root.ink; family:root.family
                onClicked:controller.request({action:"disconnect"}) }
            }
            ActionButton {
              visible:!root.bothConnected && !controller.busy
              width:parent.width; text:"Connect missing shoe"; ink:root.ink; accent:root.accent; family:root.family
              onClicked:controller.request({action:"connect",pair_id:controller.state.selected_id})
            }
            Item {
              width:parent.width; height:14
              Text { text:"Lacing"; color:root.ink; font.family:root.family; font.pixelSize:12; font.weight:Font.Medium }
              Text { anchors.right:parent.right; text:"5% STEPS"; color:root.muted; font.family:root.family; font.pixelSize:9; font.letterSpacing:1 }
            }
            Row {
              anchors.horizontalCenter:parent.horizontalCenter; spacing:Math.max(16,(parent.width-280)/2)
              Repeater {
                model:["left","right"]
                FootSlider {
                  required property string modelData
                  side:modelData; value:controller.state.feet[modelData].percent || 0; revision:controller.revision
                  connected:controller.state.feet[modelData].connected
                  editing:root.opened && root.page === "controls" && controller.loaded && !controller.busy && connected
                  ink:root.ink; accent:root.accent; family:root.family
                  showBattery:controller.showBattery; battery:controller.state.feet[modelData].battery
                  checked:Model.lastChecked(controller.state.feet[modelData].battery_checked_at)
                  onCommitted: percent => controller.request({action:"lace",side:modelData,percent:percent})
                }
              }
            }
            Rectangle { width:parent.width; height:1; color:Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.09) }
            Row {
              width:parent.width; spacing:8
              Text { width:parent.width-176; anchors.verticalCenter:parent.verticalCenter
                text:"Color"; color:root.ink; font.family:root.family; font.pixelSize:12; font.weight:Font.Medium }
              Repeater {
                model:["left","both","right"]
                ActionButton {
                  required property string modelData
                  width:50; compact:true; text:modelData === "both" ? "Both" : (modelData === "left" ? "L" : "R")
                  emphasized:root.colorSide === modelData; ink:root.ink; accent:root.accent; family:root.family
                  Accessible.name:"Set color for " + modelData + " shoes"
                  onClicked:root.colorSide=modelData
                }
              }
            }
            Grid {
              width:parent.width; columns:6; columnSpacing:7; rowSpacing:9
              Repeater {
                model:Model.palette
                Button {
                  id:swatch
                  required property var modelData
                  width:(parent.width-35)/6; height:32; hoverEnabled:true; activeFocusOnTab:true
                  enabled:!controller.busy && root.colorConnected
                  readonly property bool chosen:root.colorSide === "both"
                    ? controller.state.feet.left.color === modelData.id && controller.state.feet.right.color === modelData.id
                    : controller.state.feet[root.colorSide].color === modelData.id
                  Accessible.name:modelData.name + " color"
                  ToolTip.visible:hovered; ToolTip.text:modelData.name
                  background:Rectangle {
                    anchors.centerIn:parent; width:32; height:32; radius:16
                    color:swatch.chosen || swatch.activeFocus ? root.ink : "transparent"; opacity:swatch.enabled ? 1 : 0.35
                    Rectangle { anchors.centerIn:parent; width:swatch.chosen || swatch.activeFocus ? 24 : 27
                      height:width; radius:width/2; color:swatch.modelData.hex; border.width:1; border.color:Qt.rgba(1,1,1,0.20) }
                  }
                  contentItem:Item {}
                  onClicked:controller.request({action:"color",side:root.colorSide,color:modelData.id})
                }
              }
            }
            Row {
              width:parent.width; spacing:9
              ActionButton { width:(parent.width-9)/2; text:"Battery"; ink:root.ink; family:root.family; enabled:!controller.busy && controller.connected
                onClicked:controller.request({action:"battery"}) }
              ActionButton { width:(parent.width-9)/2
                text:controller.state.feet.left.lights === "off" && controller.state.feet.right.lights === "off" ? "Lights are off" : "Lights off"
                ink:root.ink; family:root.family; enabled:!controller.busy && controller.connected
                onClicked:controller.request({action:"lights-off"}) }
            }
          }
          ActionButton {
            visible:controller.busy && root.page === "shoes"
            width:parent.width; text:"Cancel connection"; ink:root.ink; family:root.family
            onClicked:controller.request({action:"disconnect"})
          }
          Text {
            width:parent.width; visible:text.length > 0
            text:controller.message || (root.page === "shoes" && controller.state.saved_pairs.length > 0 ? "Wake your shoes and close Nike Adapt, then connect." : "")
            color:controller.failed ? Color.urgent : root.muted; textFormat:Text.PlainText
            font.family:root.family; font.pixelSize:10; wrapMode:Text.WordWrap; lineHeight:1.3
          }
        }
      }
    }
  }
}
