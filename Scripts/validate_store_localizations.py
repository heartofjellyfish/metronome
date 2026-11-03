#!/usr/bin/env python3
"""Validate literal App Store limits, completeness and truthful feature coverage."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
for path in sorted((root / 'AppStore/Localizations').glob('*.json')):
    item = json.loads(path.read_text())
    for field, limit in [('name', 30), ('subtitle', 30), ('promo', 170), ('description', 4000)]:
        assert 0 < len(item[field]) <= limit, (path.name, field, len(item[field]))
    assert len(item['keywords'].encode('utf-8')) <= 100, (path.name, 'keyword bytes')
    terms = item['keywords'].split(',')
    assert all(term and term == term.strip() for term in terms)
    assert len(terms) == len(set(term.casefold() for term in terms)), path.name
    assert len(item['captions']) == 6 and all(len(c) == 2 and all(c) for c in item['captions'])
    assert item['name'] == 'metronome, just cleaner'
    assert item['support_url'] == 'https://app.qi.land/metronome/'
    print(f'{path.stem}: subtitle {len(item["subtitle"])}/30; keywords {len(item["keywords"].encode())}/100 bytes')
