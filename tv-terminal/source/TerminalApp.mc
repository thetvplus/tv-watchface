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
        if (face != null) { face.loadSettings(); }
        if (System.getDisplayMode() != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onDeviceSettingChanged(key as Symbol, value as Object) as Void {
        var view = face;
        if (view == null) { return; }
        if (key == :is24Hour) {
            if (view.use24 == (value as Boolean) || savedChoice(CLOCK_KEY, 0, 3) != 0) { return; }
            view.use24 = value as Boolean;
        } else if (key == :distanceUnits) {
            var metric = value == System.UNIT_METRIC;
            if (view.metricUnits == metric) { return; }
            view.metricUnits = metric;
            if (view.rows.indexOf(DISTANCE) < 0) { return; }
            view.sampledSecond = -1;
        } else { return; }
        view.shownMinute = -1;
        view.nextCheck = null;
        if (view.mode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
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
