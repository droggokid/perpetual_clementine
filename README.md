# Perpetual Clementine

An Omarchy shell plugin with a small illustrated clementine you can peel and eat.
It opens from a little orange in the bar and stays in a fixed pose.

| Input | Action |
| --- | --- |
| Left-drag any part of the rind | Pull it off; a short tug settles back |
| Click a fully peeled segment | Eat it |
| Hold and sweep over fully peeled segments | Highlight several; release to eat |
| Arrows / Space | Choose a piece / peel or eat it |
| R / Fresh clementine | Start again |
| Escape | Cancel the current gesture, then close |

The rind begins as one continuous skin. Each fresh fruit chooses a different
pattern from three families: broad ribbons, asymmetric flaps, and irregular
patches. These three-to-five peel pieces are independent of the eight segments
inside. A tug gently compresses the fruit and tilts its leaf; detached peel
curls collect underneath, and the exposed segments spread slightly apart.

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

The tests cover continuous rind coverage, pattern variety, segment picking,
fast sweep selection, mouse peeling, snapback, eating on release, animation
completion, cancellation, and reset.
Open the plugin in the shell to check theme integration and the bar popup.

## Implementation

The artwork uses flat QML Shapes and native QML animations. A small JavaScript
helper constructs the two-dimensional paths and handles mouse picking; there
is no rotating mesh or per-frame geometry calculation. The rind is partitioned
independently of the segments, with matching curved tear boundaries hidden
until peeling begins. Motion runs only in response to interaction and follows
Omarchy's reduced-motion setting. No image assets or extra dependencies are needed.

English and Danish catalogs follow the shell language live, with English as
the fallback for other languages. All plugin text uses plain-text rendering.
