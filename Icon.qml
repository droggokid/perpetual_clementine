import QtQuick

Canvas {
  width: 24
  height: 24
  antialiasing: false
  layer.enabled: true
  layer.textureSize: Qt.size(18, 18)
  layer.smooth: false
  onPaint: {
    var ctx = getContext("2d");
    ctx.reset();
    ctx.fillStyle = "#f6a548";
    ctx.beginPath();
    ctx.ellipse(2, 5, 20, 17);
    ctx.fill();
    ctx.strokeStyle = "#b87438";
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = "#80512e";
    ctx.fillRect(8, 13, 1, 2);
    ctx.fillRect(15, 13, 1, 2);
    ctx.fillStyle = "#8ab45b";
    ctx.beginPath();
    ctx.moveTo(11, 6);
    ctx.quadraticCurveTo(12, 0, 20, 2);
    ctx.quadraticCurveTo(18, 8, 11, 6);
    ctx.fill();
  }
}
