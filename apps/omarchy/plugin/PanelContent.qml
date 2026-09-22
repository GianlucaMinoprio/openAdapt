import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui as UI
import "Model.js" as Model

Column {
  id: root
  required property var session
  property bool active: true
  property bool reduceMotion: false
  property string page: "home"
  property string section: "fit"
  property bool linkedFit: true
  property int linkedPreview: -1
  property string previewSide: ""
  property string editModeId: ""
  property string removeModeId: ""
  property bool creatingMode: false
  readonly property bool bothConnected: session.state.feet.left.connected && session.state.feet.right.connected
  readonly property bool fitReady: bothConnected && session.state.feet.left.fit_calibrated && session.state.feet.right.fit_calibrated && !session.busy
  readonly property bool canControl: bothConnected && !session.busy
  readonly property var selectedPair: session.state.saved_pairs.find(p => p.id === session.state.selected_id)
  readonly property var modes: session.state.modes || []
  readonly property var tieMode: modes.find(m => m.id === session.state.tie_mode_id)
  readonly property color ink: Color.popups.text
  signal importRequested()
  signal closeRequested()
  spacing: Style.spacing.panelGap

  function reset() { page = session.state.saved_pairs.length ? "home" : "shoes"; section = "fit"; linkedPreview = -1; previewSide = ""; cancelEditor(); }
  function cancelEditor() { creatingMode = false; editModeId = ""; removeModeId = ""; }
  function finishEditing() { cancelEditor(); Qt.callLater(function() { if (root.active) root.moveFocus(1); }); }
  function back() {
    if (creatingMode || editModeId || removeModeId) finishEditing();
    else if (page !== "home" && session.state.saved_pairs.length) page = "home";
    else closeRequested();
  }
  function connectPair(pairId) {
    if (session.request({action:"connect", pair_id:pairId})) { page = "home"; section = "fit"; cancelEditor(); }
  }
  function saveMode() {
    var name = modeName.text.trim();
    if (!name.length || session.busy) return;
    var request = editModeId ? {action:"mode-rename", mode_id:editModeId, name:name} : {action:"mode-save", name:name};
    if (session.request(request)) finishEditing();
  }
  function focusables(item, result) {
    if (!item.visible || !item.enabled) return;
    if (item.activeFocusOnTab) { result.push(item); return; }
    for (var i = 0; i < item.children.length; i++) focusables(item.children[i], result);
  }
  function moveFocus(direction) {
    var list = []; focusables(root, list);
    if (!list.length) return;
    var current = list.findIndex(item => item.activeFocus);
    list[(current + direction + list.length) % list.length].forceActiveFocus(Qt.TabFocusReason);
  }
  Keys.onEscapePressed: back()
  onActiveChanged: if (!active) { leftFit.cancel(); rightFit.cancel(); }
  onPageChanged: { cancelEditor(); linkedPreview = -1; }
  Connections { target: root.session; function onRevisionChanged() { root.linkedPreview = -1; } function onStateChanged() { if (root.page === "home" && !root.session.state.saved_pairs.length) root.page = "shoes"; } }

  Row {
    width: parent.width; spacing: Style.spacing.lg
    ShoeMark { width: Style.space(34); height: width; ink: Color.accent; lampInk: "white"; anchors.verticalCenter: parent.verticalCenter }
    Column {
      width: parent.width - Style.space(34) - headerAction.width - parent.spacing * 2
      spacing: Style.spacing.xs
      AppText { text: root.page === "home" ? "OpenAdapt" : (root.page === "new" ? "New shoes" : "Your shoes"); font.pixelSize: Style.font.heading; font.weight: Font.DemiBold }
      AppText { visible: root.page === "home"; width: parent.width; text: root.session.state.pair_name || "Your shoes"; wrapMode: Text.NoWrap; elide: Text.ElideRight; opacity: 0.75 }
    }
    ActionButton {
      id: headerAction; objectName: "shoeMenu"; text: root.page === "home" ? "Shoes" : "Back"; compact: true
      onClicked: { if (root.page === "home") root.page = "shoes"; else root.back(); }
    }
  }

  SavedShoes {
    visible: root.page === "shoes"; width: parent.width
    pairs: root.session.state.saved_pairs; loaded: root.session.loaded; busy: root.session.busy
    connected: root.session.connected; bothConnected: root.bothConnected
    onConnectRequested: pairId => root.connectPair(pairId)
    onOpenRequested: { root.page = "home"; root.section = "fit"; }
    onNewRequested: root.page = "new"
    onDisconnectRequested: root.session.request({action:"disconnect"})
  }

  Column {
    visible: root.page === "new"; width: parent.width; spacing: Style.spacing.panelGap
    ShoeMark { width: Style.space(110); height: width; anchors.horizontalCenter: parent.horizontalCenter; ink: Color.accent; lampInk: "white" }
    AppText { width: parent.width; text: "Pair on your iPhone, then bring your shoes here."; font.pixelSize: Style.font.title }
    AppText { width: parent.width; text: "In OpenAdapt on iPhone, open Settings → Developer mode → Your shoes and export the pairing file."; opacity: 0.8 }
    ActionButton { width: parent.width; text: "Import pairing file"; emphasized: true; enabled: root.session.loaded && !root.session.busy && !root.session.connected; onClicked: root.importRequested() }
    AppText { width: parent.width; text: root.session.connected ? "Disconnect your shoes before importing." : "Keep the file private: it contains your pairing keys. Your other saved pairs are kept. Omarchy may also need Bluetooth pairing in system settings."; opacity: 0.7; font.pixelSize: Style.font.bodySmall }
  }

  Column {
    visible: root.page === "home"; width: parent.width; spacing: Style.spacing.panelGap
    ActionButton {
      objectName: "connectPair"; width: parent.width; visible: !root.bothConnected
      text: root.session.state.operation === "connect" ? "Cancel connection" : "Connect"; emphasized: true
      enabled: root.session.loaded && (root.session.state.operation === "connect" || (!root.session.busy && root.selectedPair && root.selectedPair.connectable))
      onClicked: { if (root.session.state.operation === "connect") root.session.request({action:"disconnect"}); else root.connectPair(root.session.state.selected_id); }
    }
    Row {
      width: parent.width; spacing: Style.spacing.sm
      Repeater {
        model: ["fit", "lights", "battery", "modes"]
        ActionButton {
          required property string modelData
          objectName: "section-" + modelData
          width: (parent.width - parent.spacing * 3) / 4
          text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
          emphasized: root.section === modelData
          Accessible.role: Accessible.PageTab
          Accessible.description: emphasized ? "Selected" : ""
          onClicked: { root.section = modelData; root.cancelEditor(); }
        }
      }
    }
    Item {
      width: parent.width
      implicitHeight: Math.max(Style.space(360), root.section === "fit" ? fitBody.implicitHeight : root.section === "lights" ? lightsBody.implicitHeight : root.section === "battery" ? batteryBody.implicitHeight : modesBody.implicitHeight)
      Column {
        id: fitBody; visible: root.section === "fit"; width: parent.width; spacing: Style.spacing.panelGap
        Row {
          width: parent.width; spacing: Style.spacing.lg
          FootSlider {
            id: leftFit; width: (parent.width - linkColumn.width - parent.spacing * 2) / 2; side: "left"
            value: root.session.state.feet.left.percent || 0; revision: root.session.revision
            movement: root.session.state.feet.left.movement || null
            preview: root.linkedFit && root.previewSide !== "left" ? root.linkedPreview : -1
            pairedValue: root.linkedFit ? root.session.state.feet.right.percent : -1
            connected: root.session.state.feet.left.connected; fitCalibrated: root.session.state.feet.left.fit_calibrated === true
            editing: root.active && root.page === "home" && root.section === "fit" && !root.session.busy && connected && fitCalibrated && (!root.linkedFit || root.fitReady)
            reduceMotion: root.reduceMotion
            onPreviewed: percent => { root.previewSide = "left"; root.linkedPreview = percent; }
            onPreviewEnded: if (root.previewSide === "left") root.linkedPreview = -1
            onCommitted: percent => root.session.request({action:"lace", side:root.linkedFit ? "both" : "left", percent:percent})
          }
          Item {
            id: linkColumn; width: Style.space(40); height: leftFit.implicitHeight
            ActionButton {
              objectName: "linkFit"; width: parent.width; height: width
              y: leftFit.trackCenterY - height / 2
              iconText: "\uf0c1"; iconSize: Style.space(20); emphasized: root.linkedFit
              enabled: !root.session.busy
              Accessible.name: "Link fit"
              Accessible.role: Accessible.CheckBox; Accessible.checked: root.linkedFit
              tooltipText: root.linkedFit ? "Linked fit · Move both shoes together" : "Link fit · Move both shoes together"
              onClicked: { root.linkedFit = !root.linkedFit; root.linkedPreview = -1; }
            }
          }
          FootSlider {
            id: rightFit; width: leftFit.width; side: "right"
            value: root.session.state.feet.right.percent || 0; revision: root.session.revision
            movement: root.session.state.feet.right.movement || null
            preview: root.linkedFit && root.previewSide !== "right" ? root.linkedPreview : -1
            pairedValue: root.linkedFit ? root.session.state.feet.left.percent : -1
            connected: root.session.state.feet.right.connected; fitCalibrated: root.session.state.feet.right.fit_calibrated === true
            editing: root.active && root.page === "home" && root.section === "fit" && !root.session.busy && connected && fitCalibrated && (!root.linkedFit || root.fitReady)
            reduceMotion: root.reduceMotion
            onPreviewed: percent => { root.previewSide = "right"; root.linkedPreview = percent; }
            onPreviewEnded: if (root.previewSide === "right") root.linkedPreview = -1
            onCommitted: percent => root.session.request({action:"lace", side:root.linkedFit ? "both" : "right", percent:percent})
          }
        }
        Row {
          width: parent.width; spacing: Style.spacing.lg
          ActionButton { objectName: "tieShoes"; width: (parent.width - parent.spacing) / 2; text: "Tie"; emphasized: true; enabled: root.fitReady && !!root.tieMode; tooltipText: root.tieMode ? root.tieMode.name + " · " + root.tieMode.left + "/" + root.tieMode.right : "Save a fit in Modes first"; onClicked: root.session.request({action:"tie"}) }
          ActionButton { objectName: "untieShoes"; width: (parent.width - parent.spacing) / 2; text: "Untie"; enabled: root.fitReady; onClicked: root.session.request({action:"untie"}) }
        }
        AppText { width: parent.width; visible: root.session.connected && (!leftFit.fitCalibrated || !rightFit.fitCalibrated); text: "Use the shoe buttons for fit until calibration is verified. Battery and lights are available."; opacity: 0.75; font.pixelSize: Style.font.bodySmall }
      }
      Column {
        id: lightsBody; visible: root.section === "lights"; width: parent.width; spacing: Style.spacing.panelGap
        AppText { text: "Color for both shoes"; opacity: 0.75 }
        Grid {
          width: parent.width; columns: 6; spacing: Style.spacing.lg
          Repeater {
            model: Model.palette
            ActionButton {
              id: swatch; required property var modelData
              objectName: "color-" + modelData.id
              width: (parent.width - parent.spacing * 5) / 6; height: Style.space(42)
              enabled: root.canControl
              emphasized: root.session.state.feet.left.color === modelData.id && root.session.state.feet.right.color === modelData.id && root.session.state.feet.left.lights === "color-set" && root.session.state.feet.right.lights === "color-set"
              tooltipText: modelData.name; Accessible.name: modelData.name + " for both shoes"
              Rectangle { anchors.centerIn: parent; width: Style.space(21); height: width; radius: width / 2; color: swatch.modelData.hex; border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4) }
              onClicked: root.session.request({action:"color", side:"both", color:modelData.id})
            }
          }
        }
        ActionButton { objectName: "lightsOff"; width: parent.width; text: "Lights off"; enabled: root.canControl; emphasized: root.session.state.feet.left.lights === "off" && root.session.state.feet.right.lights === "off"; onClicked: root.session.request({action:"lights-off"}) }
      }
      Column {
        id: batteryBody; visible: root.section === "battery"; width: parent.width; spacing: Style.spacing.panelGap
        Row {
          width: parent.width; spacing: Style.spacing.lg
          Repeater {
            model: ["left", "right"]
            BatteryGauge {
              required property string modelData
              objectName: modelData + "BatteryGauge"
              width: (parent.width - parent.spacing) / 2
              side: modelData; percent: root.session.state.feet[modelData].battery
              connected: root.session.state.feet[modelData].connected
              checked: Model.lastChecked(root.session.state.feet[modelData].battery_checked_at)
            }
          }
        }
        ActionButton { objectName: "refreshBattery"; width: parent.width; text: "Refresh battery"; enabled: root.session.connected && !root.session.busy; onClicked: root.session.request({action:"battery"}) }
      }
      Column {
        id: modesBody; visible: root.section === "modes"; width: parent.width; spacing: Style.spacing.lg
        Repeater {
          model: root.modes
          Column {
            required property var modelData
            width: modesBody.width; spacing: Style.spacing.sm
            Row {
              width: parent.width; spacing: Style.spacing.sm
              ActionButton {
                objectName: "apply-" + modelData.id; width: parent.width - editButton.width - parent.spacing; height: Style.space(62)
                enabled: root.fitReady
                Accessible.name: modelData.name + ", left " + modelData.left + ", right " + modelData.right
                onClicked: root.session.request({action:"mode-apply", mode_id:modelData.id})
                Column {
                  anchors.verticalCenter: parent.verticalCenter; x: Style.space(12); width: parent.width - x * 2; spacing: Style.spacing.sm
                  AppText { width: parent.width; text: modelData.name; wrapMode: Text.NoWrap; elide: Text.ElideRight; font.pixelSize: Style.font.subtitle }
                  AppText { width: parent.width; text: "L " + modelData.left + "%  ·  R " + modelData.right + "%" + (root.session.state.tie_mode_id === modelData.id ? "  ·  Used by Tie" : ""); font.pixelSize: Style.font.bodySmall; opacity: 0.7 }
                }
              }
              ActionButton { id: editButton; objectName: "edit-" + modelData.id; text: "Edit"; compact: true; anchors.verticalCenter: parent.verticalCenter; enabled: !root.session.busy; onClicked: { root.cancelEditor(); root.editModeId = modelData.id; modeName.text = modelData.name; modeName.forceActiveFocus(); } }
            }
          }
        }
        AppText { visible: !root.modes.length; width: parent.width; text: "Adjust your fit, then save it here."; opacity: 0.75 }
        ActionButton { objectName: "saveCurrentFit"; width: parent.width; text: "Save current fit"; visible: !root.creatingMode && !root.editModeId; enabled: root.fitReady && root.modes.length < 20; onClicked: { root.creatingMode = true; modeName.text = ""; modeName.forceActiveFocus(); } }
        Column {
          visible: root.creatingMode || root.editModeId !== ""; width: parent.width; spacing: Style.spacing.lg
          UI.TextField { id: modeName; property bool isFitName: true; objectName: "modeName"; width: parent.width; maximumLength: 40; placeholderText: "Fit name"; Accessible.name: "Fit name"; onAccepted: root.saveMode(); Keys.onEscapePressed: root.finishEditing() }
          Row {
            width: parent.width; spacing: Style.spacing.sm
            ActionButton { width: (parent.width - parent.spacing) / 2; text: "Save"; emphasized: true; enabled: modeName.text.trim().length > 0 && !root.session.busy; onClicked: root.saveMode() }
            ActionButton { width: (parent.width - parent.spacing) / 2; text: "Cancel"; onClicked: root.finishEditing() }
          }
          ActionButton { width: parent.width; text: "Remove fit"; visible: !!root.editModeId && !root.removeModeId; enabled: !root.session.busy; onClicked: root.removeModeId = root.editModeId }
          Column {
            visible: !!root.removeModeId; width: parent.width; spacing: Style.spacing.sm
            AppText { width: parent.width; text: "Remove this saved fit?" }
            Row {
              width: parent.width; spacing: Style.spacing.sm
              ActionButton { width: (parent.width - parent.spacing) / 2; text: "Remove"; ink: Color.urgent; enabled: !root.session.busy; onClicked: { if (root.session.request({action:"mode-remove", mode_id:root.removeModeId})) root.finishEditing(); } }
              ActionButton { width: (parent.width - parent.spacing) / 2; text: "Keep fit"; onClicked: root.removeModeId = "" }
            }
          }
        }
      }
    }
  }
  AppText {
    width: parent.width; visible: text.length > 0
    text: (root.page === "home" && root.session.message === "Both shoes connected" ? "" : root.session.message) || (!root.session.connected && root.page === "home" ? "Wake both shoes, then connect." : "")
    color: root.session.failed ? Color.urgent : root.ink; opacity: root.session.failed ? 1 : 0.75
    font.pixelSize: Style.font.bodySmall
  }
}
