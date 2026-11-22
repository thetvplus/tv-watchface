"""Build the original bitmap fonts and launcher with Python and Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw


RESOURCES = Path(__file__).resolve().parents[1] / "resources"

# Each row is a binary pixel pattern. Clock digits have fixed advances, including 1.
CLOCK = {
    "0": "0111110 1100011 1100011 1100111 1101011 1110011 1100011 1100011 1100011 0111110",
    "1": "0001100 0011100 0111100 0001100 0001100 0001100 0001100 0001100 0001100 0111111",
    "2": "0111110 1100011 0000011 0000011 0000110 0001100 0011000 0110000 1100000 1111111",
    "3": "0111110 1100011 0000011 0000011 0011110 0000011 0000011 0000011 1100011 0111110",
    "4": "0000110 0001110 0011110 0110110 1100110 1100110 1111111 0000110 0000110 0000110",
    "5": "1111111 1100000 1100000 1100000 1111110 0000011 0000011 0000011 1100011 0111110",
    "6": "0011110 0110000 1100000 1100000 1111110 1100011 1100011 1100011 1100011 0111110",
    "7": "1111111 0000011 0000110 0000110 0001100 0001100 0011000 0011000 0110000 0110000",
    "8": "0111110 1100011 1100011 1100011 0111110 1100011 1100011 1100011 1100011 0111110",
    "9": "0111110 1100011 1100011 1100011 1100011 0111111 0000011 0000011 0000110 0111100",
    ":": "00 00 11 11 00 00 11 11 00 00",
}

CONSOLE = {
    " ": "00000 00000 00000 00000 00000 00000 00000",
    "%": "11001 11010 00010 00100 01000 01011 10011",
    ".": "00000 00000 00000 00000 00000 00000 00100",
    "-": "00000 00000 00000 11111 00000 00000 00000",
    "0": "01110 10001 10011 10101 11001 10001 01110",
    "1": "00100 01100 00100 00100 00100 00100 01110",
    "2": "01110 10001 00001 00010 00100 01000 11111",
    "3": "11110 00001 00001 01110 00001 00001 11110",
    "4": "00010 00110 01010 10010 11111 00010 00010",
    "5": "11111 10000 10000 11110 00001 00001 11110",
    "6": "01110 10000 10000 11110 10001 10001 01110",
    "7": "11111 00001 00010 00100 01000 01000 01000",
    "8": "01110 10001 10001 01110 10001 10001 01110",
    "9": "01110 10001 10001 01111 00001 00001 01110",
    "A": "01110 10001 10001 11111 10001 10001 10001",
    "B": "11110 10001 10001 11110 10001 10001 11110",
    "C": "01111 10000 10000 10000 10000 10000 01111",
    "D": "11110 10001 10001 10001 10001 10001 11110",
    "E": "11111 10000 10000 11110 10000 10000 11111",
    "F": "11111 10000 10000 11110 10000 10000 10000",
    "H": "10001 10001 10001 11111 10001 10001 10001",
    "I": "01110 00100 00100 00100 00100 00100 01110",
    "K": "10001 10010 10100 11000 10100 10010 10001",
    "L": "10000 10000 10000 10000 10000 10000 11111",
    "M": "10001 11011 10101 10101 10001 10001 10001",
    "N": "10001 11001 11001 10101 10011 10011 10001",
    "O": "01110 10001 10001 10001 10001 10001 01110",
    "P": "11110 10001 10001 11110 10000 10000 10000",
    "R": "11110 10001 10001 11110 10100 10010 10001",
    "S": "01111 10000 10000 01110 00001 00001 11110",
    "T": "11111 00100 00100 00100 00100 00100 00100",
    "U": "10001 10001 10001 10001 10001 10001 01110",
    "W": "10001 10001 10001 10101 10101 11011 10001",
}


def make_font(name, patterns, scale_x, height, gap, scanline_alpha=None, small_letters=None):
    atlas = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    glyphs = []
    x = y = 0
    small_letters = small_letters or {}
    for char, pattern in sorted((patterns | small_letters).items()):
        rows = pattern.split()
        pixel_width = 2 if char in small_letters else scale_x
        glyph_height = 14 if char in small_letters else height
        width = len(rows[0]) * pixel_width
        if x + width > atlas.width:
            x = 0
            y += height + 1
        assert y + height <= atlas.height
        for dy in range(glyph_height):
            row = rows[dy * len(rows) // glyph_height]
            alpha = 255 if scanline_alpha is None else scanline_alpha[dy % len(scanline_alpha)]
            for dx in range(width):
                if row[dx // pixel_width] == "1":
                    atlas.putpixel((x + dx, y + dy), (255, 255, 255, alpha))
        glyphs.append(
            f"char id={ord(char)} x={x} y={y} width={width} height={glyph_height} "
            f"xoffset=0 yoffset={height - glyph_height} xadvance={width + gap} page=0 chnl=15"
        )
        x += width + 1
    dest = RESOURCES / "fonts"
    atlas.save(dest / f"{name}.png", optimize=True)
    header = [
        f'info face="{name}" size={height} bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
        f"common lineHeight={height} base={height} scaleW=256 scaleH=256 pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs)}",
    ]
    (dest / f"{name}.fnt").write_text("\n".join(header + glyphs) + "\n", encoding="ascii")


def make_launcher():
    icon = Image.new("RGBA", (60, 60))
    draw = ImageDraw.Draw(icon)
    draw.rounded_rectangle((3, 8, 56, 51), radius=5, fill="black", outline="#76D889", width=3)
    draw.line([(13, 20), (23, 30), (13, 40)], fill="#A6FF90", width=5)
    draw.rectangle((30, 36, 44, 40), fill="#A6FF90")
    icon.save(RESOURCES / "drawables" / "launcher.png")


if __name__ == "__main__":
    make_font("clock", CLOCK, 5, 60, 6, (255, 255, 255, 255, 0))
    make_font("sleep-clock", CLOCK, 3, 30, 3, (255, 0), {c: CONSOLE[c] for c in "AMP"})
    make_font("console", CONSOLE, 2, 17, 3)
    make_launcher()
