import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

function ledTime(hour as Number, minute as Number, use24 as Boolean) as String {
    var minutes = ":" + minute.format("%02d");
    if (use24) { return hour.format("%02d") + minutes; }
    var shown = (hour + 11) % 12 + 1;
    return shown.toString() + minutes + (hour < 12 ? "AM" : "PM");
}

function nextClockRead(tick as Number, second as Number, interval as Number) as Number? {
    // A 1 s setting follows each awake callback even when it arrives a few ms early.
    if (interval == 1) { return null; }
    // Start checking one callback before the boundary. The system clock reports whole seconds.
    var untilBoundary = 59 - second;
    return tick + (interval < untilBoundary ? interval : untilBoundary) * 1000;
}

class LedFace extends WatchUi.WatchFace {
    var brightFont as Graphics.FontType = Graphics.FONT_NUMBER_HOT;
    var dimFont as Graphics.FontType = Graphics.FONT_NUMBER_MILD;
    var frameKey as Number = -1;
    var text as String = "";
    var x as Number = 0;
    var y as Number = 0;
    var ink as Number = LED_RED;
    var use24 as Boolean = true;
    var interval as Number = 60;
    var nextRead as Number?;

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Graphics.Dc) as Void {
        brightFont = WatchUi.loadResource(Rez.Fonts.Led) as WatchUi.FontResource;
        dimFont = WatchUi.loadResource(Rez.Fonts.DimLed) as WatchUi.FontResource;
        invalidateTime();
    }

    function loadPreferences() as Void {
        ink = chosenColor();
        interval = chosenInterval();
    }

    function invalidateTime() as Void { frameKey = -1; nextRead = null; }
    function onShow() as Void {
        use24 = System.getDeviceSettings().is24Hour;
        loadPreferences();
        invalidateTime();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var mode = System.getDisplayMode();
        if (mode == System.DISPLAY_MODE_OFF) { return; }
        var dim = mode == System.DISPLAY_MODE_LOW_POWER;
        var font = dim ? dimFont : brightFont;
        var tick = dim || interval == 1 ? 0 : System.getTimer();
        if (dim || nextRead == null || tick - (nextRead as Number) >= 0) {
            var clock = System.getClockTime();
            nextRead = dim ? null : nextClockRead(tick, clock.sec, interval);
            var key = (clock.hour * 60 + clock.min) * 2 + (dim ? 1 : 0);
            if (key != frameKey) {
                text = ledTime(clock.hour, clock.min, use24);
                var chars = text.toCharArray();
                var gap = dim ? 8 : 11;
                var left = 0;
                if (chars[0] == '1') { left = dim ? 24 : 36; }
                else if (chars[0] == '3' || chars[0] == '7') { left = dim ? 5 : 7; }
                x = (dc.getWidth() - dc.getTextWidthInPixels(text, font) + gap - left) / 2;

                // 1 and 4 have neither end bar, 7 only the top. AM/PM inks the baseline.
                var top = dim ? 6 : 7;
                var bottom = use24 ? top : 0;
                for (var i = 0; i < chars.size(); i++) {
                    var ch = chars[i];
                    if (ch == 'A' || ch == 'P') { break; }
                    if (ch == '1' || ch == '4' || ch == ':') { continue; }
                    top = 0;
                    if (ch != '7') { bottom = 0; break; }
                }
                y = (dc.getHeight() - dc.getFontHeight(font) + bottom - top) / 2;
                // Preserve physical scan-line parity even when the optical center changes.
                if (dim) { y = (y & ~1) + (clock.min & 1); }
                frameKey = key;
            }
        }
        dc.setColor(dim ? (ink >> 1) & 0x7F7F7F : ink, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
