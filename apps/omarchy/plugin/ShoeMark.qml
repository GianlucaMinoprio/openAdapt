// Generated from assets/brand/sneaker.svg by apps/ios/scripts/make-icon.swift.
import QtQuick

Canvas {
  id: root
  property color ink: "#d9e3df"
  property color lampInk: "#009dff"
  onInkChanged: requestPaint()
  onLampInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var c = getContext("2d");
    c.reset();
    var edge = Math.min(width, height);
    c.translate((width - edge) / 2, (height - edge) / 2);
    c.scale(edge / 128, edge / 128);
    c.globalCompositeOperation = 'source-over';
    c.fillStyle = ink;
    c.beginPath();
    c.moveTo(19.82, 45.2);
    c.bezierCurveTo(19.82, 42.38, 21.7, 41.44, 24.52, 44.26);
    c.bezierCurveTo(29.22, 49.9, 32.98, 52.72, 39.56, 52.72);
    c.lineTo(44.26, 52.72);
    c.lineTo(49.9, 48.02);
    c.lineTo(49.9, 41.44);
    c.bezierCurveTo(49.9, 37.68, 53.66, 34.86, 56.48, 37.68);
    c.lineTo(61.18, 43.32);
    c.bezierCurveTo(67.76, 48.96, 75.28, 51.78, 83.74, 54.6);
    c.bezierCurveTo(93.14, 58.36, 102.54, 59.3, 108.18, 60.24);
    c.bezierCurveTo(114.76, 61.18, 117.58, 64.94, 116.64, 71.52);
    c.bezierCurveTo(115.7, 79.98, 105.36, 85.62, 92.2, 88.44);
    c.bezierCurveTo(74.34, 92.2, 46.14, 91.26, 30.16, 89.38);
    c.bezierCurveTo(18.88, 88.44, 12.3, 84.68, 11.36, 79.04);
    c.bezierCurveTo(10.42, 74.34, 15.12, 69.64, 16.06, 63.06);
    c.closePath();
    c.fill();
    c.globalCompositeOperation = 'source-over';
    c.fillStyle = lampInk;
    c.beginPath();
    c.moveTo(57.655, 82.8);
    c.bezierCurveTo(57.655, 85.006, 55.866, 86.795, 53.66, 86.795);
    c.bezierCurveTo(51.454, 86.795, 49.665, 85.006, 49.665, 82.8);
    c.bezierCurveTo(49.665, 80.594, 51.454, 78.805, 53.66, 78.805);
    c.bezierCurveTo(55.866, 78.805, 57.655, 80.594, 57.655, 82.8);
    c.closePath();
    c.moveTo(69.875, 82.8);
    c.bezierCurveTo(69.875, 85.006, 68.086, 86.795, 65.88, 86.795);
    c.bezierCurveTo(63.674, 86.795, 61.885, 85.006, 61.885, 82.8);
    c.bezierCurveTo(61.885, 80.594, 63.674, 78.805, 65.88, 78.805);
    c.bezierCurveTo(68.086, 78.805, 69.875, 80.594, 69.875, 82.8);
    c.closePath();
    c.fill();
  }
}
