import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

const WEEKDAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
const SAMPLE_INTERVALS = [60, 300, 900];
const FIELD_LABELS = ["PULSE", "STEPS", "KCAL", "DIST", "FLOORS"];

function tinted(color as Number, percent as Number) as Number {
    var r = ((color >> 16) & 255) * percent / 100;
    var g = ((color >> 8) & 255) * percent / 100;
    var b = (color & 255) * percent / 100;
    return (r << 16) | (g << 8) | b;
}

function terminalTime(hour as Number, minute as Number, use24 as Boolean) as String {
    var shown = use24 ? hour : (hour + 11) % 12 + 1;
    return shown.format("%02d") + ":" + minute.format("%02d");
}

function meridiem(hour as Number) as String {
    return hour < 12 ? "AM" : "PM";
}

function counterText(value as Number?) as String {
    if (value == null || value < 0) { return "--"; }
    if (value >= 100000000) { return (value / 1000000).toString() + "M"; }
    return value.toString();
}

function distanceText(cm as Number?, metric as Boolean) as String {
    if (cm == null || cm < 0) { return "--"; }
    var distance = cm / (metric ? 100000.0 : 160934.4);
    return distance.format(distance >= 1000 ? "%.0f" : "%.2f") + (metric ? " KM" : " MI");
}

class TerminalFace extends WatchUi.WatchFace {
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT;
    const TABLE_WIDTH = 196;
    var centered as Boolean = false;
    var use24 as Boolean = true;
    var metricUnits as Boolean = true;
    var rows as Array<Number> = [PULSE, STEPS, KCAL];
    var values as Array<String> = ["-- BPM", "--", "--", "--", "--"];
    var wakeOnly as Boolean = true;
    var sampleInterval as Number = 300;
    var pulseTick as Number?;
    var bpm as Number?;
    var historyExpires as Number = 0;
    var timeInk as Number = PHOSPHOR_TIME;
    var textInk as Number = PHOSPHOR_TEXT;
    var labelInk as Number = PHOSPHOR_TEXT;
    var ruleInk as Number = PHOSPHOR_TEXT;
    var sleepInk as Number = PHOSPHOR_TIME;
    var clockFont as Graphics.FontType = Graphics.FONT_NUMBER_HOT;
    var textFont as Graphics.FontType = Graphics.FONT_XTINY;
    var sleepFont as Graphics.FontType = Graphics.FONT_MEDIUM;
    var mode as System.DisplayMode = System.DISPLAY_MODE_HIGH_POWER;
    var frame as Graphics.BufferedBitmap?;
    var tryFrame as Boolean = true;
    var dirty as Boolean = true;
    var nextCheck as Number?;
    var shownMinute as Number = -1;
    var localDay as Number = -1;
    var sampledSecond as Number = -1;
    var timeText as String = "";
    var periodText as String = "";
    var dateText as String = "";
    var batteryText as String = "--";
    var battery as Number = -1;
    var batteryIcon as Boolean = false;

    function initialize() { WatchFace.initialize(); }

    function onLayout(dc as Graphics.Dc) as Void {
        clockFont = WatchUi.loadResource(Rez.Fonts.Clock) as WatchUi.FontResource;
        textFont = WatchUi.loadResource(Rez.Fonts.Console) as WatchUi.FontResource;
        sleepFont = WatchUi.loadResource(Rez.Fonts.SleepClock) as WatchUi.FontResource;
        discardFrame();
    }

    function discardFrame() as Void {
        frame = null;
        tryFrame = true;
        dirty = true;
    }

    function loadSettings() as Void {
        centered = savedChoice(ALIGN_KEY, ALIGN_LEFT, 2) == ALIGN_CENTER;
        batteryIcon = savedChoice(BATTERY_KEY, 0, 2) == 1;
        var device = System.getDeviceSettings();
        use24 = uses24Hours(savedChoice(CLOCK_KEY, 0, 3), device.is24Hour);
        if (metricUnits != (device.distanceUnits == System.UNIT_METRIC)) { sampledSecond = -1; }
        metricUnits = device.distanceUnits == System.UNIT_METRIC;
        for (var i = 0; i < rows.size(); i++) {
            var field = savedChoice(ROW_KEYS[i], i, FIELD_LABELS.size());
            if (rows[i] != field) { sampledSecond = -1; }
            rows[i] = field;
        }
        sampleInterval = SAMPLE_INTERVALS[savedChoice(TOTALS_KEY, 1, 3)];
        wakeOnly = savedChoice(HEART_KEY, 0, 2) == 0;
        timeInk = savedColor(TIME_COLOR_KEY);
        textInk = savedColor(TEXT_COLOR_KEY);
        labelInk = tinted(textInk, 77);
        ruleInk = tinted(textInk, 41);
        sleepInk = tinted(timeInk, 50);
        shownMinute = -1;
        nextCheck = null;
        pulseTick = null;
        discardFrame();
    }

