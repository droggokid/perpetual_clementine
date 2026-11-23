# Perpetual Clementine

Peel and eat a little pixel-art clementine from your Omarchy bar. The peel
pattern changes depending on where you start, and the plugin keeps a running
total of the clementines you finish.

## Demo

[![Perpetual Clementine being peeled and eaten](media/demo.gif)](media/screenrecording-2026-11-23_18-05-50.mp4)

| Colour bar icon | Monochrome bar icon |
| --- | --- |
| ![Orange clementine icon in the Omarchy bar](media/screenshot-2026-11-23_17-20-42.png) | ![Monochrome clementine outline in the Omarchy bar](media/screenshot-2026-11-23_18-30-34.png) |

## Install

Requires the Quickshell-based Omarchy shell that ships with Elsewhen.

```sh
omarchy plugin add https://github.com/droggokid/perpetual_clementine.git --yes --enable
```

## How to play

Click the orange in the bar and drag the rind to peel it. Once the fruit is
fully peeled, click a segment to eat it or hold and sweep across several, then
release. A new clementine appears after the last bite.

Use the arrow keys to select a spot or segment, then press Space or Enter to
peel or eat. Press R or click the reset button for a fresh fruit. Escape
cancels the current gesture or closes the popup. Right-click the bar icon to
switch between colour and monochrome.

## Remove

```sh
omarchy plugin remove droggokid.perpetual-clementine
```

Your clementine total carries over if you reinstall.

## Contributing

See the [contribution guide](CONTRIBUTING.md).
