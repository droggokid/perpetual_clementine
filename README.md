# Perpetual Clementine

An Omarchy shell plugin with a small illustrated clementine you can peel and eat.
It opens from a little orange in the bar and stays in a fixed pose.

| Input | Action |
| --- | --- |
| Left-drag any part of the rind | Pull it off; a short tug settles back |
| Click a fully peeled segment | Eat it |
| Hold and sweep over fully peeled segments | Highlight several; release to eat |
| Arrows / Space | Choose a starting point or piece / peel or eat it |
| R | Start again |
| Escape | Cancel the current gesture, then close |

The rind begins as one continuous skin. Your first successful pull chooses the
pattern: the top opens broad flaps, either side makes ribbons, and a lower or
central start makes irregular patches. The precise starting point shifts the
tear boundaries and the direction of the curl; each fresh fruit also changes
the variation within the chosen family. Once the first piece comes off, the
layout stays fixed for that fruit. A cancelled first tug lets you start elsewhere.
The three-to-five peel pieces are independent of the eight segments inside. A tug gently compresses the fruit and tilts its leaf. The rind separates
along a moving tear line, curls back to reveal its pale pith, and stretches a
few fine pith strands before detaching. Each folded sheet falls into the pile
in its own shape, and the exposed segments spread slightly apart.

After the last segment, “All gone” stays for 1.4 seconds before a fresh fruit
appears. Renewal waits while the popup is closed. There is no reset button;
R remains available as a keyboard shortcut.

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
`Icon.qml`, `PeelFlap.qml`, `FruitModel.js`, and `i18n/` under
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

The tests cover continuous rind coverage, start-dependent patterns, pattern locking,
starting again after a cancelled tug, segment picking,
fast sweep selection, mouse peeling, snapback, eating on release, animation
completion, progressive peeling, automatic renewal, closing during the pause,
cancellation, and reset.
Open the plugin in the shell to check theme integration and the bar popup.

## Implementation

The artwork uses rounded, softly uneven QML curves and native animations.
Shared peel boundaries bend organically; closed curved outlines soften every
tear and folded corner. A small nearest-filtered artwork layer gives the fruit
a lightly pixelated finish, with a limited warm palette, sparse rind pores,
and rounded, plump segments. Text and panel controls retain their normal rendering.

A small JavaScript
helper constructs the two-dimensional paths and handles mouse picking. Only
the actively peeled sheet recalculates its small curved outline as the tear
advances. The rind is partitioned independently of the segments, with matching
tear boundaries hidden until peeling begins. The same folded artwork is used
while pulling, falling, and resting in the pile. Animations follow Omarchy's
reduced-motion setting; the completion pause remains readable with motion off.
No image assets or extra dependencies are needed.

English and Danish catalogs follow the shell language live, with English as
the fallback for other languages. All plugin text uses plain-text rendering.
