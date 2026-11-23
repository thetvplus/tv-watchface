import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const ALIGN_LEFT = 0;
const ALIGN_CENTER = 1;
const TIME_COLOR_KEY = "timeColor";
const TEXT_COLOR_KEY = "textColor";
const ALIGN_KEY = "alignment";
const CLOCK_KEY = "clockFormat";
const TOTALS_KEY = "totalsRefresh";
const HEART_KEY = "heartRefresh";
const BATTERY_KEY = "batteryStyle";
const ROW_KEYS = ["rowOne", "rowTwo", "rowThree"];
const METRIC_NAMES = [Rez.Strings.HeartRate, Rez.Strings.Steps, Rez.Strings.Energy,
    Rez.Strings.Distance, Rez.Strings.Floors];
enum Metric { PULSE, STEPS, KCAL, DISTANCE, FLOORS }
const PHOSPHOR_TIME = 0xA6FF90;
const PHOSPHOR_TEXT = 0x76D889;

function phosphorColor(key as String) as Number {
    return key.equals(TIME_COLOR_KEY) ? PHOSPHOR_TIME : PHOSPHOR_TEXT;
}

function savedColor(key as String) as Number {
    return colorSetting(key, phosphorColor(key));
}

function savedChoice(key as String, fallback as Number, count as Number) as Number {
    var value = Properties.getValue(key);
    if (value instanceof Number && value >= 0 && value < count) { return value; }
    return fallback;
}

function isColorKey(key as String) as Boolean {
    return key.equals(TIME_COLOR_KEY) || key.equals(TEXT_COLOR_KEY);
}

function uses24Hours(choice as Number, device24 as Boolean) as Boolean {
    return choice == 0 ? device24 : choice == 2;
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    const COLORS = [
        [0xefefef, Rez.Strings.White], [0x98d9b7, Rez.Strings.Mint],
        [Graphics.COLOR_GREEN, Rez.Strings.PureGreen], [Graphics.COLOR_DK_GREEN, Rez.Strings.DarkGreen],
        [0x8fbff0, Rez.Strings.Sky], [Graphics.COLOR_BLUE, Rez.Strings.Blue],
        [Graphics.COLOR_PURPLE, Rez.Strings.Purple], [0xf1a8be, Rez.Strings.Rose],
        [Graphics.COLOR_RED, Rez.Strings.Red], [Graphics.COLOR_ORANGE, Rez.Strings.SystemOrange],
        [0xff9500, Rez.Strings.WarmOrange], [0xffbb76, Rez.Strings.Amber]
    ];

    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        if (isColorKey(key)) {
            var current = savedColor(key);
            var green = phosphorColor(key);
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.Phosphor, "#" + green.format("%06X"), green, {}));
            var focus = current == green ? 0 : COLORS.size() + 1;
            for (var i = 0; i < COLORS.size(); i++) {
                var rgb = COLORS[i][0] as Number;
                var name = COLORS[i][1] as ResourceId;
                menu.addItem(new WatchUi.MenuItem(name, "#" + rgb.format("%06X"), rgb, {}));
                if (rgb == current) { focus = i + 1; }
            }
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.Custom, "#" + current.format("%06X"), -1, {}));
            menu.setFocus(focus);
        } else {
            var choices = METRIC_NAMES;
            var fallback = 0;
            if (key.equals(ALIGN_KEY)) {
                choices = [Rez.Strings.Left, Rez.Strings.Center];
            } else if (key.equals(CLOCK_KEY)) {
                choices = [Rez.Strings.FollowWatch, Rez.Strings.TwelveHour, Rez.Strings.TwentyFourHour];
            } else if (key.equals(TOTALS_KEY)) {
                choices = [Rez.Strings.OneMinute, Rez.Strings.FiveMinutes, Rez.Strings.FifteenMinutes];
                fallback = 1;
            } else if (key.equals(HEART_KEY)) {
                choices = [Rez.Strings.OnWake, Rez.Strings.LivePulse];
            } else if (key.equals(BATTERY_KEY)) {
                choices = [Rez.Strings.Percent, Rez.Strings.BatteryIcon];
            } else {
                fallback = ROW_KEYS.indexOf(key) as Number;
            }
            for (var n = 0; n < choices.size(); n++) {
                menu.addItem(new WatchUi.MenuItem(choices[n], null, n, {}));
            }
            menu.setFocus(savedChoice(key, fallback, choices.size()));
        }
        WatchUi.pushView(menu, new PreferenceDelegate(key), WatchUi.SLIDE_UP);
    }
}

class PreferenceDelegate extends WatchUi.Menu2InputDelegate {
    var key as String;

    function initialize(propertyKey as String) {
        Menu2InputDelegate.initialize();
        key = propertyKey;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var choice = item.getId() as Number;
        if (choice == -1) {
            var initial = savedColor(key).format("%06X");
            WatchUi.pushView(new WatchUi.TextPicker(initial), new HexDelegate(key, item), WatchUi.SLIDE_UP);
        } else {
            if (isColorKey(key)) {
                saveSetting(key, choice.format("%06X"));
            } else {
                saveSetting(key, choice);
            }
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}
