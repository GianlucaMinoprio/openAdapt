pragma Singleton
import QtQuick
QtObject { function controlSpec(state, ink, accent) { return {color:state === "focus" ? accent : Qt.rgba(ink.r,ink.g,ink.b,0.3)}; } }
