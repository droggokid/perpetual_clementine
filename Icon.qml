import QtQuick

Canvas {
  width: 24
  height: 24
  antialiasing: true
  onPaint: {
    var ctx = getContext("2d");
    ctx.reset();
    var orange = ctx.createRadialGradient(8, 9, 1, 12, 13, 11);
    orange.addColorStop(0, "#ffb752");
    orange.addColorStop(1, "#e66a19");
    ctx.fillStyle = orange;
    ctx.beginPath();
    ctx.ellipse(2, 5, 20, 17);
    ctx.fill();
    ctx.strokeStyle = "#b94d18";
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    ctx.moveTo(12, 7);
    ctx.bezierCurveTo(9, 12, 9, 17, 12, 21);
    ctx.stroke();
    ctx.fillStyle = "#8ab45b";
    ctx.beginPath();
    ctx.moveTo(11, 6);
    ctx.quadraticCurveTo(12, 0, 20, 2);
    ctx.quadraticCurveTo(18, 8, 11, 6);
    ctx.fill();
  }
}
