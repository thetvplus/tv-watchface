import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

function parseHexColor(raw as Properties.ValueType) as Number? {
    if (!(raw instanceof String)) { return null; }
    var hex = raw.toUpper();
    if (hex.length() == 7 && hex.find("#") == 0) { hex = hex.substring(1, 7) as String; }
    if (hex.length() != 6) { return null; }
    var rgb = hex.toNumberWithBase(16);
    return rgb != null && rgb.format("%06X").equals(hex) ? rgb : null;
}

function saveSetting(key as String, value as String or Number) as Void {
    Properties.setValue(key, value);
    Application.getApp().onSettingsChanged();
}

function colorSetting(key as String, fallback as Number) as Number {
    var color = parseHexColor(Properties.getValue(key));
    return color == null ? fallback : color;
}

function addPresets(menu as WatchUi.Menu2, choices as Array, current as Number) as Number {
    var focus = choices.size();
    for (var i = 0; i < choices.size(); i++) {
        var choice = choices[i] as Array;
        var value = choice[0] as Number;
        menu.addItem(new WatchUi.MenuItem(choice[1] as ResourceId, null, value, {}));
        if (value == current) { focus = i; }
    }
    return focus;
}

class HexDelegate extends WatchUi.TextPickerDelegate {
    var key as String;
    var item as WatchUi.MenuItem;
    function initialize(propertyKey as String, row as WatchUi.MenuItem) {
        TextPickerDelegate.initialize();
        key = propertyKey;
        item = row;
    }
    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (!changed) { return true; }
        var rgb = parseHexColor(text);
        if (rgb == null) {
            WatchUi.showToast(Rez.Strings.InvalidHex, null);
        } else {
            var hex = rgb.format("%06X");
            saveSetting(key, hex);
            item.setSubLabel("#" + hex);
        }
        return true;
    }
}
