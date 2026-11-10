#!/usr/bin/env python3
"""Validate literal App Store limits, completeness and truthful feature coverage."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
for locale in ['de-DE', 'es-ES', 'fr-FR', 'ja', 'ko', 'pt-BR', 'zh-Hans', 'zh-Hant']:
    path = root / 'AppStore/Localizations' / f'{locale}.json'
    item = json.loads(path.read_text())
    for field, limit in [('name', 30), ('subtitle', 30), ('promo', 170), ('description', 4000)]:
        assert 0 < len(item[field]) <= limit, (path.name, field, len(item[field]))
    assert len(item['keywords'].encode('utf-8')) <= 100, (path.name, 'keyword bytes')
    terms = item['keywords'].split(',')
    assert all(term and term == term.strip() for term in terms)
    assert len(terms) == len(set(term.casefold() for term in terms)), path.name
    assert 1 <= len(item['captions']) <= 10 and all(len(c) == 2 and all(c) for c in item['captions'])
    assert item['name'] == 'metronome, just cleaner'
    assert item['support_url'] == 'https://app.qi.land/metronome/'
    print(f'{path.stem}: subtitle {len(item["subtitle"])}/30; keywords {len(item["keywords"].encode())}/100 bytes')

# Versioned launch package is the source used for the next-version draft.
for path in sorted((root / 'AppStore/Releases/1.0.2/metadata').glob('*.json')):
    item = json.loads(path.read_text())
    for field, limit in [('name', 30), ('subtitle', 30), ('promo', 170), ('description', 4000), ('whats_new', 4000)]:
        assert 0 < len(item[field]) <= limit, (path.name, field, len(item[field]))
    terms = item['keywords'].split(',')
    assert len(item['keywords'].encode()) <= 100, (path.name, 'keyword bytes')
    assert all(t and t == t.strip() for t in terms)
    assert len(terms) == len({t.casefold() for t in terms})
    assert len(item['captions']) == 8
    assert not any(any(phrase in (title + ' ' + detail).lower() for phrase in ['free forever', 'free for life']) for title, detail in item['captions'])
    if path.stem == 'en-US':
        indexed = set((item['name'] + ' ' + item['subtitle']).casefold().replace(',', ' ').split())
        assert not indexed.intersection(t.casefold() for t in terms)
    print(f'launch {path.stem}: all fields within limits; {len(item["captions"])} screenshots')
