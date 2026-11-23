import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

const COLOR_KEY = "timeColor";
const SYNC_KEY = "clockSync";
const SIZE_KEY = "digitSize";
const HEIGHT_KEY = "digitHeight";
const LED_RED = 0xFF3924;

function chosenColor() as Number {
    return colorSetting(COLOR_KEY, LED_RED);
}

function readRange(value as Properties.ValueType, low as Number, high as Number) as Number? {
    if (value instanceof String && value.length() >= 1 && value.length() <= high.toString().length()) {
        for (var n = 0; n < value.length(); n++) {
            if ("0123456789".find(value.substring(n, n + 1) as String) == null) { return null; }
        }
        value = value.toNumber();
    }
    return (value instanceof Number && value >= low && value <= high) ? value : null;
}

function readInterval(value as Properties.ValueType) as Number? {
    return readRange(value, 1, 60);
}

function chosenSize() as Number {
    var size = Properties.getValue(SIZE_KEY);
    return size instanceof Number && (size == 60 || size == 80) ? size : 100;
}

function chosenHeight() as Number {
    var height = readRange(Properties.getValue(HEIGHT_KEY), 50, 150);
    return height == null ? 100 : height;
}

function chosenInterval() as Number {
    var seconds = readInterval(Properties.getValue(SYNC_KEY));
    return seconds == null ? 60 : seconds;
}

function customLabel(key as String, value as Number) as String {
    return key.equals(COLOR_KEY) ? "#" + value.format("%06X") : value.toString() + (key.equals(HEIGHT_KEY) ? "%" : " s");
}

class LedMenu extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        var current;
        var choices;
        var custom = null;
        if (key.equals(COLOR_KEY)) {
            current = chosenColor();
            choices = [[LED_RED, Rez.Strings.Red], [0xFF9D30, Rez.Strings.Amber],
                       [0x76D889, Rez.Strings.Green], [0xEFEFEF, Rez.Strings.White]];
            custom = Rez.Strings.Custom;
        } else if (key.equals(SIZE_KEY)) {
            current = chosenSize();
            choices = [[100, Rez.Strings.Large], [80, Rez.Strings.MediumSize], [60, Rez.Strings.Small]];
        } else if (key.equals(HEIGHT_KEY)) {
            current = chosenHeight();
            choices = [[100, Rez.Strings.Normal], [125, Rez.Strings.Tall], [75, Rez.Strings.ShortHeight]];
            custom = Rez.Strings.CustomHeight;
        } else {
            current = chosenInterval();
            choices = [[60, Rez.Strings.AtMinute], [3, Rez.Strings.ThreeSeconds], [1, Rez.Strings.EverySecond]];
            custom = Rez.Strings.CustomSeconds;
        }
        var focus = addPresets(menu, choices, current);
        if (custom != null) { menu.addItem(new WatchUi.MenuItem(custom, customLabel(key, current), -1, {})); }
        menu.setFocus(focus);
        WatchUi.pushView(menu, new LedChoice(key), WatchUi.SLIDE_UP);
    }
}

class LedChoice extends WatchUi.Menu2InputDelegate {
    var key as String;
    function initialize(propertyKey as String) { Menu2InputDelegate.initialize(); key = propertyKey; }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        if (value == -1) {
            if (key.equals(COLOR_KEY)) {
                WatchUi.pushView(new WatchUi.TextPicker(chosenColor().format("%06X")), new HexDelegate(key, item), WatchUi.SLIDE_UP);
            } else {
                var current = key.equals(HEIGHT_KEY) ? chosenHeight() : chosenInterval();
                WatchUi.pushView(new WatchUi.TextPicker(current.toString()), new LedEntry(key, item), WatchUi.SLIDE_UP);
            }
            return;
        }
        saveSetting(key, key.equals(COLOR_KEY) ? value.format("%06X") : value);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class LedEntry extends WatchUi.TextPickerDelegate {
    var key as String;
    var item as WatchUi.MenuItem;
    function initialize(propertyKey as String, menuItem as WatchUi.MenuItem) {
        TextPickerDelegate.initialize();
        key = propertyKey;
        item = menuItem;
    }
    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (!changed) { return true; }
        var height = key.equals(HEIGHT_KEY);
        var result = height ? readRange(text, 50, 150) : readInterval(text);
        if (result == null) {
            WatchUi.showToast(height ? Rez.Strings.InvalidHeight : Rez.Strings.InvalidSeconds, null);
        } else {
            saveSetting(key, result);
            item.setSubLabel(customLabel(key, result));
        }
        return true;
    }
}
