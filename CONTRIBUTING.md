# Contributing

All contributions are welcome, including bug fixes, new features, translations,
and documentation improvements.

## Pull requests

Every change must go through a pull request. In the description, explain what
you changed and why. Link any related issue if there is one.

For code changes, run the relevant checks and mention what you tested in the
pull request.

## Checks

```sh
omarchy plugin validate .
node tests/model.test.cjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
```

For visual changes, open the plugin in Omarchy and check the bar icon and popup.
