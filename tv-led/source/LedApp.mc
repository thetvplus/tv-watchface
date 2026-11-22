import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class TvLedApp extends Application.AppBase {
    var face as LedFace?;

    function initialize() { AppBase.initialize(); }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new LedFace();
        face = view;
        return [view];
    }

    function onDisplayModeChanged() as Void {
        if (!(Application.AppBase has :onDeviceSettingChanged) && System.getDisplayMode() == System.DISPLAY_MODE_HIGH_POWER && face != null) {
            face.use24 = System.getDeviceSettings().is24Hour;
        }
        refreshFace();
    }

    function onDeviceSettingChanged(key as Symbol, value as Object) as Void {
        var view = face;
        if (key == :is24Hour && view != null && view.use24 != (value as Boolean)) {
            view.use24 = value as Boolean;
            refreshFace();
        }
    }

    function onSettingsChanged() as Void {
        if (face != null) { face.loadPreferences(); }
        refreshFace();
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Color, null, COLOR_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ClockSync, null, SYNC_KEY, {}));
        return [menu, new LedMenu()];
    }

    function onValidateProperty(key as String, value as Properties.ValueType) as Boolean or String {
        if (key.equals(COLOR_KEY) && parseHexColor(value) == null) {
            return WatchUi.loadResource(Rez.Strings.InvalidHex) as String;
        }
        if (key.equals(SYNC_KEY) && readInterval(value) == null) {
            return WatchUi.loadResource(Rez.Strings.InvalidSeconds) as String;
        }
        return true;
    }

    function refreshFace() as Void {
        if (face != null) { face.invalidateTime(); }
        if (System.getDisplayMode() != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }
}
