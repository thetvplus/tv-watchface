import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// JPL, Approximate Positions of the Planets, Table 1 (1800–2050), J2000 ecliptic.
// Pairs are the element and its rate per Julian century: a (AU), e, I, L, longitude of perihelion, ascending node.
const ELEMENTS = [
    [0.38709927, 0.00000037, 0.20563593, 0.00001906, 7.00497902, -0.00594749, 252.25032350, 149472.67411175, 77.45779628, 0.16047689, 48.33076593, -0.12534081],
    [0.72333566, 0.00000390, 0.00677672, -0.00004107, 3.39467605, -0.00078890, 181.97909950, 58517.81538729, 131.60246718, 0.00268329, 76.67984255, -0.27769418],
    [1.00000261, 0.00000562, 0.01671123, -0.00004392, -0.00001531, -0.01294668, 100.46457166, 35999.37244981, 102.93768193, 0.32327364, 0.0, 0.0],
    [1.52371034, 0.00001847, 0.09339410, 0.00007882, 1.84969142, -0.00813131, -4.55343205, 19140.30268499, -23.94362959, 0.44441088, 49.55953891, -0.29257343],
    [5.20288700, -0.00011607, 0.04838624, -0.00013253, 1.30439695, -0.00183714, 34.39644051, 3034.74612775, 14.72847983, 0.21252668, 100.47390909, 0.20469106],
    [9.53667594, -0.00125060, 0.05386179, -0.00050991, 2.48599187, 0.00193609, 49.95424423, 1222.49362201, 92.59887831, -0.41897216, 113.66242448, -0.28867794],
    [19.18916464, -0.00196176, 0.04725744, -0.00004397, 0.77263783, -0.00242939, 313.23810451, 428.48202785, 170.95427630, 0.40805281, 74.01692503, 0.04240589],
    [30.06992276, 0.00026291, 0.00859048, 0.00005105, 1.77004347, 0.00035372, -55.12002969, 218.45945325, 44.96476227, -0.32241464, 131.78422574, -0.00508664]
];
const RAD = 0.01745329252;
const CHART_RADIUS = 128;
const LIMIT_AU = 30.5;
const NEAR_INNER_AU = 1.23;
const NEAR_PX_PER_AU = 38.0;
const BALANCED_UNIT = 5.0;
const INNER_AU = 1.05;
const INNER_PX_PER_AU = 46.0;
const NEAR_SCALE = 0;
const BALANCED = 1;
const INNER_FOCUS = 2;
const CONCENTRIC = 3;
const RING_STEP = 16;
const HALF = 134;
const EARTH = 2;
const SUN_DOT = 4;
const SUN_COLOR = 0xFFD45A;
const EARTH_HIGHLIGHT = 0xBBECFF;
const TRACK_COLOR = 0x3E4850;
const EARTH_TRACK_COLOR = 0x32596A;
const DOTS = [2, 3, 4, 2, 4, 4, 3, 3];
const CHART_PALETTE = [0xBABFC6, 0xE9BE90, 0x42B9FF, 0xE6755E,
    0xE6A264, 0xDBC389, 0x73D9C7, 0x6984F7, SUN_COLOR, EARTH_HIGHLIGHT,
    TRACK_COLOR, EARTH_TRACK_COLOR, Graphics.COLOR_BLACK];
const DAILY = 1;
const DEFAULT_REFRESH_DAYS = 2;
const EVERY_THREE_DAYS = 3;

// Project the heliocentric ellipse onto the J2000 ecliptic, in astronomical units.
function planetXY(index as Number, centuries as Float) as Array<Float> {
    var el = ELEMENTS[index];
    var a = el[0] + el[1] * centuries;
    var e = el[2] + el[3] * centuries;
    var tilt = (el[4] + el[5] * centuries) * RAD;
    var peri = el[8] + el[9] * centuries;
    var node = (el[10] + el[11] * centuries) * RAD;
    var mean = el[6] + el[7] * centuries - peri;
    mean = (mean - 360.0 * Math.floor((mean + 180.0) / 360.0).toFloat()) * RAD;
    // JPL's first-order starting value converges in two corrections for these eccentricities.
    var anomaly = mean + e * Math.sin(mean).toFloat();
    for (var n = 0; n < 2; n++) {
        anomaly -= (anomaly - e * Math.sin(anomaly).toFloat() - mean) / (1.0 - e * Math.cos(anomaly).toFloat());
    }
    var xp = a * (Math.cos(anomaly).toFloat() - e);
    var yp = a * Math.sqrt(1.0 - e * e).toFloat() * Math.sin(anomaly).toFloat();
    var w = peri * RAD - node;
    var cw = Math.cos(w).toFloat();
    var sw = Math.sin(w).toFloat();
    var cn = Math.cos(node).toFloat();
    var sn = Math.sin(node).toFloat();
    var u = xp * cw - yp * sw;
    var v = (xp * sw + yp * cw) * Math.cos(tilt).toFloat();
    return [u * cn - v * sn, u * sn + v * cn];
}

