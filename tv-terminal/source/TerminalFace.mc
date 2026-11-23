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
const HEART_HISTORY_SECONDS = 900;
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
    // The 265S content fits this centered band for both alignments and time formats.
    const BAND_WIDTH = 248;
    const BAND_HEIGHT = 204;
    const BAND_TOP = 80;
    var bandX as Number = 56;
    var centered as Boolean = false;
    var clockChoice as Number = 0;
    var use24 as Boolean = true;
    var metricUnits as Boolean = true;
    var fields as Number = (1 << PULSE) | (1 << STEPS) | (1 << KCAL);
    var rows as Array<Number> = [PULSE, STEPS, KCAL];
    var values as Array<String> = ["-- BPM", "--", "--", "--", "--"];
    var wakeOnly as Boolean = true;
    var sampleInterval as Number = 300;
    var pulseTick as Number?;
    var bpm as Number?;
    var historyExpires as Number = 0;
    var timeInk as Number = PHOSPHOR_TIME;
    var textInk as Number = PHOSPHOR_TEXT;
    var labelInk as Number = tinted(PHOSPHOR_TEXT, 77);
    var ruleInk as Number = tinted(PHOSPHOR_TEXT, 41);
    var sleepInk as Number = tinted(PHOSPHOR_TIME, 50);
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
        bandX = (dc.getWidth() - BAND_WIDTH) / 2;
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
        var newCentered = savedChoice(ALIGN_KEY, ALIGN_LEFT, 2) == ALIGN_CENTER;
        var newBatteryIcon = savedChoice(BATTERY_KEY, 0, 2) == 1;
        if (newCentered != centered || newBatteryIcon != batteryIcon) { dirty = true; }
        centered = newCentered;
        batteryIcon = newBatteryIcon;
        var device = System.getDeviceSettings();
        clockChoice = savedChoice(CLOCK_KEY, 0, 3);
        setClockFormat(uses24Hours(clockChoice, device.is24Hour));
        var previousFields = fields;
        fields = 0;
        for (var i = 0; i < rows.size(); i++) {
            var field = savedChoice(ROW_KEYS[i], i, FIELD_LABELS.size());
            fields |= 1 << field;
            if (rows[i] != field) {
                rows[i] = field;
                dirty = true;
            }
        }
        if ((fields & ~previousFields & ~(1 << PULSE)) != 0) { invalidateStats(); }
        setDistanceUnits(device.distanceUnits == System.UNIT_METRIC);
        var interval = SAMPLE_INTERVALS[savedChoice(TOTALS_KEY, 1, SAMPLE_INTERVALS.size())];
        if (sampleInterval != interval) {
            sampleInterval = interval;
            nextCheck = null;
        }
        var pulseChanged = ((previousFields ^ fields) & (1 << PULSE)) != 0;
        var newWakeOnly = savedChoice(HEART_KEY, 0, 2) == 0;
        if (pulseChanged || wakeOnly != newWakeOnly) { pulseTick = null; }
        wakeOnly = newWakeOnly;
        if (pulseChanged && (fields & (1 << PULSE)) == 0) {
            bpm = null;
            values[PULSE] = "-- BPM";
            historyExpires = 0;
        }

        var newTimeInk = savedColor(TIME_COLOR_KEY);
        var newTextInk = savedColor(TEXT_COLOR_KEY);
        if (timeInk != newTimeInk || textInk != newTextInk) {
            timeInk = newTimeInk;
            textInk = newTextInk;
            labelInk = tinted(textInk, 77);
            ruleInk = tinted(textInk, 41);
            sleepInk = tinted(timeInk, 50);
            discardFrame();
        }
    }

    function applySettings() as Void {
        loadSettings();
        requestVisibleUpdate();
    }

    function applyDeviceSetting(key as Symbol, value as Object) as Void {
        var changed = false;
        if (key == :is24Hour && clockChoice == 0) {
            changed = setClockFormat(value as Boolean);
        } else if (key == :distanceUnits) {
            changed = setDistanceUnits(value == System.UNIT_METRIC);
        }
        if (changed) { requestVisibleUpdate(); }
    }

    function setClockFormat(newUse24 as Boolean) as Boolean {
        if (newUse24 == use24) { return false; }
        use24 = newUse24;
        shownMinute = -1;
        nextCheck = null;
        return true;
    }

    function setDistanceUnits(metric as Boolean) as Boolean {
        if (metric == metricUnits) { return false; }
        metricUnits = metric;
        if ((fields & (1 << DISTANCE)) == 0) { return false; }
        invalidateStats();
        return true;
    }

    function invalidateStats() as Void {
        sampledSecond = -1;
        nextCheck = null;
    }

    function requestVisibleUpdate() as Void {
        if (mode != System.DISPLAY_MODE_OFF) { WatchUi.requestUpdate(); }
    }

    function onShow() as Void {
        mode = System.getDisplayMode();
        loadSettings();
        shownMinute = -1;
        nextCheck = null;
        pulseTick = null;
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
        requestVisibleUpdate();
    }

    // One shared margin keeps even the lowest left-aligned data row inside the round panel.
    function lineX(dc as Graphics.Dc, width as Number) as Number {
        return (dc.getWidth() - (centered ? width : 224)) / 2;
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
            var left = centered ? lineX(dc, dc.getTextWidthInPixels(value, sleepFont) - 3 - inset) : 68;
            dc.drawText(left - inset,
                (dc.getHeight() - 30) / 2 + (clock.min & 1), sleepFont, value, LEFT);
            return;
        }

        var tick = System.getTimer();
        var previousPulse = bpm;
        if (nextCheck == null || tick - (nextCheck as Number) >= 0) { refreshClock(Time.now(), tick); }
        refreshPulse(tick);
        if (tryFrame) {
            tryFrame = false;
            try {
                var colors = [Graphics.COLOR_BLACK, ruleInk, labelInk, textInk, timeInk];
                frame = Graphics.createBufferedBitmap({:width => BAND_WIDTH, :height => BAND_HEIGHT,
                    :palette => colors}).get() as Graphics.BufferedBitmap?;
            } catch (error instanceof Graphics.OutOfGraphicsMemoryException) {
                // Direct drawing also works when another view is using the graphics pool.
            }
        }
        var cached = frame;
        if (cached == null) {
            drawTerminal(dc, 0);
        } else {
            if (dirty) {
                drawTerminal(cached.getDc(), BAND_TOP);
                dirty = false;
            } else if (bpm != previousPulse) {
                var canvas = cached.getDc();
                var table = lineX(canvas, TABLE_WIDTH);
                for (var i = 0; i < rows.size(); i++) {
                    if (rows[i] == PULSE) { drawRow(canvas, i, table, BAND_TOP, true); }
                }
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawBitmap(bandX, BAND_TOP, cached);
        }
    }

    function refreshClock(now as Time.Moment, tick as Number) as Void {
        var second = now.value();
        var minute = second / 60;
        if (minute != shownMinute) {
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
            dirty = true;
        }
        var untilSample = sampleInterval - (second - sampledSecond);
        if (sampledSecond < 0 || second < sampledSecond || untilSample <= 0) {
            readStats(second);
            untilSample = sampleInterval;
        }
        var delay = 60 - second % 60;
        if (untilSample < delay) { delay = untilSample; }
        if (historyExpires > 0) {
            var untilExpiry = historyExpires - second;
            if (untilExpiry <= 0 || untilExpiry > HEART_HISTORY_SECONDS) {
                bpm = null;
                values[PULSE] = "-- BPM";
                historyExpires = 0;
            } else if (untilExpiry < delay) {
                delay = untilExpiry;
            }
        }
        // Wall time has whole-second precision, so check one second before the nearest deadline.
        nextCheck = tick + (delay - 1) * 1000;
    }

    function readStats(second as Number) as Void {
        sampledSecond = second;
        var level = System.getSystemStats().battery.toNumber();
        if (level < 0 || level > 100) { level = -1; }
        if (level != battery) {
            battery = level;
            batteryText = level < 0 ? "--" : level.toString() + "%";
            dirty = true;
        }
        if (fields == (1 << PULSE)) { return; }
        var info = ActivityMonitor.getInfo();
        if ((fields & (1 << STEPS)) != 0) { updateValue(STEPS, counterText(info.steps)); }
        if ((fields & (1 << KCAL)) != 0) { updateValue(KCAL, counterText(info.calories)); }
        if ((fields & (1 << DISTANCE)) != 0) { updateValue(DISTANCE, distanceText(info.distance, metricUnits)); }
        if ((fields & (1 << FLOORS)) != 0) { updateValue(FLOORS, counterText(info.floorsClimbed)); }
    }

    function updateValue(field as Number, value as String) as Void {
        if (!values[field].equals(value)) {
            values[field] = value;
            dirty = true;
        }
    }

    function currentPulse() as Number? { return Activity.getActivityInfo().currentHeartRate; }

    function recentPulse() as Number? {
        var now = Time.now().value();
        var history = ActivityMonitor.getHeartRateHistory(new Time.Duration(HEART_HISTORY_SECONDS), true);
        for (var sample = history.next(); sample != null; sample = history.next()) {
            var rate = sample.heartRate;
            var when = sample.when;
            if (when == null) { continue; }
            var recorded = when.value();
            if (now - recorded >= HEART_HISTORY_SECONDS) { break; }
            if (recorded <= now && rate != null && rate > 0 && rate != ActivityMonitor.INVALID_HR_SAMPLE) {
                historyExpires = recorded + HEART_HISTORY_SECONDS;
                return rate;
            }
        }
        return null;
    }

    function refreshPulse(tick as Number) as Void {
        if ((fields & (1 << PULSE)) == 0) { return; }
        if (pulseTick != null && ((wakeOnly && bpm != null) || tick - (pulseTick as Number) < 3000)) {
            return;
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
            if (historyExpires > 0) { nextCheck = null; }
        } else if (historyExpires > 0) {
            return;
        }
        if (bpm == rate) { return; }
        bpm = rate;
        values[PULSE] = (rate == null ? "--" : rate.toString()) + " BPM";
    }

    function drawTerminal(dc as Graphics.Dc, top as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var table = lineX(dc, TABLE_WIDTH);
        var dateWidth = dc.getTextWidthInPixels(dateText, textFont) - 3;
        var batteryWidth = !centered || batteryIcon ? 27 : dc.getTextWidthInPixels(batteryText, textFont) - 3;
        var header = lineX(dc, dateWidth + 18 + batteryWidth);
        dc.setColor(textInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(header, 84 - top, textFont, dateText, LEFT);
        var meterX = header + dateWidth + 18;
        if (batteryIcon) {
            dc.drawRectangle(meterX, 87 - top, 24, 12);
            dc.fillRectangle(meterX + 24, 90 - top, 3, 6);
            if (battery > 0 && battery <= 100) { dc.fillRectangle(meterX + 2, 89 - top, 1 + (battery - 1) * 19 / 99, 8); }
        } else {
            dc.drawText(meterX, 84 - top, textFont, batteryText, LEFT);
        }

        var digits = centered || !use24 ? dc.getTextWidthInPixels(timeText, clockFont) : 0;
        // Justify the actual ink. BMFont advances include a trailing gap; a leading 1 is inset.
        var inset = timeText.find("1") == 0 ? 5 : 0;
        var width = !centered || use24 ? digits - 6 : digits + 4 + dc.getTextWidthInPixels(periodText, textFont) - 3;
        var start = lineX(dc, width - inset) - inset;
        dc.setColor(timeInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(start, 119 - top, clockFont, timeText, LEFT);
        if (!use24) { dc.drawText(start + digits + 4, 162 - top, textFont, periodText, LEFT); }

        dc.setColor(ruleInk, Graphics.COLOR_TRANSPARENT);
        for (var dx = 0; dx < TABLE_WIDTH; dx += 8) { dc.fillRectangle(table + dx, 198 - top, 4, 2); }
        for (var i = 0; i < rows.size(); i++) { drawRow(dc, i, table, top, false); }
    }

    function drawRow(dc as Graphics.Dc, index as Number, x as Number, top as Number, erase as Boolean) as Void {
        var field = rows[index];
        var y = 213 - top + 25 * index;
        if (erase) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, TABLE_WIDTH, 18);
        }
        dc.setColor(labelInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, textFont, FIELD_LABELS[field], LEFT);
        dc.setColor(textInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + TABLE_WIDTH + 2, y, textFont, values[field], Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
