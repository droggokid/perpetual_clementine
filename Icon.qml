import QtQuick

Canvas {
  property bool monochrome: false
  property color monochromeColor: "white"

  width: 24
  height: 24
  antialiasing: monochrome
  layer.enabled: true
  layer.textureSize: Qt.size(18, 18)
  layer.smooth: false
  onMonochromeChanged: requestPaint()
  onMonochromeColorChanged: if (monochrome) requestPaint()
  onPaint: {
    var ctx = getContext("2d");
    ctx.reset();
    ctx.beginPath();
    if (monochrome) {
      ctx.strokeStyle = monochromeColor;
      ctx.lineWidth = 1.9;
      ctx.lineJoin = "round";
      ctx.moveTo(12, 7.5);
      ctx.bezierCurveTo(8.5, 6, 4.3, 7.4, 2.8, 11.2);
      ctx.bezierCurveTo(1, 15.9, 5.1, 21, 11.7, 21);
      ctx.bezierCurveTo(17.8, 21, 22.4, 17.7, 21.6, 13.1);
      ctx.bezierCurveTo(21, 9.4, 17.3, 6.4, 12, 7.5);
      ctx.closePath();
      ctx.moveTo(12, 7.5);
      ctx.bezierCurveTo(13.1, 4.2, 15.7, 2.4, 20.1, 2.9);
      ctx.bezierCurveTo(18.8, 6.1, 15.7, 7.8, 12, 7.5);
      ctx.closePath();
      ctx.stroke();
      return;
    }

    ctx.fillStyle = "#f6a548";
    ctx.ellipse(2, 5, 20, 17);
    ctx.fill();
    ctx.strokeStyle = "#b87438";
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.fillStyle = "#ffd48a";
    ctx.fillRect(5, 10, 2, 1);

    ctx.fillStyle = "#8ab45b";
    ctx.beginPath();
    ctx.moveTo(11, 6);
    ctx.quadraticCurveTo(12, 0, 20, 2);
    ctx.quadraticCurveTo(18, 8, 11, 6);
    ctx.fill();
  }
}
