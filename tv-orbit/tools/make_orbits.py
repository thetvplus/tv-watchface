"""Build the 265S orbit backgrounds from the watch's JPL elements and projection."""
from ast import literal_eval
from math import cos, sin, radians, tau, sqrt, hypot, log1p
from pathlib import Path
import re

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "source/Orbits.mc").read_text(encoding="utf-8")


def constant(name):
    return literal_eval(re.search(rf"^const {name} = (.*?);", SOURCE, re.M | re.S)[1])


ELEMENTS = constant("ELEMENTS")
RADIUS, LIMIT, HALF, RING_STEP = map(constant, ("CHART_RADIUS", "LIMIT_AU", "HALF", "RING_STEP"))
INNER, INNER_SCALE = map(constant, ("INNER_AU", "INNER_PX_PER_AU"))
NEAR, NEAR_SCALE, BALANCED_UNIT = map(constant, ("NEAR_INNER_AU", "NEAR_PX_PER_AU", "BALANCED_UNIT"))
EARTH = constant("EARTH")
MODES = ("inner", "linear", "log", "concentric")
# 2026-01-01 noon UTC. Planet markers use the orbital elements of the displayed day.
TRACK_EPOCH = 9497 / 36525


def ellipse(row, t, anomaly):
    a, e, inc, _, peri, node = [value + rate*t for value, rate in zip(row[::2], row[1::2])]
    inc, w, node = map(radians, (inc, peri - node, node))
    xp, yp = a * (cos(anomaly) - e), a * sqrt(1 - e*e) * sin(anomaly)
    u, v = xp*cos(w) - yp*sin(w), (xp*sin(w) + yp*cos(w))*cos(inc)
    return u*cos(node) - v*sin(node), u*sin(node) + v*cos(node)


def project(x, y, mode, planet):
    r = hypot(x, y)
    if mode == "concentric":
        scale = (planet + 1) * RING_STEP / r
    else:
        inner, scale = (INNER, INNER_SCALE) if mode == "inner" else (NEAR, NEAR_SCALE)
        if r > inner:
            offset = r - inner
            span = LIMIT - inner
            edge = inner * scale
            if mode == "linear":
                fraction = offset / span
            else:
                unit = INNER if mode == "inner" else BALANCED_UNIT
                fraction = log1p(offset / unit) / log1p(span / unit)
            scale = (edge + (RADIUS - edge) * fraction) / r
    return x*scale, -y*scale


def generate():
    palette = b"".join(color.to_bytes(3, "big") for color in
                       (0, constant("TRACK_COLOR"), constant("EARTH_TRACK_COLOR")))
    for mode in MODES:
        image = Image.new("P", (2*HALF+1, 2*HALF+1), 0)
        image.putpalette(palette)
        draw = ImageDraw.Draw(image)
        for planet, row in enumerate(ELEMENTS):
            color = 2 if planet == EARTH else 1
            if mode == "concentric":
                r = (planet + 1) * RING_STEP
                draw.ellipse((HALF - r, HALF - r, HALF + r, HALF + r), outline=color)
                continue
            path = []
            for step in range(1024):
                xy = ellipse(row, TRACK_EPOCH, tau * step / 1024)
                dx, dy = project(*xy, mode, planet)
                path.append((HALF + round(dx), HALF + round(dy)))
            draw.line(path + path[:1], fill=color)
        image.save(ROOT / f"resources/drawables/{mode}-orbits.png", bits=2)


if __name__ == "__main__":
    generate()
