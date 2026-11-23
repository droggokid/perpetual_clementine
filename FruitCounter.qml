pragma Singleton
import QtCore

Settings {
  location: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
    + "/omarchy/droggokid.perpetual-clementine.ini"
  property double total: 0

  function recordFruit() {
    total += 1;
    setValue("total", total);
    sync();
  }
}
