import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;

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
