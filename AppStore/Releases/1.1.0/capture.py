#!/usr/bin/env python3
"""Capture first-release store screenshots from a Debug simulator build."""
import argparse
import subprocess
import tempfile
import time
from pathlib import Path

BUNDLE = "com.heartofjellyfish.themetronome"
LOCALES = {
    "en-US": ("en", "en_US"), "zh-Hans": ("zh-Hans", "zh_CN"), "zh-Hant": ("zh-Hant", "zh_TW"),
    "ja": ("ja", "ja_JP"), "ko": ("ko", "ko_KR"), "de-DE": ("de", "de_DE"),
    "es-ES": ("es", "es_ES"), "fr-FR": ("fr", "fr_FR"), "pt-BR": ("pt-BR", "pt_BR"),
}
SCENES = {
    "guitar": ("--mode-tuner", "--tuner-instrument=Guitar", "--tuner-test-cents=0"),
    "metronome": ("--mode-metronome", "--reference"),

}

def sim(*args, check=True):
    return subprocess.run(["xcrun", "simctl", *args], check=check, capture_output=True, text=True)

def capture(args):
    device = args.device
    sim("boot", device, check=False)
    sim("bootstatus", device, "-b")
    sim("ui", device, "appearance", "light")
    sim("install", device, str(args.app.resolve()))
    sim("status_bar", device, "override", "--time", "6:27", "--dataNetwork", "wifi",
        "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active",
        "--cellularBars", "4", "--operatorName", "", "--batteryState", "discharging",
        "--batteryLevel", "100")
    for locale in args.locale or LOCALES:
        language, region = LOCALES[locale]
        target = args.output / args.size / locale
        target.mkdir(parents=True, exist_ok=True)
        for scene in args.scene or SCENES:
            state = SCENES[scene]
            image = target / f"{scene}.jpg"
            if image.exists() and not args.refresh:
                continue
            sim("launch", "--terminate-running-process", device, BUNDLE, "--light", "--tuner-test-silent", "--tuner-release-catalog",
                "-AppleLanguages", f"({language})", "-AppleLocale", region,
                "-tuner.reference", "440", "-tuner.response", "balanced", *state)
            time.sleep(1.7)
            with tempfile.TemporaryDirectory() as scratch:
                raw = Path(scratch) / "screen.png"
                sim("io", device, "screenshot", str(raw))
                subprocess.run(
                    ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best",
                     str(raw), "--out", str(image)],
                    check=True, capture_output=True, text=True,
                )
        print(f"{args.size} {locale}", flush=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device")
    parser.add_argument("size", choices=("iphone", "ipad"))
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--locale", choices=LOCALES, action="append")
    parser.add_argument("--scene", choices=SCENES, action="append")
    parser.add_argument("--refresh", action="store_true")
    try:
        capture(parser.parse_args())
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr.strip() or str(error)) from error
