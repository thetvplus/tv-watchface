import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const FORMAT_KEY = "clockFormat";
const COLOR_KEY = "timeColor";
const SCALE_KEY = "orbitScale";
const REFRESH_KEY = "orbitRefreshDays";

function selectedScale() as Number {
    var value = Properties.getValue(SCALE_KEY);
    return value instanceof Number && value >= NEAR_SCALE && value <= CONCENTRIC ? value : INNER_FOCUS;
}

function selectedRefreshDays() as Number {
    var value = Properties.getValue(REFRESH_KEY);
    return value instanceof Number && value >= DAILY && value <= EVERY_THREE_DAYS ? value : DEFAULT_REFRESH_DAYS;
}

function selectedColor() as Number {
    return colorSetting(COLOR_KEY, Graphics.COLOR_WHITE);
}

function selectedFormat() as Number {
    var value = Properties.getValue(FORMAT_KEY);
    return value instanceof Number && (value == 12 || value == 24) ? value : 0;
}

class OrbitMenu extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        var colors = key.equals(COLOR_KEY);
        var current;
        var choices;
        if (colors) {
            current = selectedColor();
            choices = [[Graphics.COLOR_WHITE, Rez.Strings.White], [Graphics.COLOR_YELLOW, Rez.Strings.Amber],
                       [Graphics.COLOR_BLUE, Rez.Strings.Blue], [0x96D9AD, Rez.Strings.Green]];
        } else if (key.equals(SCALE_KEY)) {
            current = selectedScale();
            choices = [[INNER_FOCUS, Rez.Strings.InnerScale], [NEAR_SCALE, Rez.Strings.NearScale],
                       [BALANCED, Rez.Strings.BalancedScale], [CONCENTRIC, Rez.Strings.ConcentricScale]];
        } else if (key.equals(REFRESH_KEY)) {
            current = selectedRefreshDays();
            choices = [[DAILY, Rez.Strings.Daily], [DEFAULT_REFRESH_DAYS, Rez.Strings.EveryTwoDays],
                       [EVERY_THREE_DAYS, Rez.Strings.EveryThreeDays]];
        } else {
            current = selectedFormat();
            choices = [[0, Rez.Strings.SystemFormat], [12, Rez.Strings.Twelve], [24, Rez.Strings.TwentyFour]];
        }
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        var focus = addPresets(menu, choices, current);
        if (colors) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.Custom, "#" + current.format("%06X"), -1, {}));
        }
        menu.setFocus(focus);
        WatchUi.pushView(menu, new OrbitChoice(key), WatchUi.SLIDE_UP);
    }
}

class OrbitChoice extends WatchUi.Menu2InputDelegate {
    var key as String;
    function initialize(setting as String) { Menu2InputDelegate.initialize(); key = setting; }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Number;
        if (id == -1) {
            WatchUi.pushView(new WatchUi.TextPicker(selectedColor().format("%06X")), new HexDelegate(key, item), WatchUi.SLIDE_UP);
            return;
        }
        saveSetting(key, key.equals(COLOR_KEY) ? id.format("%06X") : id);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
