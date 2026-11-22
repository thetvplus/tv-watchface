import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

function orbitTime(hour as Number, minute as Number, use24 as Boolean) as String {
    var h = use24 ? hour.format("%02d") : ((hour + 11) % 12 + 1).toString();
    return h + ":" + minute.format("%02d");
}

function orbitDate(month as Number, day as Number) as String {
    return month.format("%02d") + "-" + day.format("%02d");
}

class OrbitFace extends WatchUi.WatchFace {
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    var chart as OrbitChart = new OrbitChart();
    var mask as Graphics.BitmapReference?;
    var choice as Number = 0;
    var use24 as Boolean = true;
    var ink as Number = Graphics.COLOR_WHITE;
    var seenMinute as Number?;
    var nextRead as Number?;
    var seenDate as Number = -1;
    var digits as String = "";
    var date as String = "";

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Graphics.Dc) as Void {
        mask = WatchUi.loadResource(Rez.Drawables.RestRows) as Graphics.BitmapReference;
        seenMinute = null;
        nextRead = null;
    }

    function onShow() as Void { loadPreferences(); }

    function syncSystem() as Void {
        setClockFormat(choice == 0 ? System.getDeviceSettings().is24Hour : choice == 24);
    }

    function setClockFormat(is24 as Boolean) as Void {
        use24 = is24;
        seenMinute = null;
        nextRead = null;
    }

    function loadPreferences() as Void {
        choice = selectedFormat();
        ink = selectedColor();
        chart.setScale(selectedScale());
        syncSystem();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var mode = System.getDisplayMode();
        if (mode == System.DISPLAY_MODE_OFF) { return; }
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (mode == System.DISPLAY_MODE_LOW_POWER) {
            var clock = System.getClockTime();
            drawAmbient(dc, clock.hour, clock.min);
            return;
        }
        var tick = System.getTimer();
        if (nextRead == null || tick - (nextRead as Number) >= 0) { updateTime(Time.now(), tick); }
        chart.draw(dc, cx, cy);
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 148, Graphics.FONT_XTINY, digits, CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 148, Graphics.FONT_XTINY, date, CENTER);
    }

    function updateTime(now as Time.Moment, tick as Number) as Void {
        var seconds = now.value();
        nextRead = tick + (59 - seconds % 60) * 1000;
        var minute = seconds / 60;
        if (minute == seenMinute) { return; }
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        digits = orbitTime(local.hour, local.min, use24);
        if (!use24) { digits += local.hour < 12 ? " AM" : " PM"; }
        var month = local.month as Number;
        var day = month * 32 + local.day;
        if (day != seenDate) { date = orbitDate(month, local.day); seenDate = day; }
        chart.update(seconds);
        seenMinute = minute;
    }

    function drawAmbient(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        var label = orbitTime(hour, minute, use24);
        if (!use24) { label += hour < 12 ? " AM" : " PM"; }
        var cy = dc.getHeight() / 2;
        dc.setColor((ink >> 1) & 0x7F7F7F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, cy, Graphics.FONT_SMALL, label, CENTER);
        // The mask alternates physical scan lines, including the AM/PM marker.
        if (mask != null) { dc.drawBitmap(0, cy - 36 + (minute & 1), mask); }
    }
}
