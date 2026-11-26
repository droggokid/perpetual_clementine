# Tasks

## Give each clementine a different peel

As a player, I want the rind to tear a little differently on each fruit so
peeling stays surprising even when I start in the same place.

### Acceptance criteria

- Each new fruit gets a seed that varies the seam angles, positions, and curves
  within its peel pattern.
- The first grab still shapes the pattern. A cancelled tug lets you start
  elsewhere, and the first detached piece locks the layout for that fruit.
- Every layout covers the whole rind with matching seams and pieces large
  enough to grab with the pointer or select with the keyboard.
- The same seed, fruit variant, and starting point reproduce the same layout
  so geometry failures can be tested and repeated.

### Implementation notes

Use the seed when building the peel polygons and keep the existing hit testing,
curl, and drop animation. Replay a fixed set of seeds in CI to check rind
coverage and piece reachability. Include the seed, fruit variant, and grab
coordinates in failures so the layout can be reproduced locally.
[FruitModel.js](FruitModel.js) · [Clementine.qml](Clementine.qml)

A follow-up could let the tear follow the drag in real time. That would need
to handle intersections with earlier tears and keep the flap curling as the
seam changes.

## Model popup event ordering if the lifecycle grows

Revisit this if new popup or timer behavior makes event ordering harder to
cover with the shell tests. Use TLA+/TLC to explore reset, renewal, monitor
handoff, and disconnect. Check that the fruit has at most one active popup,
that events from a previous fruit cannot change a fresh one, and that each
completed fruit is counted once. Turn any counterexample into a regression
test against the plugin.
[Shell tests](tests/ShellSmoke.qml) · [TLC documentation](https://dl.tlapl.us/tlatoolbox/doc/model/overview-page.html)
