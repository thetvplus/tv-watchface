import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const FORMAT_KEY = "clockFormat";
const COLOR_KEY = "timeColor";

const SCALE_KEY = "orbitScale";

function selectedScale() as Number {
    var value = Properties.getValue(SCALE_KEY);
    return value instanceof Number && (value == LINEAR || value == LOG_SCALE) ? value : INNER_FOCUS;
}

function selectedColor() as Number {
    var color = parseHexColor(Properties.getValue(COLOR_KEY));
    return color == null ? Graphics.COLOR_WHITE : color;
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
            choices = [[INNER_FOCUS, Rez.Strings.InnerScale], [LINEAR, Rez.Strings.LinearScale], [LOG_SCALE, Rez.Strings.LogScale]];
        } else {
            current = selectedFormat();
            choices = [[0, Rez.Strings.SystemFormat], [12, Rez.Strings.Twelve], [24, Rez.Strings.TwentyFour]];
        }
        var menu = new WatchUi.Menu2({:title => item.getLabel()});
        var focus = choices.size();
        for (var i = 0; i < choices.size(); i++) {
            var id = choices[i][0] as Number;
            menu.addItem(new WatchUi.MenuItem(choices[i][1] as ResourceId, null, id, {}));
            if (id == current) { focus = i; }
        }
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
            WatchUi.pushView(new WatchUi.TextPicker(selectedColor().format("%06X")), new OrbitHex(item), WatchUi.SLIDE_UP);
            return;
        }
        saveSetting(key, key.equals(COLOR_KEY) ? id.format("%06X") : id);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class OrbitHex extends WatchUi.TextPickerDelegate {
    var item as WatchUi.MenuItem;
    function initialize(row as WatchUi.MenuItem) { TextPickerDelegate.initialize(); item = row; }
    function onTextEntered(value as String, changed as Boolean) as Boolean {
        if (!changed) { return true; }
        var rgb = parseHexColor(value);
        if (rgb == null) { WatchUi.showToast(Rez.Strings.InvalidHex, null); }
        else {
            var hex = rgb.format("%06X");
            saveSetting(COLOR_KEY, hex);
            item.setSubLabel("#" + hex);
        }
        return true;
    }
}
