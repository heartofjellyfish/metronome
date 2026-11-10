"""Assemble native XCTest captures and deterministic store compositions.

Usage: python3 assemble.py iphone /path/to/exported/attachments [...]
Compile render.swift with swiftc -O and pass --renderer /path/to/binary.
Later capture manifests override earlier ones for the same screen.
"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('platform', choices=['iphone', 'ipad'])
parser.add_argument('attachments', nargs='*', type=Path)
parser.add_argument('--renderer', type=Path, default=Path('/tmp/metronome-live-marketing-render'))
args = parser.parse_args()
root = Path(__file__).resolve().parent
locales = {'en': 'en-US', 'zh-Hans': 'zh-Hans', 'zh-Hant': 'zh-Hant',
           'ja': 'ja', 'ko': 'ko', 'fr': 'fr-FR', 'de': 'de-DE',
           'es': 'es-ES', 'pt-BR': 'pt-BR'}
sources = ['01-live', '02-pedal', '03-setlists', '04-home',
           '05-sounds', '06-rhythms', '07-ramp', '08-silent']
for folder in args.attachments:
    for suite in json.loads((folder / 'manifest.json').read_text()):
        for attachment in suite['attachments']:
            match = re.search(r'launch__(.+?)__(\d\d-[a-z]+)', attachment.get('suggestedHumanReadableName', ''))
            if not match:
                continue
            language, screen = match.groups()
            target = root / 'screenshots' / args.platform / language / 'raw'
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(folder / attachment['exportedFileName'], target / f'{screen}.png')
for language, locale in locales.items():
    folder = root / 'screenshots' / args.platform / language
    for screen in sources[:3 if args.platform == 'ipad' else 8]:
        assert (folder / 'raw' / f'{screen}.png').exists(), (language, screen)
    metadata = json.loads((root / 'metadata' / f'{locale}.json').read_text())
    (folder / 'captions.json').write_text(json.dumps(metadata['captions'], ensure_ascii=False, indent=2) + '\n')
    command = [str(args.renderer), str(folder)]
    if args.platform == 'ipad':
        command.append('--ipad')
    subprocess.run(command, check=True)
    print(args.platform, language, 'rendered', flush=True)
