import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class TvTerminalApp extends Application.AppBase {
    var face as TerminalFace?;

    function initialize() { AppBase.initialize(); }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new TerminalFace();
        face = view;
        return [view];
    }

    function onDisplayModeChanged() as Void {
        if (face != null) { face.setDisplayMode(System.getDisplayMode()); }
    }

    function onSettingsChanged() as Void {
        if (face != null) { face.applySettings(); }
    }

    function onDeviceSettingChanged(key as Symbol, value as Object) as Void {
        if (face != null) { face.applyDeviceSetting(key, value); }
    }

    function onValidateProperty(key as String, value as Properties.ValueType) as Boolean or String {
        if (isColorKey(key) && parseHexColor(value) == null) {
            return WatchUi.loadResource(Rez.Strings.InvalidHex) as String;
        }
        return true;
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AppName});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.ClockFormat, null, CLOCK_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.TimeColor, null, TIME_COLOR_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.TextColor, null, TEXT_COLOR_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Alignment, null, ALIGN_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.BatteryStyle, null, BATTERY_KEY, {}));
        var labels = [Rez.Strings.RowOne, Rez.Strings.RowTwo, Rez.Strings.RowThree];
        for (var i = 0; i < ROW_KEYS.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(labels[i], null, ROW_KEYS[i], {}));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.TotalsRefresh, null, TOTALS_KEY, {}));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.HeartRefresh, null, HEART_KEY, {}));
        return [menu, new SettingsDelegate()];
    }
}
