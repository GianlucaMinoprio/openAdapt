import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as UI

UI.Panel {
  id: root
  moduleName: "io.github.gianlucaminoprio.openadapt"
  ipcTarget: moduleName
  manageIpc: false
  readonly property bool reduceMotion: setting("reduceMotion", false) === true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Controller { id: session }
  FileDialog {
    id: pairingFile
    title: "Import OpenAdapt pairing"
    fileMode: FileDialog.OpenFile
    nameFilters: ["OpenAdapt pairing (*.json)"]
    onAccepted: if (session.request({action:"import-pairing", file_url:selectedFile.toString()})) content.page = "shoes"
  }
  function showDefault() { content.reset(); root.open(); }
  onOpenedChanged: if (opened) {
    session.refresh(); content.reset();
    Qt.callLater(function() { keyScope.forceActiveFocus(); });
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.showDefault(); }
    function close(): void { root.close(); }
    function toggle(): void { root.toggle(); }
    function showShoes(): void { root.open(); content.page = "shoes"; }
    function showNewShoes(): void { root.open(); content.page = "new"; }
    function connectSaved(pairId: string): string { return session.request({action:"connect", pair_id:pairId}) ? "connecting" : "unavailable"; }
    function disconnect(): string { return session.request({action:"disconnect"}) ? "disconnecting" : "unavailable"; }
    function refreshBattery(): string { return session.request({action:"battery"}) ? "reading" : "unavailable"; }
    function inspect(): string {
      return JSON.stringify({opened:root.opened, page:content.page, section:content.section, mode:"live",
        connected:session.connected, busy:session.busy, loaded:session.loaded, message:session.message,
        state:session.state, panel:{x:panel.cardOrigin.x,y:panel.cardOrigin.y,width:panel.contentWidth,height:panel.contentHeight,scrollable:flick.interactive}});
    }
  }

  UI.BarIconButton {
    id: button
    readonly property color iconInk: root.bar ? root.bar.foreground : Color.foreground
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component { ShoeMark { ink: button.iconInk } }
    onPressed: buttonCode => { if (buttonCode === Qt.LeftButton) root.toggle(); }
    Accessible.name: "OpenAdapt shoes"
  }

  UI.KeyboardPanel {
    id: panel
    anchorItem: button; owner: root; bar: root.bar; open: root.opened; focusTarget: keyScope
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(680))
    UI.PanelKeyCatcher {
      id: keyScope
      anchors.fill: parent
      readonly property var focusedItem: Window.window ? Window.window.activeFocusItem : null
      blocked: focusedItem !== null && (focusedItem.isFitInput === true || focusedItem.isFitName === true)
      onCloseRequested: content.back()
      onMoveRequested: (dx, dy) => content.moveFocus(dx || dy)
      onTabRequested: direction => content.moveFocus(direction)
      onActivateRequested: {
        if (focusedItem && focusedItem.enabled && typeof focusedItem.clicked === "function") focusedItem.clicked();
        else content.moveFocus(1);
      }
      Flickable {
        id: flick
        anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.implicitHeight
        interactive: contentHeight > height + 1
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        function revealFocus() {
          var item = keyScope.focusedItem;
          if (!item || !item.visible || item === keyScope) return;
          var point = item.mapToItem(content, 0, 0);
          if (point.y < contentY) contentY = Math.max(0, point.y - Style.space(4));
          else if (point.y + item.height > contentY + height) contentY = Math.min(Math.max(0, contentHeight - height), point.y + item.height - height + Style.space(4));
        }
        Connections { target: keyScope; function onFocusedItemChanged() { Qt.callLater(flick.revealFocus); } }
        PanelContent {
          id: content
          width: flick.width
          session: session
          active: root.opened
          reduceMotion: root.reduceMotion
          onImportRequested: pairingFile.open()
          onCloseRequested: root.close()
          onPageChanged: flick.contentY = 0
          onSectionChanged: flick.contentY = 0
        }
      }
    }
  }
}
