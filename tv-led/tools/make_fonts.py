"""Build the two 1-bit LED fonts and the 265S launcher icon."""

from pathlib import Path

from PIL import Image, ImageDraw

RES = Path(__file__).resolve().parents[1] / "resources"
DIGITS = ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]
LETTERS = {
    "A": ["010", "101", "111", "101", "101"],
    "P": ["110", "101", "110", "100", "100"],
    "M": ["10001", "11011", "10101", "10001", "10001"],
}


def numeral(char, width, height, thickness):
    image = Image.new("L", (width, height))
    draw = ImageDraw.Draw(image)
    tip = thickness // 2
    mid = height // 2
    # All six junctions use the same tip-to-junction distance on both axes.
    setback = tip + 1

    def horizontal(y):
        left, right = tip + setback, width - 1 - tip - setback
        draw.polygon([(left, y), (left + tip, y - tip), (right - tip, y - tip),
                      (right, y), (right - tip, y + tip), (left + tip, y + tip)], fill=255)

    def vertical(x, top, bottom):
        draw.polygon([(x, top), (x + tip, top + tip), (x + tip, bottom - tip),
                      (x, bottom), (x - tip, bottom - tip), (x - tip, top + tip)], fill=255)

    active = DIGITS[int(char)]
    for segment, y in (("a", tip), ("g", mid), ("d", height - tip - 1)):
        if segment in active:
            horizontal(y)
    for segment, x, top, bottom in (
        ("f", tip, tip + setback, mid - setback), ("b", width - tip - 1, tip + setback, mid - setback),
        ("e", tip, mid + setback, height - 1 - tip - setback),
        ("c", width - tip - 1, mid + setback, height - 1 - tip - setback),
    ):
        if segment in active:
            vertical(x, top, bottom)
    return image


def glyph_image(char, width, height, thickness):
    if char.isdigit():
        return numeral(char, width, height, thickness)
    if char == ":":
        image = Image.new("L", (thickness, height))
        draw = ImageDraw.Draw(image)
        for y in (height // 3, height - 1 - height // 3):
            draw.rectangle((0, y - thickness // 2, thickness - 1, y + thickness // 2), fill=255)
        return image
    rows = LETTERS[char]
    image = Image.new("L", (len(rows[0]), len(rows)))
    image.putdata([255 * int(bit) for row in rows for bit in row])
    scale = 3 if thickness == 7 else 2
    return image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)


def make_font(name, width, height, thickness, gap, dim=False):
    size = (256, 256)
    atlas = Image.new("L", size)
    glyphs = []
    x = y = 0
    for char in "0123456789:AMP":
        glyph = glyph_image(char, width, height, thickness)
        if dim:
            # Align every glyph, including AM/PM, to the same physical scan lines.
            for row in range(1 - ((height - glyph.height) & 1), glyph.height, 2):
                glyph.paste(0, (0, row, glyph.width, row + 1))
        if x + glyph.width > atlas.width:
            x = 0
            y += height + 1
        assert y + glyph.height <= atlas.height
        atlas.paste(glyph, (x, y))
        advance = glyph.width + (3 if char in "AP" else gap)
        glyphs.append(f"char id={ord(char)} x={x} y={y} width={glyph.width} height={glyph.height} "
                      f"xoffset=0 yoffset={height - glyph.height} xadvance={advance} page=0 chnl=15")
        x += glyph.width + 1
    path = RES / "fonts"
    png = Image.new("RGBA", size, "white")
    png.putalpha(atlas)
    png.save(path / f"{name}.png", optimize=True)
    lines = [f'info face="{name}" size={height} unicode=1 smooth=0 aa=1',
             f"common lineHeight={height} base={height} scaleW=256 scaleH=256 pages=1 packed=0",
             f'page id=0 file="{name}.png"', f"chars count={len(glyphs)}", *glyphs]
    (path / f"{name}.fnt").write_text("\n".join(lines) + "\n", encoding="ascii", newline="\n")


if __name__ == "__main__":
    make_font("led", width=43, height=71, thickness=7, gap=11)
    make_font("dim-led", width=29, height=45, thickness=5, gap=8, dim=True)
    icon = Image.new("RGBA", (60, 60))
    eight = numeral("8", 31, 49, 5)
    icon.paste("#FF3924", ((60 - eight.width) // 2, (60 - eight.height) // 2), eight)
    icon.save(RES / "drawables" / "launcher.png", optimize=True)
