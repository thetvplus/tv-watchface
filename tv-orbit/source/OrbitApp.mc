import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class TvOrbitApp extends Application.AppBase {
    var face as OrbitFace?;
    function initialize() { AppBase.initialize(); }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new OrbitFace();
        face = view;
        return [view];
    }

    function onDisplayModeChanged() as Void {
        var mode = System.getDisplayMode();
        var view = face;
        if (view != null) { view.setDisplayMode(mode); }
        if (mode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onDeviceSettingChanged(key as Symbol, value as Object) as Void {
        var current = face;
        if (key != :is24Hour || current == null || current.choice != 0) { return; }
        if (current.use24 == (value as Boolean)) { return; }
        current.setClockFormat(value as Boolean);
        if (System.getDisplayMode() != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onSettingsChanged() as Void {
        if (face != null) { face.loadPreferences(); }
        if (System.getDisplayMode() != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Format, null, FORMAT_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Color, null, COLOR_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Scale, null, SCALE_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.OrbitRefresh, null, REFRESH_KEY, {}));
        return [menu, new OrbitMenu()];
    }

    function onValidateProperty(key as String, value as Properties.ValueType) as Boolean or String {
        if (key.equals(COLOR_KEY) && parseHexColor(value) == null) {
            return WatchUi.loadResource(Rez.Strings.InvalidHex) as String;
        }
        return true;
    }
}
