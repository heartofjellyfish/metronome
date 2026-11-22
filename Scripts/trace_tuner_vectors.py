"""Compile the checked-in tuner line art into paths for SwiftUI Canvas.

Run on macOS with Pillow, svgpathtools and Potrace installed.
Usage: python3 scripts/trace_tuner_vectors.py [path-to-potrace]
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageOps
from svgpathtools import CubicBezier, Line, parse_path

root = Path(__file__).resolve().parents[1]
assets = root / "TheMetronome/Assets.xcassets/TunerInstruments"
output = root / "TheMetronome/TunerVectors"
potrace = sys.argv[1] if len(sys.argv) > 1 else "potrace"
svg_namespace = {"svg": "http://www.w3.org/2000/svg"}


def trace(source, scratch):
    original = source
    if source.suffix == ".svg":
        # Render the original vector at 4x first, so tiny strokes survive tracing.
        svg = ET.parse(source)
        element = svg.getroot()
        _, _, width, height = map(float, element.get("viewBox").split())
        element.set("width", str(round(width * 4)))
        element.set("height", str(round(height * 4)))
        enlarged = scratch / "input.svg"
        svg.write(enlarged, encoding="unicode")
        original = scratch / "input.png"
        subprocess.run(["sips", "-s", "format", "png", enlarged, "--out", original],
                       check=True, capture_output=True)
    artwork = Image.open(original).convert("RGBA")
    artwork.thumbnail((1050, 1050), Image.Resampling.LANCZOS)
    width, height = artwork.size
    if artwork.getchannel("A").getextrema() == (255, 255):
        ink = ImageOps.invert(ImageOps.grayscale(artwork))
    else:
        ink = artwork.getchannel("A")
    mask = ink.point([255 if level <= 92 else 0 for level in range(256)], mode="1")
    bitmap = scratch / "input.pbm"
    mask.save(bitmap)
    traced = scratch / "output.svg"
    subprocess.run([potrace, "--svg", "--flat", "--unit", "10", "--turdsize", "3",
                    bitmap, "-o", traced], check=True, capture_output=True)

    def point(pos):
        # Potrace's unit is 1/10 pixel and its origin is lower left.
        return [round(pos.real / 10, 2), round(height - pos.imag / 10, 2)]

    commands = []
    for item in ET.parse(traced).findall(".//svg:path", svg_namespace):
        for contour in parse_path(item.get("d")).continuous_subpaths():
            commands += ["M", *point(contour.start)]
            for edge in contour:
                if isinstance(edge, Line):
                    commands += ["L", *point(edge.end)]
                elif isinstance(edge, CubicBezier):
                    commands += ["C", *point(edge.control1), *point(edge.control2), *point(edge.end)]
                else:
                    raise TypeError(type(edge))
            commands.append("Z")
    return {"width": width, "height": height, "path": " ".join(map(str, commands)),
            "source": str(source.relative_to(root))}


fallback_names = ["8-string-guitar", "baritone-guitar", "mandola", "custom-tuning"]
sources = sorted(assets.glob("tuner-*-face.imageset"))
sources.extend(assets / f"tuner-{name}.imageset" for name in fallback_names)
output.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory() as folder:
    for source in sources:
        images = json.loads((source / "Contents.json").read_text())["images"]
        drawing = source / next(image["filename"] for image in images if "filename" in image)
        geometry = trace(drawing, Path(folder))
        target = output / (source.stem + "-vector.json")
        target.write_text(json.dumps(geometry, separators=(",", ":")) + "\n")
        print(target.name)
