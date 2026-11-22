import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class TvMinimalApp extends Application.AppBase {
    var face as TvMinimalFace?;

    function initialize() { AppBase.initialize(); }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var initialFace = new TvMinimalFace();
        face = initialFace;
        return [initialFace];
    }

    function onDisplayModeChanged() as Void {
        if (face != null) { face.setDisplayMode(System.getDisplayMode()); }
    }

    function onDeviceSettingChanged(key as Symbol, value as Object) as Void {
        var view = face;
        if (key != :is24Hour || view == null || view.clock24 == (value as Boolean)) { return; }
        view.clock24 = value as Boolean;
        view.activeMinute = -1;
        view.nextClockTick = null;
        if (view.displayMode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onSettingsChanged() as Void {
        var view = face;
        if (view != null) {
            view.loadPreferences();
            if (view.displayMode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
        }
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.TimeColor, null, "timeColor", {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.DataColor, null, "color", {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.BatteryDisplay, null, "batteryStyle", {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ClockRefresh, null, "clockSync", {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ActivityRefresh, null, "interval", {}));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.HeartOnWake, null, "heartOnWake", heartOnWakeEnabled(), {}));
        return [menu, new PreferencesDelegate()];
    }
}
