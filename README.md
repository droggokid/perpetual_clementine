# Perpetual Clementine

An Omarchy shell plugin with a clementine you can rotate, peel, and eat.
It opens from a small orange in the bar, in a popup like Elsewhen.

| Input | Action |
| --- | --- |
| Left-drag a peel strip | Pull it off; a short pull snaps back |
| Right-drag, middle-drag, or drag the empty background | Rotate the fruit |
| Click a fully peeled segment | Eat it |
| Hold and sweep over fully peeled segments | Highlight several; release to eat |
| Arrows / Space | Rotate / remove the frontmost peel strip or segment |
| R / Fresh clementine | Start again |
| Escape | Cancel the current gesture, then close |

Finish peeling before eating. Progress survives closing the popup within a
shell session. Each monitor has its own fruit; restarting or reloading the
plugin starts fresh. The plugin makes no network requests and writes no data.

## Install

Requires an Omarchy version with the Quickshell shell and `qs.Commons.Translations`
(the same shell generation as the built-in Elsewhen plugin).
No dependencies or compilation are needed: the shell loads QML directly.

Once the repository is published:

```sh
omarchy plugin add https://github.com/droggokid/perpetual_clementine.git --yes --enable
```

For a local checkout, place `manifest.json`, `Panel.qml`, `Clementine.qml`,
`Icon.qml`, `FruitModel.js`, and `i18n/` under
`~/.config/omarchy/plugins/droggokid.perpetual-clementine/`, then run:

```sh
omarchy-shell shell rescanPlugins
omarchy plugin enable droggokid.perpetual-clementine --after omarchy.elsewhen
```

User plugin files and `shell.json` hot-reload. System files under
`/usr/share/omarchy/` need no changes. See the
[Omarchy shell reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md).

## Check

```sh
omarchy plugin validate .
node tests/model.test.cjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
```

The tests cover mesh picking and occlusion, fast sweep selection, mouse peeling,
snapback, rotation, eating on release, cancellation, completion, and reset.
Open the plugin in the shell to check theme integration and the bar popup.

## Implementation

Like Elsewhen's globe, the fruit uses orthographic projection on a QML Canvas.
The painter and mouse picker share the same depth-sorted wedge surfaces, so
removed segments expose the membranes of the neighbouring pieces. Procedural
surface details keep the artwork attached while rotating without texture files
or a 3D engine. The Canvas repaints only when its state changes; the short peel
and eating animations follow Omarchy's reduced-motion setting.

English and Danish catalogs follow the shell language live, with English as
the fallback for other languages. All plugin text uses plain-text rendering.