    function onShow() as Void {
        loadSettings();
        mode = System.getDisplayMode();
    }

    function onHide() as Void { discardFrame(); }

    function setDisplayMode(newMode as System.DisplayMode) as Void {
        if (newMode == mode) { return; }
        mode = newMode;
        nextCheck = null;
        pulseTick = null;
        if (mode == System.DISPLAY_MODE_HIGH_POWER && !(Application.AppBase has :onDeviceSettingChanged)) {
            loadSettings();
        }
        if (mode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    // One shared margin keeps even the lowest left-aligned data row inside the round panel.
    function lineX(dc as Graphics.Dc, width as Number) as Number {
        return centered ? (dc.getWidth() - width) / 2 : 68;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (mode == System.DISPLAY_MODE_OFF) { return; }
        if (mode == System.DISPLAY_MODE_LOW_POWER) {
            var clock = System.getClockTime();
            var value = terminalTime(clock.hour, clock.min, use24);
            if (!use24) { value += meridiem(clock.hour); }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            dc.setColor(sleepInk, Graphics.COLOR_TRANSPARENT);
            // The font only inks even rows. A one-pixel shift rests every lit row next minute.
            var inset = value.find("1") == 0 ? 3 : 0;
            dc.drawText(lineX(dc, dc.getTextWidthInPixels(value, sleepFont) - 3 - inset) - inset,
                (dc.getHeight() - 30) / 2 + (clock.min & 1), sleepFont, value, LEFT);
            return;
        }

        var tick = System.getTimer();
        if (nextCheck == null || tick - (nextCheck as Number) >= 0) { refreshClock(Time.now(), tick); }
        var pulseChanged = refreshPulse(tick);
        if (tryFrame) {
            tryFrame = false;
            try {
                var colors = [Graphics.COLOR_BLACK, ruleInk, labelInk, textInk, timeInk];
                frame = Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight(),
                    :palette => colors}).get() as Graphics.BufferedBitmap?;
            } catch (error instanceof Graphics.OutOfGraphicsMemoryException) {
                // Direct drawing also works when another view is using the graphics pool.
            }
        }
        var cached = frame;
        if (cached == null) {
            drawTerminal(dc);
        } else {
            if (dirty) {
                drawTerminal(cached.getDc());
                dirty = false;
            } else if (pulseChanged) {
                var canvas = cached.getDc();
                for (var i = 0; i < rows.size(); i++) {
                    if (rows[i] == PULSE) { drawRow(canvas, i); }
                }
            }
            dc.drawBitmap(0, 0, cached);
        }
    }

    function refreshClock(now as Time.Moment, tick as Number) as Void {
        var second = now.value();
        var minute = second / 60;
        // Recheck near the next minute. Repeated high-power callbacks only blit the frame.
        nextCheck = tick + (59 - second % 60) * 1000;
        if (minute == shownMinute) { return; }
        shownMinute = minute;
        var date = Gregorian.info(now, Time.FORMAT_SHORT);
        timeText = terminalTime(date.hour, date.min, use24);
        periodText = use24 ? "" : meridiem(date.hour);
        var month = date.month as Number;
        var day = date.year * 10000 + month * 100 + date.day;
        if (day != localDay) {
            dateText = WEEKDAYS[(date.day_of_week as Number) - 1] + " " + month.format("%02d") + "-" + date.day.format("%02d");
            localDay = day;
            sampledSecond = -1;
        }
        if (sampledSecond < 0 || second < sampledSecond || second - sampledSecond >= sampleInterval) {
            readStats(second);
        }
        if (historyExpires > 0 && (second >= historyExpires || second < historyExpires - 900)) {
            bpm = null;
            values[PULSE] = "-- BPM";
            historyExpires = 0;
            pulseTick = null;
        }
        dirty = true;
    }

