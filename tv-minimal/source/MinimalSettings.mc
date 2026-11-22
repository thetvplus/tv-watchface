import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const COLOR_MINT = 0x98d9b7;
const COLOR_SOFT_WHITE = 0xefefef;
const COLOR_WARM_ORANGE = 0xff9500;
const DEFAULT_DATA_COLOR = COLOR_MINT;
const DEFAULT_TIME_COLOR = COLOR_SOFT_WHITE;
const DEFAULT_ACTIVITY_MINUTES = 5;
const CLOCK_AT_MINUTE = 0;
const BATTERY_PERCENT = 0;
const BATTERY_ICON = 1;

function heartOnWakeEnabled() as Boolean {
    return (Storage.getValue("heartOnWake") as Boolean?) == true;
}

function readMinimalSettings(view as TvMinimalFace) as Void {
    var color = Storage.getValue("color") as Number?;
    var digitColor = Storage.getValue("timeColor") as Number?;
    var minutes = Storage.getValue("interval") as Number?;
    var sync = Storage.getValue("clockSync") as Number?;
    view.accent = (color == null) ? DEFAULT_DATA_COLOR : color;
    view.timeColor = (digitColor == null) ? DEFAULT_TIME_COLOR : digitColor;
    var style = Storage.getValue("batteryStyle");
    view.batteryIcon = style instanceof Number && style == BATTERY_ICON;
    view.interval = (minutes == 1 || minutes == 15) ? (minutes as Number) : DEFAULT_ACTIVITY_MINUTES;
    view.clockSync = (sync == 1 || sync == 3) ? (sync as Number) : CLOCK_AT_MINUTE;
    view.heartOnWake = heartOnWakeEnabled();
}

class PreferencesDelegate extends WatchUi.Menu2InputDelegate {
    const COLOR_CHOICES = [
        [COLOR_SOFT_WHITE, Rez.Strings.White],
        [COLOR_MINT, Rez.Strings.Mint],
        [Graphics.COLOR_GREEN, Rez.Strings.PureGreen],
        [Graphics.COLOR_DK_GREEN, Rez.Strings.DarkGreen],
        [0x8fbff0, Rez.Strings.Sky],
        [Graphics.COLOR_BLUE, Rez.Strings.Blue],
        [Graphics.COLOR_PURPLE, Rez.Strings.Purple],
        [0xf1a8be, Rez.Strings.Rose],
        [Graphics.COLOR_RED, Rez.Strings.Red],
        [Graphics.COLOR_ORANGE, Rez.Strings.SystemOrange],
        [COLOR_WARM_ORANGE, Rez.Strings.WarmOrange],
        [0xffbb76, Rez.Strings.Amber]
    ];
    const INTERVAL_CHOICES = [
        [1, Rez.Strings.OneMinute],
        [5, Rez.Strings.FiveMinutes],
        [15, Rez.Strings.FifteenMinutes]
    ];
    const CLOCK_CHOICES = [
        [CLOCK_AT_MINUTE, Rez.Strings.AtMinute],
        [3, Rez.Strings.ThreeSeconds],
        [1, Rez.Strings.EverySecond]
    ];
    const BATTERY_CHOICES = [
        [BATTERY_PERCENT, Rez.Strings.Percentage],
        [BATTERY_ICON, Rez.Strings.BatteryIcon]
    ];

    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            Storage.setValue(key, item.isEnabled());
            Application.getApp().onSettingsChanged();
            return;
        }
        var choices = COLOR_CHOICES;
        var fallback = DEFAULT_DATA_COLOR;
        if (key.equals("interval")) {
            choices = INTERVAL_CHOICES;
            fallback = DEFAULT_ACTIVITY_MINUTES;
        } else if (key.equals("clockSync")) {
            choices = CLOCK_CHOICES;
            fallback = CLOCK_AT_MINUTE;
        } else if (key.equals("batteryStyle")) {
            choices = BATTERY_CHOICES;
            fallback = BATTERY_PERCENT;
        } else if (key.equals("timeColor")) {
            fallback = DEFAULT_TIME_COLOR;
        }
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        var current = Storage.getValue(key) as Number?;
        if (current == null) { current = fallback; }
        for (var i = 0; i < choices.size(); i++) {
            var choice = choices[i];
            menu.addItem(new WatchUi.MenuItem(choice[1], null, choice[0], {}));
            if (current == choice[0]) { menu.setFocus(i); }
        }
        WatchUi.pushView(menu, new ChoiceDelegate(key), WatchUi.SLIDE_UP);
    }
}

class ChoiceDelegate extends WatchUi.Menu2InputDelegate {
    var key as String;
    function initialize(settingKey as String) {
        Menu2InputDelegate.initialize();
        key = settingKey;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Storage.setValue(key, item.getId() as Number);
        Application.getApp().onSettingsChanged();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