class OrbitChart {
    var periodStart as Number?;
    var scaleMode as Number = INNER_FOCUS;
    var refreshDays as Number = DEFAULT_REFRESH_DAYS;
    var x as Array<Number> = [0, 0, 0, 0, 0, 0, 0, 0];
    var y as Array<Number> = [0, 0, 0, 0, 0, 0, 0, 0];
    var image as Graphics.BufferedBitmap?;
    var tracks as Graphics.BitmapReference?;

    function configure(mode as Number, days as Number) as Void {
        if (scaleMode == mode && refreshDays == days) { return; }
        if (scaleMode != mode) { tracks = null; }
        scaleMode = mode;
        refreshDays = days;
        periodStart = null;
    }

    function update(utcSeconds as Number) as Void {
        var day = utcSeconds / 86400;
        var start = day - day % refreshDays;
        if (periodStart == start) { return; }
        // Sample the midpoint of the UTC window. J2000.0 is noon of Unix day 10957.
        var centuries = (start - 10957 + (refreshDays - 1) * 0.5) / 36525.0;
        var innerFocus = scaleMode == INNER_FOCUS;
        var innerAu = innerFocus ? INNER_AU : NEAR_INNER_AU;
        var innerRate = innerFocus ? INNER_PX_PER_AU : NEAR_PX_PER_AU;
        var outerUnit = innerFocus ? INNER_AU : BALANCED_UNIT;
        var rings = scaleMode == CONCENTRIC;
        var linear = scaleMode == NEAR_SCALE;
        var innerLimit = innerAu * innerAu;
        var innerEdge = innerAu * innerRate;
        var outerSpan = LIMIT_AU - innerAu;
        var outerFactor = 0.0;
        if (!rings) {
            outerFactor = (CHART_RADIUS - innerEdge) / (linear
                ? outerSpan : Math.ln(1.0 + outerSpan / outerUnit).toFloat());
        }
        for (var i = 0; i < ELEMENTS.size(); i++) {
            var xy = planetXY(i, centuries);
            var dx = xy[0];
            var dy = xy[1];
            var r2 = dx * dx + dy * dy;
            var scale = innerRate;
            // All layouts retain the projected heliocentric bearing.
            if (rings) {
                scale = (i + 1) * RING_STEP / Math.sqrt(r2).toFloat();
            } else if (r2 > innerLimit) {
                var r = Math.sqrt(r2).toFloat();
                var offset = r - innerAu;
                var outerDistance = linear ? offset : Math.ln(1.0 + offset / outerUnit).toFloat();
                scale = (innerEdge + outerFactor * outerDistance) / r;
            }
            x[i] = Math.round(dx * scale).toNumber();
            y[i] = -Math.round(dy * scale).toNumber();
        }
        if (tracks == null) {
            var resources = [Rez.Drawables.LinearOrbits, Rez.Drawables.LogOrbits,
                Rez.Drawables.InnerOrbits, Rez.Drawables.ConcentricOrbits];
            tracks = WatchUi.loadResource(resources[scaleMode]) as Graphics.BitmapReference;
        }
        if (image == null) {
            try {
                image = Graphics.createBufferedBitmap({:width => 2 * HALF + 1, :height => 2 * HALF + 1,
                    :palette => CHART_PALETTE}).get() as Graphics.BufferedBitmap?;
            } catch (error instanceof Graphics.OutOfGraphicsMemoryException) {
                // Direct painting uses the same track resource and cached coordinates.
            }
        }
        var cached = image;
        if (cached != null) { paint(cached.getDc(), HALF, HALF); }
        periodStart = start;
    }

    function draw(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var cached = image;
        if (cached != null) { dc.drawBitmap(cx - HALF, cy - HALF, cached); }
        else { paint(dc, cx, cy); }
    }

    function paint(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var background = tracks;
        if (background != null) { dc.drawBitmap(cx - HALF, cy - HALF, background); }
        for (var p = 0; p < DOTS.size(); p++) {
            dc.setColor(CHART_PALETTE[p], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + x[p], cy + y[p], DOTS[p]);
        }
        dc.setColor(EARTH_HIGHLIGHT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + x[EARTH] - 1, cy + y[EARTH] - 1, 1);
        dc.setColor(SUN_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, SUN_DOT);
    }
}
