import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

function orbitTime(hour as Number, minute as Number, use24 as Boolean) as String {
    var suffix = ":" + minute.format("%02d");
    if (use24) { return hour.format("%02d") + suffix; }
    return ((hour + 11) % 12 + 1).toString() + suffix + (hour < 12 ? " AM" : " PM");
}

class OrbitFace extends WatchUi.WatchFace {
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    var cx as Number = 180;
    var cy as Number = 180;
    var chart as OrbitChart = new OrbitChart();
    var mode as System.DisplayMode = System.DISPLAY_MODE_OFF;
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
        cx = dc.getWidth() / 2;
        cy = dc.getHeight() / 2;
    }

    function onShow() as Void {
        mode = System.getDisplayMode();
        loadPreferences();
    }

    function setDisplayMode(newMode as System.DisplayMode) as Void {
        mode = newMode;
        if (mode != System.DISPLAY_MODE_HIGH_POWER) { return; }
        var needsDeviceFormat = choice == 0 && !(Application.AppBase has :onDeviceSettingChanged);
        setClockFormat(needsDeviceFormat ? System.getDeviceSettings().is24Hour : use24);
    }

    function setClockFormat(is24 as Boolean) as Void {
        use24 = is24;
        seenMinute = null;
        nextRead = null;
    }

    function loadPreferences() as Void {
        choice = selectedFormat();
        ink = selectedColor();
        chart.configure(selectedScale(), selectedRefreshDays());
        setClockFormat(choice == 0 ? System.getDeviceSettings().is24Hour : choice == 24);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (mode == System.DISPLAY_MODE_OFF) { return; }
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
        if (minute == seenMinute && chart.periodStart != null) { return; }
        chart.update(seconds);
        var local = Gregorian.info(now, Time.FORMAT_SHORT);
        digits = orbitTime(local.hour, local.min, use24);
        var month = local.month as Number;
        var day = month * 32 + local.day;
        if (day != seenDate) {
            date = month.format("%02d") + "-" + local.day.format("%02d");
            seenDate = day;
        }
        seenMinute = minute;
    }

    function drawAmbient(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        if (mask == null) { mask = WatchUi.loadResource(Rez.Drawables.RestRows) as Graphics.BitmapReference; }
        var rows = mask as Graphics.BitmapReference;
        dc.setColor((ink >> 1) & 0x7F7F7F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, orbitTime(hour, minute, use24), CENTER);
        // The mask alternates physical scan lines, including the AM/PM marker.
        dc.drawBitmap(cx - rows.getWidth() / 2, cy - rows.getHeight() / 2 + (minute & 1), rows);
    }
}
