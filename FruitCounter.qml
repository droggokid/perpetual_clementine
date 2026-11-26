pragma Singleton
import QtCore

Settings {
  location: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    + "/omarchy/droggokid.perpetual-clementine.ini"
  property double total: 0
  property bool monochromeIcon: false

  function recordFruit() {
    total += 1;
    setValue("total", total);
    sync();
  }

  function saveIconStyle(monochrome) {
    monochromeIcon = monochrome;
    setValue("monochromeIcon", monochrome);
    sync();
  }
}
