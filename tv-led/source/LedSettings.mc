import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

const COLOR_KEY = "timeColor";
const SYNC_KEY = "clockSync";
const LED_RED = 0xFF3924;

function chosenColor() as Number {
    var rgb = parseHexColor(Properties.getValue(COLOR_KEY));
    return rgb == null ? LED_RED : rgb;
}

function readInterval(value as Properties.ValueType) as Number? {
    if (value instanceof String && value.length() >= 1 && value.length() <= 2) {
        for (var n = 0; n < value.length(); n++) {
            if ("0123456789".find(value.substring(n, n + 1) as String) == null) { return null; }
        }
        value = value.toNumber();
    }
    return (value instanceof Number && value >= 1 && value <= 60) ? value : null;
}

function chosenInterval() as Number {
    var seconds = readInterval(Properties.getValue(SYNC_KEY));
    return seconds == null ? 60 : seconds;
}

function customLabel(color as Boolean, value as Number) as String {
    return color ? "#" + value.format("%06X") : value.toString() + " s";
}

class LedMenu extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var key = item.getId() as String;
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        var colorMenu = key.equals(COLOR_KEY);
        var current = colorMenu ? chosenColor() : chosenInterval();
        var choices = colorMenu
            ? [[LED_RED, Rez.Strings.Red], [0xFF9D30, Rez.Strings.Amber],
               [0x76D889, Rez.Strings.Green], [0xEFEFEF, Rez.Strings.White]]
            : [[60, Rez.Strings.AtMinute], [3, Rez.Strings.ThreeSeconds], [1, Rez.Strings.EverySecond]];
        var focus = choices.size();
        for (var i = 0; i < choices.size(); i++) {
            var id = choices[i][0] as Number;
            menu.addItem(new WatchUi.MenuItem(choices[i][1] as ResourceId, null, id, {}));
            if (current == id) { focus = i; }
        }
        var custom = colorMenu ? Rez.Strings.Custom : Rez.Strings.CustomSeconds;
        menu.addItem(new WatchUi.MenuItem(custom, customLabel(colorMenu, current), -1, {}));
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
            var initial = key.equals(COLOR_KEY) ? chosenColor().format("%06X") : chosenInterval().toString();
            WatchUi.pushView(new WatchUi.TextPicker(initial), new LedEntry(key, item), WatchUi.SLIDE_UP);
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
        var color = key.equals(COLOR_KEY);
        var result = color ? parseHexColor(text) : readInterval(text);
        if (result == null) {
            WatchUi.showToast(color ? Rez.Strings.InvalidHex : Rez.Strings.InvalidSeconds, null);
        } else {
            saveSetting(key, color ? result.format("%06X") : result);
            item.setSubLabel(customLabel(color, result));
        }
        return true;
    }
}
