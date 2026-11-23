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
    const STRIP_W = 276;
    const STRIP_H = 76;
    var mode as System.DisplayMode = System.DISPLAY_MODE_HIGH_POWER;
    var size as Number = 100;
    var heightPercent as Number = 100;
    var strip as Graphics.BufferedBitmap?;
    var brightImage as Graphics.BufferedBitmap?;
    var tryBrightImage as Boolean = true;
    var restMask as Graphics.BitmapReference?;
    var dimInk as Number = (LED_RED >> 1) & 0x7F7F7F;
    var scaledWidth as Number = 0;
    var scaledHeight as Number = 0;
    var maskX as Number = 0;
    var maskY as Number = 0;
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
        var color = chosenColor();
        var newSize = chosenSize();
        var height = chosenHeight();
        if (size != newSize || heightPercent != height) { brightImage = null; }
        size = newSize;
        heightPercent = height;
        tryBrightImage = brightImage == null;
        if (color != ink || (size == 100 && heightPercent == 100)) { strip = null; }
        ink = color;
        dimInk = (ink >> 1) & 0x7F7F7F;
        if (strip == null && (size != 100 || heightPercent != 100)) {
            try {
                strip = Graphics.createBufferedBitmap({:width => STRIP_W, :height => STRIP_H,
                    :palette => [Graphics.COLOR_BLACK, ink, dimInk]}).get() as Graphics.BufferedBitmap?;
            } catch (error instanceof Graphics.OutOfGraphicsMemoryException) {
                // Keep a readable native clock if the graphics pool is temporarily full.
            }
        }
        interval = chosenInterval();
    }

    function onHide() as Void { strip = null; brightImage = null; restMask = null; }

    function invalidateTime() as Void { frameKey = -1; nextRead = null; }
    function onShow() as Void {
        mode = System.getDisplayMode();
        use24 = System.getDeviceSettings().is24Hour;
        loadPreferences();
        invalidateTime();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (mode == System.DISPLAY_MODE_OFF) { return; }
        var dim = mode == System.DISPLAY_MODE_LOW_POWER;
        var font = dim && strip == null ? dimFont : brightFont;
        var tick = dim || interval == 1 ? 0 : System.getTimer();
        if (dim || nextRead == null || tick - (nextRead as Number) >= 0) {
            var clock = System.getClockTime();
            nextRead = dim ? null : nextClockRead(tick, clock.sec, interval);
            var key = (clock.hour * 60 + clock.min) * 2 + (dim ? 1 : 0);
            if (key != frameKey) {
                text = ledTime(clock.hour, clock.min, use24);
                var source = strip;
                if (source == null) {
                    layoutText(dc, font, dim);
                    if (dim) { y = (y & ~1) + (clock.min & 1); }
                } else {
                    prepareStrip(dc, source, dim, clock.min);
                }
                frameKey = key;
            }
        }
        dc.setColor(dim ? dimInk : ink, Graphics.COLOR_BLACK);
        dc.clear();
        var bitmap = strip;
        if (bitmap == null) {
            dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
        } else if (!dim && brightImage != null) {
            dc.drawBitmap(x, y, brightImage);
        } else {
            dc.drawScaledBitmap(x, y, scaledWidth, scaledHeight, bitmap);
            if (dim && restMask != null) { dc.drawBitmap(maskX, maskY, restMask); }
        }
    }

    function prepareStrip(dc as Graphics.Dc, source as Graphics.BufferedBitmap, dim as Boolean, minute as Number) as Void {
        var canvas = source.getDc();
        layoutText(canvas, brightFont, false);
        canvas.setColor(dim ? dimInk : ink, Graphics.COLOR_BLACK);
        canvas.clear();
        canvas.drawText(x, y, brightFont, text, Graphics.TEXT_JUSTIFY_LEFT);
        // Keep both percentages in the numerator until the final pixel rounding.
        scaledWidth = STRIP_W * size * (dim ? 29 : 43) / (100 * 43);
        scaledHeight = STRIP_H * size * heightPercent * (dim ? 45 : 71) / (100 * 100 * 71);
        x = (dc.getWidth() - scaledWidth) / 2;
        y = (dc.getHeight() - scaledHeight) / 2;
        if (dim) {
            if (restMask == null) { restMask = WatchUi.loadResource(Rez.Drawables.RestPixels) as Graphics.BitmapReference; }
            maskX = (dc.getWidth() - 192) / 2;
            maskY = (((dc.getHeight() - 80) / 2) & ~1) + (minute & 1);
        } else {
            if (tryBrightImage) {
                tryBrightImage = false;
                try {
                    // Preserve the native scaler’s edge coverage for arbitrary user colors.
                    brightImage = Graphics.createBufferedBitmap({:width => scaledWidth,
                        :height => scaledHeight, :colorDepth => 16}).get() as Graphics.BufferedBitmap?;
                } catch (error instanceof Graphics.OutOfGraphicsMemoryException) {
                    // Draw directly from the small source strip when only it fits.
                }
            }
            var output = brightImage;
            if (output != null) { output.getDc().drawScaledBitmap(0, 0, scaledWidth, scaledHeight, source); }
        }
    }

    function layoutText(dc as Graphics.Dc, font as Graphics.FontType, dim as Boolean) as Void {
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
    }
}