    function readStats(second as Number) as Void {
        sampledSecond = second;
        battery = System.getSystemStats().battery.toNumber();
        batteryText = (battery < 0 || battery > 100) ? "--" : battery.toString() + "%";
        if (rows[0] == PULSE && rows[1] == PULSE && rows[2] == PULSE) { return; }
        var info = ActivityMonitor.getInfo();
        if (rows.indexOf(STEPS) >= 0) { values[STEPS] = counterText(info.steps); }
        if (rows.indexOf(KCAL) >= 0) { values[KCAL] = counterText(info.calories); }
        if (rows.indexOf(DISTANCE) >= 0) { values[DISTANCE] = distanceText(info.distance, metricUnits); }
        if (rows.indexOf(FLOORS) >= 0) { values[FLOORS] = counterText(info.floorsClimbed); }
    }

    function currentPulse() as Number? { return Activity.getActivityInfo().currentHeartRate; }

    function recentPulse() as Number? {
        var now = Time.now().value();
        var history = ActivityMonitor.getHeartRateHistory(new Time.Duration(900), true);
        for (var sample = history.next(); sample != null; sample = history.next()) {
            var rate = sample.heartRate;
            var when = sample.when;
            if (when == null) { continue; }
            var recorded = when.value();
            if (now - recorded >= 900) { break; }
            if (recorded <= now && rate != null && rate > 0 && rate != ActivityMonitor.INVALID_HR_SAMPLE) {
                historyExpires = recorded + 900;
                return rate;
            }
        }
        return null;
    }

    function refreshPulse(tick as Number) as Boolean {
        if (rows.indexOf(PULSE) < 0) { return false; }
        if (pulseTick != null && ((wakeOnly && bpm != null) || tick - (pulseTick as Number) < 3000)) {
            return false;
        }
        var first = pulseTick == null;
        pulseTick = tick;
        var rate = currentPulse();
        if (rate != null && (rate <= 0 || rate == ActivityMonitor.INVALID_HR_SAMPLE)) { rate = null; }
        if (rate != null) {
            historyExpires = 0;
        } else if (first) {
            historyExpires = 0;
            rate = recentPulse();
        } else if (historyExpires > 0) {
            return false;
        }
        if (bpm == rate) { return false; }
        bpm = rate;
        values[PULSE] = (rate == null ? "--" : rate.toString()) + " BPM";
        return true;
    }

    function drawTerminal(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var table = lineX(dc, TABLE_WIDTH);
        var dateWidth = dc.getTextWidthInPixels(dateText, textFont) - 3;
        var batteryWidth = batteryIcon ? 27 : dc.getTextWidthInPixels(batteryText, textFont) - 3;
        var header = lineX(dc, dateWidth + 18 + batteryWidth);
        dc.setColor(textInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(header, 84, textFont, dateText, LEFT);
        var meterX = header + dateWidth + 18;
        if (batteryIcon) {
            dc.drawRectangle(meterX, 87, 24, 12);
            dc.fillRectangle(meterX + 24, 90, 3, 6);
            if (battery > 0 && battery <= 100) { dc.fillRectangle(meterX + 2, 89, 1 + (battery - 1) * 19 / 99, 8); }
        } else {
            dc.drawText(meterX, 84, textFont, batteryText, LEFT);
        }

        var digits = dc.getTextWidthInPixels(timeText, clockFont);
        // Justify the actual ink. BMFont advances include a trailing gap; a leading 1 is inset.
        var inset = timeText.find("1") == 0 ? 5 : 0;
        var width = use24 ? digits - 6 : digits + 4 + dc.getTextWidthInPixels(periodText, textFont) - 3;
        var start = lineX(dc, width - inset) - inset;
        dc.setColor(timeInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(start, 119, clockFont, timeText, LEFT);
        if (!use24) { dc.drawText(start + digits + 4, 162, textFont, periodText, LEFT); }

        dc.setColor(ruleInk, Graphics.COLOR_TRANSPARENT);
        for (var dx = 0; dx < TABLE_WIDTH; dx += 8) { dc.fillRectangle(table + dx, 198, 4, 2); }
        for (var i = 0; i < rows.size(); i++) { drawRow(dc, i); }
    }

    function drawRow(dc as Graphics.Dc, index as Number) as Void {
        var field = rows[index];
        var x = lineX(dc, TABLE_WIDTH);
        var y = 213 + 25 * index;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, TABLE_WIDTH, 18);
        dc.setColor(labelInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, textFont, FIELD_LABELS[field], LEFT);
        dc.setColor(textInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + TABLE_WIDTH + 2, y, textFont, values[field], Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
