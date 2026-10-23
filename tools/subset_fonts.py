#!/usr/bin/env python3
"""Rebuild fonts/ZCOOLQingKeHuangYou-Subset.ttf (the chunky sign font).

The full font is ~8 MB, so the project ships a subset that only contains the
characters used in the game's scripts plus ASCII. Run this after adding new
Chinese text:

    pip install fonttools
    python3 tools/subset_fonts.py            # downloads the full font once
    python3 tools/subset_fonts.py path/to/ZCOOLQingKeHuangYou-Regular.ttf

Characters missing from the subset still render: the game falls back to the
bundled ZCOOL KuaiLe font, then to system CJK fonts.
"""
import pathlib
import sys
import urllib.request

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/zcoolqingkehuangyou/ZCOOLQingKeHuangYou-Regular.ttf"
OUT = ROOT / "fonts" / "ZCOOLQingKeHuangYou-Subset.ttf"


def used_chars() -> str:
    chars = set(chr(c) for c in range(0x20, 0x7F))
    chars.update("★☆■□●○◆◇♥♪！？，。、：；“”‘’（）《》【】…—～·×÷￥%")
    for path in list(ROOT.glob("scripts/**/*.gd")) + list(ROOT.glob("scenes/*.tscn")):
        for ch in path.read_text(encoding="utf-8"):
            if ord(ch) > 0x7F:
                chars.add(ch)
    return "".join(sorted(chars))


def main() -> None:
    if len(sys.argv) > 1:
        src = pathlib.Path(sys.argv[1])
    else:
        src = ROOT / ".godot" / "ZCOOLQingKeHuangYou-Regular.ttf"
        if not src.exists():
            src.parent.mkdir(exist_ok=True)
            print("downloading", URL)
            urllib.request.urlretrieve(URL, src)
    text = used_chars()
    opts = subset.Options()
    opts.layout_features = ["*"]
    font = subset.load_font(str(src), opts)
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    subset.save_font(font, str(OUT), opts)
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB, {len(text)} chars)")


if __name__ == "__main__":
    main()
