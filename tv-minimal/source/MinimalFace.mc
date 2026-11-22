import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

const WEEKDAYS = [Rez.Strings.Sun, Rez.Strings.Mon, Rez.Strings.Tue, Rez.Strings.Wed, Rez.Strings.Thu, Rez.Strings.Fri, Rez.Strings.Sat];

class TvMinimalFace extends WatchUi.WatchFace {
    const MUTED = 0xaab5b1;
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const HEART_INTERVAL_MS = 3000;
    const METRIC_FONT_SIZE = 38;
    const METRIC_COLUMN_STEP = 84;
    // Visible left/right edges relative to each native digit's cell center at the 265S layout size.
    const LEADING_INK = [29, 26, 30];
    const TRAILING_INK = [29, 10, 32, 28, 33, 31, 30, 31, 29, 28];
    var displayMode as System.DisplayMode = System.DISPLAY_MODE_HIGH_POWER;
    var activeMinute as Number = -1;
    var heartTick as Number?;
    var nextClockTick as Number?;
    var centerX as Number = 180;
    var centerY as Number = 180;
    var clockX as Number = 180;
    var clockY as Number = 180;
    var totalsSecond as Number = -1;
    var sampledDay as Number = -1;
    var accent as Number = DEFAULT_DATA_COLOR;
    var timeColor as Number = DEFAULT_TIME_COLOR;
    var interval as Number = DEFAULT_ACTIVITY_MINUTES;
    var clockSync as Number = CLOCK_AT_MINUTE;
    var heartOnWake as Boolean = false;
    var clock24 as Boolean = true;
    var stepsText as String = "--";
    var kcalText as String = "--";
    var heartRate as Number?;
    var heartRateText as String = "--";
    var activeTime as String = "";
    var dateText as String = "";
    var batteryIcon as Boolean = false;
    var batteryLevel as Number = -1;
    var batteryText as String = "--";
    var clockFont as Graphics.FontType = Graphics.FONT_NUMBER_THAI_HOT;
    var aodFont as Graphics.FontType = Graphics.FONT_MEDIUM;
    var metricFont as Graphics.FontType = Graphics.FONT_XTINY;
    var stepsFont as Graphics.FontType = Graphics.FONT_XTINY;
    var kcalFont as Graphics.FontType = Graphics.FONT_XTINY;
    var icons as Graphics.BitmapReference?;
    var aodMask as Graphics.BitmapReference?;
    var background as Graphics.BufferedBitmap?;
    var tryBackground as Boolean = true;
    var backgroundDirty as Boolean = true;
    var displayedMinuteOfDay as Number = -1;

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Graphics.Dc) as Void {
        centerX = dc.getWidth() / 2;
        centerY = dc.getHeight() / 2;
        clockX = centerX;
        clockY = centerY;
        activeMinute = -1;
        nextClockTick = null;
        displayedMinuteOfDay = -1;
        background = null;
        tryBackground = true;
        backgroundDirty = true;
        clockFont = Graphics.FONT_NUMBER_THAI_HOT;
        // Use the installed numeral font. Only measure it when laying out the face.
        var font = Graphics.getVectorFont({:face => "RobotoRegular", :size => 144});
        if (font != null) {
            var width = dc.getTextWidthInPixels("88:88", font);
            if (width > 0 && width != 322) {
                font = Graphics.getVectorFont({:face => "RobotoRegular", :size => (144 * 322 / width)});
            }
            if (font != null) {
                clockFont = font;
                // Native vertical justification puts the visible numerals four pixels below its anchor.
                clockY -= 4;
            }
        }
        var aod = Graphics.getVectorFont({:face => "RobotoRegular", :size => 54});
        aodFont = (aod == null) ? Graphics.FONT_MEDIUM : aod;
        var metric = Graphics.getVectorFont({:face => "RobotoRegular", :size => METRIC_FONT_SIZE});
        metricFont = (metric == null) ? Graphics.FONT_XTINY : metric;
        stepsFont = fitMetricFont(stepsText);
        kcalFont = fitMetricFont(kcalText);
        icons = WatchUi.loadResource(Rez.Drawables.MetricIcons) as Graphics.BitmapReference;
        aodMask = WatchUi.loadResource(Rez.Drawables.AodMask) as Graphics.BitmapReference;
    }

    function onShow() as Void {
        clock24 = System.getDeviceSettings().is24Hour;
        displayMode = System.getDisplayMode();
        dateText = "";
        loadPreferences();
    }

    function loadPreferences() as Void {
        readMinimalSettings(self);
        activeMinute = -1;
        nextClockTick = null;
        heartTick = null;
        tryBackground = background == null;
        backgroundDirty = true;
    }

    function onHide() as Void {
        background = null;
    }

    function setDisplayMode(mode as System.DisplayMode) as Void {
        if (mode == displayMode) { return; }
        displayMode = mode;
        if (mode == System.DISPLAY_MODE_HIGH_POWER) {
            if (!(Application.AppBase has :onDeviceSettingChanged)) {
                clock24 = System.getDeviceSettings().is24Hour;
            }
            nextClockTick = null;
            activeMinute = -1;
            heartTick = null;
        }
        if (mode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (displayMode == System.DISPLAY_MODE_OFF) { return; }
        if (displayMode == System.DISPLAY_MODE_LOW_POWER) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            var clock = System.getClockTime();
            drawAod(dc, clock.hour, clock.min);
            return;
        }
        updateVisible(System.getTimer());
        if (tryBackground) {
            tryBackground = false;
            try {
                background = Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight()}).get() as Graphics.BufferedBitmap?;
            } catch (e instanceof Graphics.OutOfGraphicsMemoryException) {
                // Render directly when the graphics pool has no room for a frame.
            }
        }
        var image = background;
        if (image == null) {
            drawBackground(dc);
        } else {
            if (backgroundDirty) {
                drawBackground(image.getDc());
                backgroundDirty = false;
            }
            dc.drawBitmap(0, 0, image);
        }
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 289, metricFont, heartRateText, CENTER);
    }

    function drawBackground(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        drawBattery(dc);
        dc.setColor(MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 91, Graphics.FONT_XTINY, dateText, CENTER);
        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(clockX, clockY, clockFont, activeTime, CENTER);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        if (icons != null) { dc.drawBitmap(centerX - METRIC_COLUMN_STEP - 10, 255, icons); }
        dc.drawText(centerX - METRIC_COLUMN_STEP, 289, stepsFont, stepsText, CENTER);
        dc.drawText(centerX + METRIC_COLUMN_STEP, 289, kcalFont, kcalText, CENTER);
    }

    function drawAod(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        dc.setColor((timeColor >> 2) & 0x3f3f3f, Graphics.COLOR_TRANSPARENT);
        // The visible digits of the 54 px face sit one pixel below the font anchor.
        dc.drawText(centerX, centerY - 1, aodFont, formatTime(displayHour(hour), minute), CENTER);
        if (aodMask != null) {
            // Shift a 2 x 2 mask through all four offsets. Each physical pixel rests
            // at least once in four minutes while the numerals stay centered.
            dc.drawBitmap(centerX - 64 + (minute & 1), centerY - 24 + ((minute >> 1) & 1), aodMask);
        }
    }

    function drawBattery(dc as Graphics.Dc) as Void {
        if (!batteryIcon || batteryLevel < 0) {
            dc.drawText(centerX, 49, Graphics.FONT_XTINY, batteryText, CENTER);
            return;
        }
        var left = centerX - 16;
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(left + 1, 43, 27, 13, 3);
        dc.setPenWidth(1);
        dc.fillRectangle(left + 30, 46, 2, 6);
        if (batteryLevel > 0) {
            // Both the first and last percent are distinguishable from empty and full.
            dc.fillRectangle(left + 4, 46, 1 + (batteryLevel - 1) * 21 / 99, 7);
        }
    }

    function updateVisible(tick as Number) as Void {
        // Subtract ticks so a signed millisecond counter can wrap between frames.
        if (nextClockTick == null || tick - (nextClockTick as Number) >= 0) {
            nextClockTick = tick + updateClockAndTotals(readWallClock());
        }
        if (heartTick != null) {
            if (heartOnWake && heartRate != null) { return; }
            if (tick - (heartTick as Number) < HEART_INTERVAL_MS) { return; }
        }
        heartTick = tick;
        var bpm = currentHeartRate();
        if (bpm != null && (bpm <= 0 || bpm == ActivityMonitor.INVALID_HR_SAMPLE)) { bpm = null; }
        if (bpm != heartRate) {
            heartRate = bpm;
            heartRateText = (bpm == null) ? "--" : bpm.toString();
        }
    }

    function readWallClock() as Time.Moment { return Time.now(); }

    function updateClockAndTotals(now as Time.Moment) as Number {
        var seconds = now.value();
        var minute = seconds / 60;
        if (minute != activeMinute) {
            var date = Gregorian.info(now, Time.FORMAT_SHORT);
            setActiveClock(date.hour, date.min);
            var day = date.year * 10000 + (date.month as Number) * 100 + date.day;
            if (day != sampledDay) {
                sampledDay = day;
                totalsSecond = -1;
            }
            if (totalsSecond < 0 || dateText.equals("")) {
                var weekday = (date.day_of_week as Number) - 1;
                dateText = date.day.toString() + " · " + (WatchUi.loadResource(WEEKDAYS[weekday]) as String);
            }
            activeMinute = minute;
        }
        var untilTotals = interval * 60 - (seconds - totalsSecond);
        if (totalsSecond < 0 || seconds < totalsSecond || untilTotals <= 0) {
            readActivityTotals();
            var level = System.getSystemStats().battery.toNumber();
            if (level < 0 || level > 100) { level = -1; }
            if (level != batteryLevel) {
                batteryLevel = level;
                batteryText = (level < 0) ? "--" : level.toString() + "%";
            }
            backgroundDirty = true;
            totalsSecond = seconds;
            untilTotals = interval * 60;
        }
        // Wall time has whole-second precision. Check one second early at absolute deadlines.
        var delay = 59 - seconds % 60;
        if (clockSync > 0 && clockSync < delay) { delay = clockSync; }
        if (delay >= untilTotals) { delay = untilTotals - 1; }
        return (clockSync == 1 || delay <= 0) ? 0 : delay * 1000;
    }

    function currentHeartRate() as Number? {
        return Activity.getActivityInfo().currentHeartRate;
    }

    function readActivityTotals() as Void {
        var info = ActivityMonitor.getInfo();
        stepsText = formatMetric(info.steps);
        kcalText = formatMetric(info.calories);
        stepsFont = fitMetricFont(stepsText);
        kcalFont = fitMetricFont(kcalText);
    }

    function fitMetricFont(text as String) as Graphics.FontType {
        var count = text.length();
        if (count <= 5) { return metricFont; }
        // Keep all digits inside the outer columns, including six-digit step totals.
        var font = Graphics.getVectorFont({:face => "RobotoRegular", :size => METRIC_FONT_SIZE * 5 / count});
        return (font == null) ? Graphics.FONT_XTINY : font;
    }

    function setActiveClock(hour as Number, minute as Number) as Void {
        var shownHour = displayHour(hour);
        var nextMinute = shownHour * 60 + minute;
        if (nextMinute == displayedMinuteOfDay) { return; }
        displayedMinuteOfDay = nextMinute;
        backgroundDirty = true;
        activeTime = formatTime(shownHour, minute);
        if (clockFont instanceof Graphics.VectorFont) {
            clockX = centerX + (LEADING_INK[shownHour / 10] - TRAILING_INK[minute % 10]) / 2;
        }
    }

    function displayHour(hour as Number) as Number {
        return clock24 ? hour : ((hour + 11) % 12) + 1;
    }

    function formatTime(hour as Number, minute as Number) as String {
        return hour.format("%02d") + ":" + minute.format("%02d");
    }

    function formatMetric(value as Number?) as String {
        return (value == null) ? "--" : value.toString();
    }
}
