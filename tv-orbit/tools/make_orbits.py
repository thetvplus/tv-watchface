"""Build the 265S orbit backgrounds from the watch's JPL elements and projection."""
from ast import literal_eval
from math import cos, sin, radians, tau, sqrt, hypot, log, log1p
from pathlib import Path
import re

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "source/Orbits.mc").read_text(encoding="utf-8")


def constant(name):
    return literal_eval(re.search(rf"^const {name} = (.*?);", SOURCE, re.M | re.S)[1])


ELEMENTS = constant("ELEMENTS")
RADIUS, LIMIT, UNIT, HALF = map(constant, ("CHART_RADIUS", "LIMIT_AU", "LOG_UNIT", "HALF"))
INNER, INNER_SCALE = map(constant, ("INNER_AU", "INNER_PX_PER_AU"))
MODES = ("inner", "linear", "log")
# 2026-01-01 noon UTC. Planet markers use the orbital elements of the displayed day.
TRACK_EPOCH = 9497 / 36525


def ellipse(row, t, anomaly):
    a, e, inc, _, peri, node = [value + rate*t for value, rate in zip(row[::2], row[1::2])]
    inc, w, node = map(radians, (inc, peri - node, node))
    xp, yp = a * (cos(anomaly) - e), a * sqrt(1 - e*e) * sin(anomaly)
    u, v = xp*cos(w) - yp*sin(w), (xp*sin(w) + yp*cos(w))*cos(inc)
    return u*cos(node) - v*sin(node), u*sin(node) + v*cos(node)


def project(x, y, mode):
    scale = RADIUS / LIMIT
    if mode == "inner":
        r = hypot(x, y)
        edge = INNER * INNER_SCALE
        scale = INNER_SCALE if r <= INNER else (edge + (RADIUS-edge)*log(r/INNER)/log(LIMIT/INNER))/r
    elif mode == "log":
        r = hypot(x, y)
        scale = RADIUS * log1p(r / UNIT) / (log1p(LIMIT / UNIT) * r)
    return x*scale, -y*scale


def generate():
    for mode in MODES:
        image = Image.new("P", (2*HALF+1, 2*HALF+1), 0)
        image.putpalette([0, 0, 0, 0x48, 0x50, 0x55])
        draw = ImageDraw.Draw(image)
        for row in ELEMENTS:
            path = []
            for step in range(1024):
                xy = ellipse(row, TRACK_EPOCH, tau * step / 1024)
                dx, dy = project(*xy, mode)
                path.append((HALF + round(dx), HALF + round(dy)))
            draw.line(path + path[:1], fill=1)
        image.save(ROOT / f"resources/drawables/{mode}-orbits.png", bits=1)


if __name__ == "__main__":
    generate()
