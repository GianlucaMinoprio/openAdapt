import QtQuick

Canvas {
  id: root
  property color ink: "#d9e3df"
  onInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var c = getContext("2d");
    c.reset();
    c.scale(width/28, height/28);
    c.strokeStyle = ink;
    c.lineWidth = 1.55;
    c.lineCap = "round";
    c.lineJoin = "round";
    c.beginPath();
    c.moveTo(3,9); c.lineTo(7,11); c.lineTo(10,10); c.lineTo(11,7);
    c.lineTo(17,12); c.bezierCurveTo(19,13.8,21,14.2,24,15);
    c.bezierCurveTo(25.3,15.4,26,16.4,26,18); c.lineTo(26,20);
    c.bezierCurveTo(19,22,10,21.5,2,21); c.lineTo(2,17); c.closePath(); c.stroke();
    c.beginPath(); c.moveTo(2,17); c.bezierCurveTo(9,17.6,18,19.8,26,18); c.stroke();
    c.beginPath(); c.moveTo(11,10); c.lineTo(13.6,9.6);
    c.moveTo(13.3,12); c.lineTo(16,11.7); c.moveTo(15.5,14); c.lineTo(18,13.6); c.stroke();
  }
}
