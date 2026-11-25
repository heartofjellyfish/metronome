"""Generate the tuner instrument and interface tables."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ['zh-Hans', 'zh-Hant', 'ja', 'ko', 'fr', 'de', 'es', 'pt-BR']

# Keep the tuner catalog in its own table so instrument names can be localized
# independently of homonyms in the metronome (for example, flat and sharp).
tuner = {}
for line in (ROOT / 'Localization/tuner-translations.tsv').read_text().splitlines():
    key, *values = line.split('|')
    assert key not in tuner and len(values) == len(LOCALES) and all(values), key
    english = "Middle" if key == "Middle section" else key
    tuner[key] = [english] + values
for i, locale in enumerate(['en'] + LOCALES):
    path = ROOT / 'TheMetronome' / f'{locale}.lproj' / 'Tuner.strings'
    path.write_text(''.join(f'{json.dumps(k, ensure_ascii=False)} = {json.dumps(v[i], ensure_ascii=False)};\n'
                            for k, v in sorted(tuner.items())))
